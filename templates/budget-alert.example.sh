#!/usr/bin/env bash
# budget-alert.example.sh — EXAMPLE only. Creates a Cloud Billing budget alert.
# Requires: billing account ID, and roles/billing.costsManager (or admin).
# Alerts NOTIFY only — they do not stop VMs. Review the bill yourself.
#
# Usage:
#   BILLING_ACCOUNT=XXXXXX-XXXXXX-XXXXXX \
#   BUDGET_AMOUNT=1 \
#   bash budget-alert.example.sh
#
# Get billing account: gcloud billing accounts list
set -euo pipefail
BA=${BILLING_ACCOUNT:?set BILLING_ACCOUNT=XXXXXX-XXXXXX-XXXXXX}
AMT=${BUDGET_AMOUNT:-1}
DISPLAY=${BUDGET_NAME:-gcp-free-vm-cap}

# Newer gcloud uses `billing budgets create`. If unavailable, use Console:
# Billing → Budgets & alerts → Create budget → amount $AMT → alert at 50%/90%/100%.
if gcloud billing budgets create --help >/dev/null 2>&1; then
  gcloud billing budgets create \
    --billing-account="$BA" \
    --display-name="$DISPLAY" \
    --budget-amount="${AMT}USD" \
    --threshold-rule=percent=0.5 \
    --threshold-rule=percent=0.9 \
    --threshold-rule=percent=1.0 \
    --all-updates-rule-pubsub-topic="" \
    --all-updates-rule-monitoring-notification-channels=""
  echo "Budget created (email goes to billing admins by default). Verify in Console."
else
  cat <<MSG
This gcloud build has no 'billing budgets create'. Use Console instead:
  https://console.cloud.google.com/billing/budgets
  Amount: \$${AMT} / month
  Alerts: 50%, 90%, 100%
MSG
fi
