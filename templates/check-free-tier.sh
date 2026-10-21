#!/usr/bin/env bash
# check-free-tier.sh — READ-MOSTLY verifier: is this project / VM Always Free compliant?
# Prints key: value sections for an AI or human to parse. Does not create or delete resources.
# Optional: with APPLY_BUDGET_HINT=1 prints (does not create) a budget gcloud example.
#
# Usage:
#   bash check-free-tier.sh
#   NAME=free-e2micro ZONE=us-west1-a bash check-free-tier.sh
set -u
LC_ALL=C; export LC_ALL

have(){ command -v "$1" >/dev/null 2>&1; }
sec(){ printf '\n[%s]\n' "$1"; }
kv(){ printf '%s: %s\n' "$1" "${2:-unknown}"; }
ok(){ kv "$1" "OK — $2"; }
bad(){ kv "$1" "FAIL — $2"; }
warn(){ kv "$1" "WARN — $2"; }

have gcloud || { echo "ERROR: gcloud missing"; exit 1; }

PROJECT=${PROJECT:-$(gcloud config get-value project 2>/dev/null || true)}
NAME=${NAME:-}
ZONE=${ZONE:-}
FREE_REGIONS="us-west1 us-central1 us-east1"

sec meta
kv project "${PROJECT:-unset}"
kv gcloud_account "$(gcloud config get-value account 2>/dev/null || echo none)"
kv time_utc "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

sec billing
BA=$(gcloud billing projects describe "$PROJECT" --format='value(billingAccountName)' 2>/dev/null || true)
if [ -n "$BA" ]; then ok billing_linked "billing account present (Always Free requires one)"; else bad billing_linked "no billing account on project — enable billing / free trial first"; fi

sec compute_api
if gcloud services list --enabled --project="$PROJECT" --filter='config.name:compute.googleapis.com' --format='value(config.name)' 2>/dev/null | grep -q compute; then
  ok compute_api enabled
else
  warn compute_api "not enabled — create script will enable it"
fi

sec instances
LIST=$(gcloud compute instances list --project="$PROJECT" \
  --format='csv[no-heading](name,zone,machineType.basename(),status,networkInterfaces[0].accessConfigs[0].natIP)' 2>/dev/null || true)
if [ -z "$LIST" ]; then
  kv count 0
  kv note "no VMs — free-tier slot free"
else
  N=$(printf '%s\n' "$LIST" | wc -l | tr -d ' ')
  kv count "$N"
  printf '%s\n' "$LIST" | while IFS=, read -r n z mt st ip; do
    region=${z%-*}
    freereg=no
    for r in $FREE_REGIONS; do [ "$region" = "$r" ] && freereg=yes; done
    printf 'instance: name=%s zone=%s machine=%s status=%s ip=%s free_region=%s\n' "$n" "$z" "$mt" "$st" "${ip:-none}" "$freereg"
    if [ "$mt" != "e2-micro" ]; then bad "machine_$n" "$mt is not e2-micro — will bill"; fi
    if [ "$freereg" != "yes" ]; then bad "region_$n" "$region not in Always Free set"; fi
  done
  E2=$(printf '%s\n' "$LIST" | awk -F, '$3=="e2-micro"' | wc -l | tr -d ' ')
  if [ "${E2:-0}" -gt 1 ]; then
    warn e2_micro_count "$E2 concurrent e2-micros share one month of free hours — may bill"
  else
    ok e2_micro_count "${E2:-0}"
  fi
fi

# Detail one instance if NAME+ZONE given or exactly one exists
if [ -z "$NAME" ] && [ -n "$LIST" ]; then
  N=$(printf '%s\n' "$LIST" | wc -l | tr -d ' ')
  if [ "$N" = "1" ]; then
    NAME=$(printf '%s\n' "$LIST" | cut -d, -f1)
    ZONE=$(printf '%s\n' "$LIST" | cut -d, -f2)
  fi
fi

if [ -n "${NAME:-}" ] && [ -n "${ZONE:-}" ]; then
  sec instance_detail
  kv focus "$NAME @ $ZONE"
  DESC=$(gcloud compute instances describe "$NAME" --zone="$ZONE" --project="$PROJECT" --format=json 2>/dev/null || true)
  if [ -z "$DESC" ]; then
    bad describe "cannot describe $NAME"
  else
    MT=$(printf '%s' "$DESC" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("machineType","").split("/")[-1])' 2>/dev/null || echo '?')
    DSRC=$(printf '%s' "$DESC" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["disks"][0].get("source","").split("/")[-1] if d.get("disks") else "")' 2>/dev/null || true)
    NTIER=$(printf '%s' "$DESC" | python3 -c 'import json,sys;d=json.load(sys.stdin);acs=d.get("networkInterfaces",[{}])[0].get("accessConfigs",[{}]);print(acs[0].get("networkTier","?") if acs else "?")' 2>/dev/null || echo '?')
    DSIZE=$(gcloud compute disks describe "$DSRC" --zone="$ZONE" --project="$PROJECT" --format='value(sizeGb,type.basename())' 2>/dev/null || echo '? ?')
    D_GB=$(printf '%s' "$DSIZE" | awk '{print $1}')
    D_TY=$(printf '%s' "$DSIZE" | awk '{print $2}')
    if [ "$MT" = "e2-micro" ]; then ok machine_type e2-micro; else bad machine_type "$MT"; fi
    if [ "$D_TY" = "pd-standard" ]; then ok disk_type pd-standard; else bad disk_type "${D_TY:-unknown} (must be pd-standard)"; fi
    if [ "${D_GB:-99}" -le 30 ] 2>/dev/null; then ok disk_size "${D_GB}GB"; else bad disk_size "${D_GB}GB > 30"; fi
    if [ "$NTIER" = "STANDARD" ]; then ok network_tier STANDARD; else bad network_tier "${NTIER} (PREMIUM can charge)"; fi
  fi
fi

sec disks
DISKS=$(gcloud compute disks list --project="$PROJECT" --format='csv[no-heading](name,zone,sizeGb,type.basename(),users.basename():label=users)' 2>/dev/null || true)
if [ -z "$DISKS" ]; then kv disks none; else
  printf '%s\n' "$DISKS" | while IFS=, read -r n z sz ty users; do
    printf 'disk: name=%s zone=%s sizeGb=%s type=%s users=%s\n' "$n" "$z" "$sz" "$ty" "${users:-NONE}"
    [ "$ty" = "pd-standard" ] || bad "disk_type_$n" "$ty not free"
    [ "${sz:-0}" -le 30 ] 2>/dev/null || warn "disk_size_$n" "${sz}GB — free pool is 30GB-months total"
    [ -n "${users:-}" ] || warn "disk_orphan_$n" "unattached disk still bills"
  done
fi

sec snapshots
SNAPS=$(gcloud compute snapshots list --project="$PROJECT" --format='csv[no-heading](name,storageBytes,status)' 2>/dev/null || true)
if [ -z "$SNAPS" ]; then ok snapshots "none (good — snapshots can bill)"; else
  warn snapshots "found — review; snapshot storage can bill"
  printf '%s\n' "$SNAPS"
fi

sec images_custom
IMGS=$(gcloud compute images list --project="$PROJECT" --no-standard-images --format='value(name)' 2>/dev/null || true)
if [ -z "$IMGS" ]; then ok custom_images none; else warn custom_images "present — custom image storage can bill"; printf '%s\n' "$IMGS"; fi

sec addresses
ADDR=$(gcloud compute addresses list --project="$PROJECT" --format='csv[no-heading](name,region,address,status)' 2>/dev/null || true)
if [ -z "$ADDR" ]; then ok static_ips "none (ephemeral IP on a running free-tier VM is the usual choice)"; else
  warn static_ips "reserved addresses may bill when idle — release if unused"
  printf '%s\n' "$ADDR"
fi

sec firewall
FW=$(gcloud compute firewall-rules list --project="$PROJECT" --format='csv[no-heading](name,allowed[].map().firewall_rule().list():label=allow,targetTags.list():label=tags)' 2>/dev/null | head -40 || true)
kv rules_sample "${FW:-none}"

sec egress_notes
kv always_free_egress "1 GB/month outbound from North America to destinations excluding China and Australia (official Free Tier table). Ingress is free."
kv china_egress "Traffic to China is outside Always Free Compute egress — can bill. Avoid serving heavy downloads to CN from this VM."
kv cdn_trap "Some commercial CDN destinations have been reported by community users as expensive egress — watch the bill; budget alert mandatory."
kv budget "Budget alerts notify only; they do NOT auto-stop resources. Create under Billing → Budgets & alerts."

sec verdict
# Simple overall
# recount by scanning our own style is hard; print guidance
kv next "If any FAIL lines above: fix before relying on \$0. If only WARN: understand and accept or clean up."
kv create_script "templates/create-free-vm.sh (DRY_RUN=1 first)"
