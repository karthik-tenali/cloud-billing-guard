#!/bin/bash
set -euo pipefail

echo "======================================"
echo " AWS FULL INVENTORY REPORT"
echo " Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo "======================================"

REGIONS=$(aws ec2 describe-regions --query "Regions[].RegionName" --output text)

print_none() { echo "None"; }

# ================= GLOBAL =================

echo -e "\n🌍 GLOBAL SERVICES"

echo -e "\n🪣 S3 Buckets"
aws s3api list-buckets --query "Buckets[].Name" --output table || print_none

echo -e "\n👤 IAM Users"
aws iam list-users --query "Users[].UserName" --output table || print_none

echo -e "\n🧾 IAM Roles"
aws iam list-roles --query "Roles[].RoleName" --output table || print_none

echo -e "\n🌐 Route53 Hosted Zones"
aws route53 list-hosted-zones --query "HostedZones[].Name" --output table || print_none

echo -e "\n🧿 ECR Repositories"
aws ecr describe-repositories --query "repositories[].repositoryName" --output table || print_none

# ================= REGIONAL =================

for region in $REGIONS; do
  echo -e "\n======================================"
  echo " REGION: $region"
  echo "======================================"

  echo -e "\n🟢 EC2 Instances"
  aws ec2 describe-instances --region "$region" \
    --query "Reservations[].Instances[].InstanceId" --output table || print_none

  echo -e "\n🟢 EC2 Instances (non-terminated)"
  aws ec2 describe-instances --region "$region" \
    --query "Reservations[].Instances[?State.Name!='terminated'].[InstanceId,State.Name,InstanceType]" \
    --output table || print_none

  echo -e "\n🔵 EBS Volumes"
  aws ec2 describe-volumes --region "$region" \
    --query "Volumes[].VolumeId" --output table || print_none

  echo -e "\n📸 EBS Snapshots"
  aws ec2 describe-snapshots --region "$region" --owner-ids self \
    --query "Snapshots[].SnapshotId" --output table || print_none

  echo -e "\n🖼️ AMIs"
  aws ec2 describe-images --region "$region" --owners self \
    --query "Images[].ImageId" --output table || print_none

  echo -e "\n🧷 Network Interfaces (ENI)"
  aws ec2 describe-network-interfaces --region "$region" \
    --query "NetworkInterfaces[].NetworkInterfaceId" --output table || print_none

  echo -e "\n⚖️ Load Balancers (ALB/NLB)"
  aws elbv2 describe-load-balancers --region "$region" \
    --query "LoadBalancers[].LoadBalancerName" --output table || print_none

  echo -e "\n⚖️ Classic Load Balancers"
  aws elb describe-load-balancers --region "$region" \
    --query "LoadBalancerDescriptions[].LoadBalancerName" --output table || print_none

  echo -e "\n🔥 NAT Gateways"
  aws ec2 describe-nat-gateways --region "$region" \
    --query "NatGateways[].NatGatewayId" --output table || print_none

  echo -e "\n🌐 Elastic IPs"
  aws ec2 describe-addresses --region "$region" \
    --query "Addresses[].PublicIp" --output table || print_none

  echo -e "\n🔌 VPC Endpoints"
  aws ec2 describe-vpc-endpoints --region "$region" \
    --query "VpcEndpoints[].VpcEndpointId" --output table || print_none

  echo -e "\n☸️ EKS Clusters"
  aws eks list-clusters --region "$region" --query "clusters[]" --output table || print_none

  echo -e "\n🛢️ RDS Instances"
  aws rds describe-db-instances --region "$region" \
    --query "DBInstances[].DBInstanceIdentifier" --output table || print_none

  echo -e "\n📂 EFS File Systems"
  aws efs describe-file-systems --region "$region" \
    --query "FileSystems[].FileSystemId" --output table || print_none

  echo -e "\n⚙️ Lambda Functions"
  aws lambda list-functions --region "$region" \
    --query "Functions[].FunctionName" --output table || print_none

  echo -e "\n📊 CloudWatch Log Groups"
  aws logs describe-log-groups --region "$region" \
    --query "logGroups[].logGroupName" --output table || print_none

  echo -e "\n⏰ CloudWatch Alarms"
  aws cloudwatch describe-alarms --region "$region" \
    --query "MetricAlarms[].AlarmName" --output table || print_none

done

echo -e "\n======================================"
echo " INVENTORY COMPLETE"
echo "======================================"

