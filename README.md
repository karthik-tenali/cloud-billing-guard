# Cloud Billing Guard

Cloud Billing Guard is a set of lightweight Bash scripts designed to detect billable cloud resources and generate comprehensive infrastructure inventories for AWS and Google Cloud Platform (GCP).

Prevent surprise bills by quickly identifying running or chargeable services across your cloud accounts.

---

## Features

### AWS
- Detects running EC2 instances and non-free-tier usage
- Finds NAT Gateways, Load Balancers, RDS databases, EKS clusters, and EFS file systems
- Checks EBS volumes, snapshots, and Elastic IPs
- Lists S3 buckets, ECR repositories, Route53 zones, Lambda functions, and CloudWatch resources
- Provides full region-by-region inventory

### GCP
- Detects Compute Engine VMs and their running status
- Finds persistent disks, static IPs, and load balancers
- Identifies Cloud NAT, GKE clusters, and Cloud SQL instances
- Lists Cloud Storage buckets, Cloud Run services, Cloud Functions, and Artifact Registry repositories
- Generates complete project inventory

---

## Scripts

| Script | Description |
|--------|-------------|
| `aws_guard.sh` | AWS billing safety audit - quick scan for costly resources |
| `aws_inventory.sh` | Full AWS infrastructure inventory across all regions |
| `gcp_guard.sh` | GCP billing safety audit - quick scan for costly resources |
| `gcp_inventory.sh` | Full GCP infrastructure inventory |

---

## Prerequisites

### AWS
- **AWS CLI** installed ([Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- AWS credentials configured with appropriate read permissions
- IAM permissions for services you want to audit (EC2, S3, RDS, etc.)

### GCP
- **Google Cloud SDK** installed ([Installation Guide](https://cloud.google.com/sdk/docs/install))
- Authenticated GCP account
- Project ID configured
- Viewer or equivalent permissions on the target project

---

## Installation

```bash
# Clone or download the scripts to your local machine
git clone <repository-url>
cd cloud-billing-guard

# Make scripts executable
chmod +x aws_guard.sh aws_inventory.sh gcp_guard.sh gcp_inventory.sh
```

---

## Usage

### AWS

```bash
# Configure AWS credentials (if not already done)
aws configure

# Run billing safety audit (recommended first step)
./aws_guard.sh

# Run full infrastructure inventory
./aws_inventory.sh
```

**Example Output:**
```
Checking for billable AWS resources...
✓ EC2 Instances: 3 running
✓ NAT Gateways: 1 active (costly!)
✓ RDS Instances: 0
✓ EBS Volumes: 15 (120 GB total)
```

### GCP

```bash
# Authenticate with Google Cloud (if not already done)
gcloud auth login

# Set your project ID
gcloud config set project PROJECT_ID

# Run billing safety audit (recommended first step)
./gcp_guard.sh

# Run full infrastructure inventory
./gcp_inventory.sh
```

**Example Output:**
```
Checking for billable GCP resources...
✓ Compute Instances: 2 running
✓ Cloud NAT: 1 gateway (costly!)
✓ GKE Clusters: 0
✓ Persistent Disks: 8 (200 GB total)
```

---

## What Gets Detected

### High-Cost Resources (Prioritized)
Both scripts prioritize detecting resources that can generate significant costs:
- **NAT Gateways / Cloud NAT** - Often overlooked, high hourly costs
- **Load Balancers** - Multiple types, continuous charges
- **Running VMs/Instances** - Especially larger instance types
- **Database Services** - RDS, Cloud SQL instances
- **Kubernetes Clusters** - EKS, GKE control plane and node costs

### Storage & Networking
- Persistent disks and volumes
- Snapshots and images
- Elastic/Static IP addresses
- S3 buckets and Cloud Storage

### Compute & Serverless
- Lambda functions and Cloud Functions
- Cloud Run services
- Container registries

---

## Tips

- **Run the guard scripts first** - They're faster and focus on the most expensive resources
- **Review NAT Gateways carefully** - These can cost $30-50/month each
- **Check all regions (AWS)** - Resources in unexpected regions are common billing surprises
- **Run regularly** - Schedule monthly audits to catch orphaned resources
- **Delete unused resources promptly** - Even "stopped" resources can incur charges (EBS volumes, snapshots, IPs)

---

## Limitations

- Requires read-only access to cloud resources (some services may need specific permissions)
- Does not calculate exact costs - provides resource counts only
- AWS inventory scans all enabled regions (may take several minutes)
- Does not detect all services - focuses on common billable resources

---

## Contributing

Contributions are welcome! If you'd like to add support for additional cloud services or improve existing detection, please submit a pull request.

