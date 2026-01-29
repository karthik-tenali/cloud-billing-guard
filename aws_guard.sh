#!/bin/bash
set -euo pipefail

# ================= CONFIG =================
export PATH=/usr/local/bin:/usr/bin:/bin
export AWS_PROFILE=default
export AWS_RETRY_MODE=adaptive
export AWS_MAX_ATTEMPTS=5

RISK_FOUND=0

# ================= HELPERS =================
log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
warn() { echo "⚠️  WARNING: $1"; }
crit() { echo "🚨 CRITICAL: $1"; RISK_FOUND=1; }

safe_aws() {
  aws "$@" 2>/dev/null || return 1
}

# ================= START =================
log "STARTING AWS BILLING SAFETY AUDIT"

REGIONS=$(safe_aws ec2 describe-regions --query "Regions[].RegionName" --output text)

# ================= GLOBAL SERVICES =================

log "Checking GLOBAL services"

# ---------- IAM (Free, visibility only) ----------
IAM_USERS=$(safe_aws iam list-users --query "Users[].UserName" --output text)
[ -n "$IAM_USERS" ] && log "IAM users present: $IAM_USERS"

# ---------- Route53 (PAID) ----------
ROUTE53_ZONES=$(safe_aws route53 list-hosted-zones --query "HostedZones[].Name" --output text)
[ -n "$ROUTE53_ZONES" ] && crit "Route53 hosted zones exist (monthly billed): $ROUTE53_ZONES"

# ---------- S3 (STORAGE COST) ----------
S3_BUCKETS=$(safe_aws s3api list-buckets --query "Buckets[].Name" --output text)
[ -n "$S3_BUCKETS" ] && warn "S3 buckets exist (storage billed): $S3_BUCKETS"

# ---------- ECR (STORAGE COST) ----------
ECR_REPOS=$(safe_aws ecr describe-repositories --query "repositories[].repositoryName" --output text)
for repo in $ECR_REPOS; do
  COUNT=$(safe_aws ecr list-images --repository-name "$repo" --query "imageIds[]" --output text | wc -w)
  [ "$COUNT" -gt 0 ] && warn "ECR repo '$repo' contains $COUNT images (storage billed)"
done

# ================= REGIONAL SERVICES =================

for region in $REGIONS; do
  log "Region: $region"

  # ---------- EC2 ----------
  INSTANCES=$(safe_aws ec2 describe-instances --region "$region" \
    --query "Reservations[].Instances[?State.Name=='running'].[InstanceId,InstanceType]" \
    --output text)

  if [ -n "$INSTANCES" ]; then
    while read -r id type; do
      [[ "$type" =~ micro$ ]] \
        && warn "EC2 $id ($type) running in $region (free tier hours used)" \
        || crit "EC2 $id ($type) running in $region (OUT OF FREE TIER)"
    done <<< "$INSTANCES"
  fi

  # ---------- EBS ----------
  TOTAL_EBS=$(safe_aws ec2 describe-volumes --region "$region" \
    --query "sum(Volumes[].Size)" --output text || echo 0)
  [ "$TOTAL_EBS" -gt 30 ] && crit "EBS total ${TOTAL_EBS}GB in $region (>30GB free tier)"

  # ---------- EBS SNAPSHOTS ----------
  SNAPSHOTS=$(safe_aws ec2 describe-snapshots --owner-ids self --region "$region" \
    --query "Snapshots[].SnapshotId" --output text)
  [ -n "$SNAPSHOTS" ] && crit "EBS snapshots exist in $region (storage billed)"

  # ---------- NAT GATEWAY (HIGH COST) ----------
  NAT=$(safe_aws ec2 describe-nat-gateways --region "$region" \
    --query "NatGateways[?State=='available'].NatGatewayId" --output text)
  [ -n "$NAT" ] && crit "NAT Gateway ACTIVE in $region (HIGH COST): $NAT"

  # ---------- ELASTIC IP ----------
  EIP=$(safe_aws ec2 describe-addresses --region "$region" \
    --query "Addresses[?AssociationId==null].PublicIp" --output text)
  [ -n "$EIP" ] && warn "Unattached Elastic IP in $region (hourly billed): $EIP"

  # ---------- LOAD BALANCERS ----------
  LB_V2=$(safe_aws elbv2 describe-load-balancers --region "$region" \
    --query "LoadBalancers[].LoadBalancerName" --output text)
  LB_CLASSIC=$(safe_aws elb describe-load-balancers --region "$region" \
    --query "LoadBalancerDescriptions[].LoadBalancerName" --output text)

  [ -n "$LB_V2" ] && crit "ALB/NLB present in $region (hourly billed): $LB_V2"
  [ -n "$LB_CLASSIC" ] && crit "Classic ELB present in $region: $LB_CLASSIC"

  # ---------- EKS (CONTROL PLANE COST) ----------
  EKS_CLUSTERS=$(safe_aws eks list-clusters --region "$region" --output text)
  [ -n "$EKS_CLUSTERS" ] && crit "EKS cluster ACTIVE in $region (daily cost): $EKS_CLUSTERS"

  # ---------- VPC INTERFACE ENDPOINTS ----------
  ENDPOINTS=$(safe_aws ec2 describe-vpc-endpoints --region "$region" \
    --query "VpcEndpoints[?VpcEndpointType=='Interface'].VpcEndpointId" --output text)
  [ -n "$ENDPOINTS" ] && crit "Interface VPC Endpoint in $region (hourly billed)"

  # ---------- RDS ----------
  RDS=$(safe_aws rds describe-db-instances --region "$region" \
    --query "DBInstances[].DBInstanceIdentifier" --output text)
  [ -n "$RDS" ] && crit "RDS instance running in $region (hourly billed): $RDS"

  # ---------- EFS ----------
  EFS=$(safe_aws efs describe-file-systems --region "$region" \
    --query "FileSystems[].FileSystemId" --output text)
  [ -n "$EFS" ] && crit "EFS file system active in $region (storage billed): $EFS"

  # ---------- LAMBDA ----------
  LAMBDA=$(safe_aws lambda list-functions --region "$region" \
    --query "Functions[].FunctionName" --output text)
  [ -n "$LAMBDA" ] && warn "Lambda functions present in $region (invocation cost): $LAMBDA"

  # ---------- CLOUDWATCH ----------
  LOG_GROUPS=$(safe_aws logs describe-log-groups --region "$region" \
    --query "logGroups[].logGroupName" --output text)
  [ -n "$LOG_GROUPS" ] && warn "CloudWatch log groups present in $region (storage billed)"

done

# ================= FINAL SUMMARY =================

echo ""
echo "======================================"
if [ "$RISK_FOUND" -eq 1 ]; then
  echo "🚨 BILLING RISK DETECTED — ACTION REQUIRED"
  exit 1
else
  echo "✅ BILLING SAFE — NOTHING COSTLY RUNNING"
fi
echo "======================================"

