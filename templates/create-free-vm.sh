#!/usr/bin/env bash
# create-free-vm.sh — idempotent Always Free e2-micro creator for Cloud Shell / gcloud.
# Does NOT invent project IDs, emails, or IPs. Prints what it will do; with DRY_RUN=1 only prints.
#
# Defaults stay inside Google Cloud Always Free (Compute Engine Free Tier):
#   machine: e2-micro | regions: us-west1|us-central1|us-east1
#   disk: 30GB pd-standard | network-tier: STANDARD | image: debian-12
#
# Usage (Cloud Shell):
#   bash create-free-vm.sh                 # create / reuse
#   DRY_RUN=1 bash create-free-vm.sh       # print plan only
#   ZONE=us-central1-b NAME=my-free-vm bash create-free-vm.sh
#
# Env overrides (all optional):
#   NAME ZONE REGION MACHINE_TYPE DISK_SIZE_GB DISK_TYPE IMAGE_FAMILY IMAGE_PROJECT
#   NETWORK NETWORK_TIER TAGS SWAP_MB ENABLE_OSLOGIN CREATE_FW SKIP_SWAP
#   PROJECT (defaults to gcloud config project)
#
# Idempotent: if NAME already exists in ZONE, skips create and prints its IP.
# Never deletes existing VMs, disks, snapshots, or firewall rules.
set -euo pipefail
LC_ALL=C; export LC_ALL

die(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
log(){ printf '>> %s\n' "$*"; }
have(){ command -v "$1" >/dev/null 2>&1; }

have gcloud || die "gcloud not found. Open Google Cloud Shell (console top-right '>_' ), or install Google Cloud SDK."

# --- defaults (Always Free safe) ---
NAME=${NAME:-free-e2micro}
REGION=${REGION:-us-west1}
ZONE=${ZONE:-${REGION}-a}
MACHINE_TYPE=${MACHINE_TYPE:-e2-micro}
DISK_SIZE_GB=${DISK_SIZE_GB:-30}
DISK_TYPE=${DISK_TYPE:-pd-standard}
IMAGE_FAMILY=${IMAGE_FAMILY:-debian-12}
IMAGE_PROJECT=${IMAGE_PROJECT:-debian-cloud}
NETWORK=${NETWORK:-default}
NETWORK_TIER=${NETWORK_TIER:-STANDARD}
TAGS=${TAGS:-gcp-free-vm,http-server,https-server}
SWAP_MB=${SWAP_MB:-1024}
ENABLE_OSLOGIN=${ENABLE_OSLOGIN:-FALSE}
CREATE_FW=${CREATE_FW:-1}
SKIP_SWAP=${SKIP_SWAP:-0}
DRY_RUN=${DRY_RUN:-0}
PROJECT=${PROJECT:-$(gcloud config get-value project 2>/dev/null || true)}

FREE_REGIONS="us-west1 us-central1 us-east1"
ALLOWED_MACHINES="e2-micro"
ALLOWED_DISK_TYPES="pd-standard"

# --- hard guards (refuse paid shapes) ---
region_ok=0
for r in $FREE_REGIONS; do [ "$REGION" = "$r" ] && region_ok=1; done
[ "$region_ok" -eq 1 ] || die "REGION='$REGION' is NOT Always Free. Use one of: $FREE_REGIONS"
case " $ALLOWED_MACHINES " in *" $MACHINE_TYPE "*) ;; *)
  die "MACHINE_TYPE='$MACHINE_TYPE' is NOT Always Free. Use e2-micro only.";; esac
case " $ALLOWED_DISK_TYPES " in *" $DISK_TYPE "*) ;; *)
  die "DISK_TYPE='$DISK_TYPE' is NOT Always Free. Use pd-standard only (not pd-balanced/pd-ssd).";; esac
[ "$DISK_SIZE_GB" -le 30 ] || die "DISK_SIZE_GB=$DISK_SIZE_GB > 30; Always Free covers 30 GB-months of pd-standard."
[ "$NETWORK_TIER" = "STANDARD" ] || die "NETWORK_TIER='$NETWORK_TIER' must be STANDARD (PREMIUM can incur charges)."
case "$ZONE" in ${REGION}-*) ;; *)
  die "ZONE='$ZONE' does not belong to REGION='$REGION'.";; esac
[ -n "$PROJECT" ] && [ "$PROJECT" != "(unset)" ] || die "No gcloud project set. In Cloud Shell run: gcloud config set project YOUR_PROJECT_ID"

# --- plan summary ---
cat <<PLAN
======== Always Free VM plan ========
project:       $PROJECT
name:          $NAME
region/zone:   $REGION / $ZONE
machine:       $MACHINE_TYPE
disk:          ${DISK_SIZE_GB}GB $DISK_TYPE
image:         $IMAGE_PROJECT/$IMAGE_FAMILY
network:       $NETWORK  tier=$NETWORK_TIER
tags:          $TAGS
os-login:      $ENABLE_OSLOGIN
swap_mb:       $SWAP_MB (SKIP_SWAP=$SKIP_SWAP)
create_fw:     $CREATE_FW
dry_run:       $DRY_RUN
=====================================
Cost intent: stay in Always Free (1 e2-micro + 30GB pd-standard + STANDARD tier).
Egress to China/Australia is NOT free-tier covered — set a budget alert.
Snapshots / extra disks / PREMIUM tier / non-free regions WILL charge.
PLAN

if [ "$DRY_RUN" = "1" ]; then
  log "DRY_RUN=1 — no API calls that create resources. Exiting."
  exit 0
fi

# --- billing / API readiness (read-only checks) ---
if ! gcloud billing projects describe "$PROJECT" --format='value(billingAccountName)' 2>/dev/null | grep -q .; then
  log "WARN: cannot confirm a billing account on this project. Always Free still requires an active billing account (card for verification). Continue only if you know billing is linked."
fi

log "Enabling compute.googleapis.com (idempotent)…"
gcloud services enable compute.googleapis.com --project="$PROJECT"

# --- firewall (add-only; never delete) ---
if [ "$CREATE_FW" = "1" ]; then
  ensure_fw(){
    local rule=$1; shift
    if gcloud compute firewall-rules describe "$rule" --project="$PROJECT" >/dev/null 2>&1; then
      log "firewall $rule already exists — leave as-is"
    else
      log "creating firewall $rule"
      gcloud compute firewall-rules create "$rule" --project="$PROJECT" "$@"
    fi
  }
  # SSH for admin; http/https tags match console defaults (optional convenience).
  ensure_fw allow-ssh-gcp-free-vm \
    --network="$NETWORK" --allow=tcp:22 --target-tags=gcp-free-vm \
    --description="gcp-free-vm-skill: SSH to tagged free VMs"
  ensure_fw default-allow-http \
    --network="$NETWORK" --allow=tcp:80 --target-tags=http-server \
    --description="Allow HTTP" 2>/dev/null || true
  ensure_fw default-allow-https \
    --network="$NETWORK" --allow=tcp:443 --target-tags=https-server \
    --description="Allow HTTPS" 2>/dev/null || true
fi

# --- startup script: swap + unattended-upgrades hint ---
STARTUP_FILE=$(mktemp)
trap 'rm -f "$STARTUP_FILE"' EXIT
cat > "$STARTUP_FILE" <<STARTUP
#!/bin/bash
set -e
SWAPFILE=/swapfile-gcp-free
SWAP_MB=${SWAP_MB}
if [ "${SKIP_SWAP}" != "1" ] && [ ! -f "\$SWAPFILE" ]; then
  if ! swapon --show | grep -q .; then
    fallocate -l "\${SWAP_MB}M" "\$SWAPFILE" 2>/dev/null || dd if=/dev/zero of="\$SWAPFILE" bs=1M count="\$SWAP_MB"
    chmod 600 "\$SWAPFILE"
    mkswap "\$SWAPFILE"
    swapon "\$SWAPFILE"
    grep -q "\$SWAPFILE" /etc/fstab || echo "\$SWAPFILE none swap sw 0 0" >> /etc/fstab
  fi
fi
# Debian: enable unattended-upgrades if present (no install force)
if command -v dpkg >/dev/null 2>&1; then
  apt-get update -qq || true
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unattended-upgrades >/dev/null 2>&1 || true
fi
STARTUP

# --- create or reuse instance ---
if gcloud compute instances describe "$NAME" --zone="$ZONE" --project="$PROJECT" >/dev/null 2>&1; then
  log "instance $NAME already exists in $ZONE — reuse (no recreate)"
else
  # Refuse if another e2-micro already exists elsewhere (Always Free = 1 instance-month of hours)
  EXISTING=$(gcloud compute instances list --project="$PROJECT" \
    --filter="machineType:e2-micro" --format='value(name,zone)' 2>/dev/null || true)
  if [ -n "$EXISTING" ]; then
    log "WARN: other e2-micro instance(s) already in this project:"
    printf '%s\n' "$EXISTING"
    log "Always Free covers hours equal to one full month of e2-micro. Extra concurrent e2-micros share that pool and may bill. Aborting create. Set NAME/ZONE to the existing one, or delete the other yourself."
    exit 2
  fi

  META_ARGS=(--metadata=enable-oslogin="${ENABLE_OSLOGIN}")
  # startup-script via --metadata-from-file
  log "creating instance $NAME…"
  gcloud compute instances create "$NAME" \
    --project="$PROJECT" \
    --zone="$ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --image-family="$IMAGE_FAMILY" \
    --image-project="$IMAGE_PROJECT" \
    --boot-disk-size="${DISK_SIZE_GB}GB" \
    --boot-disk-type="$DISK_TYPE" \
    --network-interface="network=${NETWORK},network-tier=${NETWORK_TIER}" \
    --tags="$TAGS" \
    --metadata-from-file=startup-script="$STARTUP_FILE" \
    "${META_ARGS[@]}" \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write
fi

# --- wait + print IP ---
log "waiting for RUNNING…"
for _ in $(seq 1 30); do
  ST=$(gcloud compute instances describe "$NAME" --zone="$ZONE" --project="$PROJECT" --format='value(status)' 2>/dev/null || true)
  [ "$ST" = "RUNNING" ] && break
  sleep 2
done

EXT_IP=$(gcloud compute instances describe "$NAME" --zone="$ZONE" --project="$PROJECT" \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)' 2>/dev/null || true)
INT_IP=$(gcloud compute instances describe "$NAME" --zone="$ZONE" --project="$PROJECT" \
  --format='get(networkInterfaces[0].networkIP)' 2>/dev/null || true)

cat <<OUT

======== DONE ========
name:     $NAME
zone:     $ZONE
status:   ${ST:-unknown}
ext_ip:   ${EXT_IP:-none}
int_ip:   ${INT_IP:-none}
ssh tip:  gcloud compute ssh $NAME --zone=$ZONE --project=$PROJECT
          (or use browser SSH on the VM instances page)

Next (budget, recommended):
  Console → Billing → Budgets & alerts → create a budget (e.g. \$1/month) with email alerts.
  Alerts do NOT auto-stop spend — they only notify. Review Billing monthly.

Teardown (YOU run when done; this script never deletes):
  gcloud compute instances delete $NAME --zone=$ZONE --project=$PROJECT
  # also delete orphan disks/snapshots if any:
  # gcloud compute disks list
  # gcloud compute snapshots list

Handoff to residential-exit skill (交锁头):
  After you can SSH in, follow:
  https://github.com/free-dam-man/homeline-residential-exit-skill
======================
OUT
