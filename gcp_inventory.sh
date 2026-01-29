#!/bin/bash
set -euo pipefail

export CLOUDSDK_CORE_DISABLE_PROMPTS=1

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

echo "======================================"
echo " GCP FULL INVENTORY REPORT"
echo " Project: $PROJECT_ID"
echo " Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo "======================================"

safe() { "$@" 2>/dev/null || true; }

echo -e "\n🖥️ Compute Engine Instances"
safe gcloud compute instances list || echo "None"

echo -e "\n💾 Persistent Disks"
safe gcloud compute disks list || echo "None"

echo -e "\n🌐 Static IP Addresses"
safe gcloud compute addresses list || echo "None"

echo -e "\n⚖️ Load Balancers"
safe gcloud compute forwarding-rules list || echo "None"

echo -e "\n🔥 Cloud NAT"
ROUTERS=$(safe gcloud compute routers list --format="value(name,region)")
if [ -n "$ROUTERS" ]; then
  while read -r router region; do
    safe gcloud compute routers nats list \
      --router="$router" \
      --region="${region##*/}"
  done <<< "$ROUTERS"
else
  echo "None"
fi

echo -e "\n☸️ GKE Clusters"
safe gcloud container clusters list || echo "None"

echo -e "\n🛢️ Cloud SQL Instances"
safe gcloud sql instances list || echo "None"

echo -e "\n🪣 Cloud Storage Buckets"
safe gsutil ls || echo "None"

echo -e "\n📦 Artifact Registry"
safe gcloud artifacts repositories list || echo "None"

echo -e "\n⚙️ Cloud Functions"
safe gcloud functions list || echo "None"

echo -e "\n🚀 Cloud Run Services"
safe gcloud run services list --platform=managed || echo "None"

echo -e "\n📊 Cloud Logging Logs"
safe gcloud logging logs list || echo "None"

echo -e "\n⏰ Monitoring Alert Policies"
safe gcloud monitoring policies list || echo "None"

echo ""
echo "======================================"
echo " INVENTORY COMPLETE (SAFE MODE)"
echo "======================================"

