#!/bin/bash
set -euo pipefail

export CLOUDSDK_CORE_DISABLE_PROMPTS=1
RISK_FOUND=0

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
warn() { echo "⚠️  WARNING: $1"; }
crit() { echo "🚨 CRITICAL: $1"; RISK_FOUND=1; }

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

[ -z "$PROJECT_ID" ] && { echo "❌ No GCP project set"; exit 1; }

log "STARTING GCP BILLING SAFETY AUDIT"
log "Project: $PROJECT_ID"

# ---------- Compute ----------
INSTANCES=$(gcloud compute instances list --format="value(name)" 2>/dev/null || true)
[ -n "$INSTANCES" ] && crit "Compute Engine VMs running"

# ---------- Disks ----------
DISKS=$(gcloud compute disks list --format="value(name)" 2>/dev/null || true)
[ -n "$DISKS" ] && warn "Persistent disks exist"

# ---------- Static IPs ----------
IPS=$(gcloud compute addresses list --format="value(name)" 2>/dev/null || true)
[ -n "$IPS" ] && warn "Static IPs allocated"

# ---------- Load Balancers ----------
LB=$(gcloud compute forwarding-rules list --format="value(name)" 2>/dev/null || true)
[ -n "$LB" ] && crit "Load balancers exist"

# ---------- Cloud NAT (SAFE CHECK) ----------
ROUTERS=$(gcloud compute routers list --format="value(name,region)" 2>/dev/null || true)
if [ -n "$ROUTERS" ]; then
  while read -r router region; do
    NAT=$(gcloud compute routers nats list \
      --router="$router" \
      --region="${region##*/}" \
      --format="value(name)" 2>/dev/null || true)
    [ -n "$NAT" ] && crit "Cloud NAT active on router $router ($region)"
  done <<< "$ROUTERS"
fi

# ---------- GKE ----------
GKE=$(gcloud container clusters list --format="value(name)" 2>/dev/null || true)
[ -n "$GKE" ] && crit "GKE clusters running"

# ---------- Cloud SQL ----------
SQL=$(gcloud sql instances list --format="value(name)" 2>/dev/null || true)
[ -n "$SQL" ] && crit "Cloud SQL instances running"

# ---------- Storage ----------
BUCKETS=$(gsutil ls 2>/dev/null || true)
[ -n "$BUCKETS" ] && warn "Cloud Storage buckets exist"

# ---------- Cloud Functions ----------
CF=$(gcloud functions list --format="value(name)" 2>/dev/null || true)
[ -n "$CF" ] && warn "Cloud Functions deployed"

# ---------- Cloud Run ----------
CR=$(gcloud run services list --platform=managed --format="value(name)" 2>/dev/null || true)
[ -n "$CR" ] && warn "Cloud Run services exist"

# ---------- Artifact Registry ----------
AR=$(gcloud artifacts repositories list --format="value(name)" 2>/dev/null || true)
[ -n "$AR" ] && warn "Artifact Registry repos exist"

echo ""
echo "======================================"
if [ "$RISK_FOUND" -eq 1 ]; then
  echo "🚨 BILLING RISK DETECTED — ACTION REQUIRED"
  exit 1
else
  echo "✅ BILLING SAFE — NOTHING COSTLY RUNNING"
fi
echo "======================================"

