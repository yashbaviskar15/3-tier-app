# AWS Three-Tier Web Application Infrastructure

![Terraform](https://img.shields.io/badge/Terraform-v1.5+-7B42BC?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?logo=amazonaws&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![IaC](https://img.shields.io/badge/IaC-Production_Grade-blue)
![Status](https://img.shields.io/badge/Status-100%25_Operational-success)

A production-grade, enterprise-scale AWS Three-Tier Web Application built entirely with modular Terraform. Features VPC network segmentation, Auto Scaling compute, Multi-AZ RDS database, CloudFront CDN, and full observability -- deployed across dev, staging, and production environments.

---

## Live Interactive Portals

| Portal | Live URL | Description |
|---|---|---|
| Enterprise Operations Console | [three-tier-app.vercel.app](https://three-tier-app.vercel.app/) | Production operations console with real-time metrics, topology flow and cloud CLI |
| Source Code and API Sandbox | [three-tier-app-src.vercel.app](https://three-tier-app-src.vercel.app/) | Interactive Node.js backend explorer, Docker manifests and live API tester |
| Terraform Modules Visualizer | [three-tier-app-modules.vercel.app](https://three-tier-app-modules.vercel.app/) | Visual catalog of all 11 Terraform modules with HCL code viewers |
| Multi-Environment Dashboard | [three-tier-app-environments.vercel.app](https://three-tier-app-environments.vercel.app/) | Dev vs Staging vs Prod parameter matrices and FinOps cost comparison |
| Documentation Hub | [three-tier-app-docs.vercel.app](https://three-tier-app-docs.vercel.app/) | Complete knowledge base covering architecture, troubleshooting, security and interview Q&A |

---

## Architecture Overview

```
User --> Route 53 (DNS) --> CloudFront CDN
                                |
                    +-----------+-----------+
                    |                       |
            Static Assets           Dynamic /api/*
            (S3 + OAC)          Application Load Balancer
                                        |
                                 Auto Scaling Group
                              (EC2 Private App Subnets)
                                        |
                                   RDS MySQL
                          (Multi-AZ, KMS Encrypted,
                           Private Data Subnets)
```

### Request Flow

1. User -- DNS resolution via Route 53 (alias to CloudFront)
2. CloudFront -- Serves cached static assets from S3 (via OAC) or forwards /api/* to ALB
3. ALB -- Health-checked routing to EC2 instances in private app subnets
4. EC2 -- Fetches DB credentials from Secrets Manager, connects to RDS MySQL in isolated data subnets
5. CloudWatch -- Collects metrics, logs, and triggers alarms via SNS

---

## Features

- Multi-tier VPC with public, private-app, and isolated private-data subnets across 2-3 AZs
- Least-privilege security groups with chained SG references (ALB to App to RDS)
- Auto Scaling with CPU and ALB request count target tracking policies
- RDS Multi-AZ with KMS-encrypted storage, automated backups, and Secrets Manager integration
- CloudFront CDN with Origin Access Control (OAC), dual-origin (S3 + ALB)
- ACM SSL/TLS with DNS-validated certificates and HTTP to HTTPS redirect
- SSM Session Manager with no SSH keys, no port 22, and IMDSv2 enforced
- CloudWatch observability with dashboards, alarms, log groups, and SNS notifications
- Multi-environment support for dev, staging, and prod with separate VPCs, configs, and state files
- CI/CD pipeline via GitHub Actions with fmt, validate, plan, checkov scan, and apply
- Remote state with S3 and DynamoDB state locking with versioning

---

## Prerequisites

| Tool | Version | Installation |
|------|---------|-------------|
| AWS CLI | v2.x+ | [Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| Terraform | v1.5.0+ | [Install Guide](https://developer.hashicorp.com/terraform/install) |
| Git | v2.x+ | [Install Guide](https://git-scm.com/downloads) |
| AWS Account | Active | With sufficient IAM permissions |

---

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/yashbaviskar15/3-tier-app.git
cd 3-tier-app

# 2. Bootstrap remote state backend (one-time)
aws s3api create-bucket --bucket three-tier-tf-state-dev --region us-east-1
aws dynamodb create-table --table-name three-tier-tf-locks-dev \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --region us-east-1

# 3. Initialize and deploy
cd environments/dev
terraform init
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

---

## Project Structure

```
3-tier-app/
|
|-- .github/
|   |-- workflows/
|       |-- terraform.yml                # CI/CD: fmt, validate, plan, checkov, apply
|
|-- api/
|   |-- index.js                         # Vercel serverless API (health, info, db-status, exec)
|
|-- docs/
|   |-- ARCHITECTURE.md                  # Detailed architecture deep-dive
|   |-- COST_ESTIMATION.md              # Per-environment cost breakdown
|   |-- DEPLOYMENT.md                    # Step-by-step deployment guide
|   |-- INTERVIEW_QUESTIONS.md          # 20 Q&A for DevOps interview prep
|   |-- ROADMAP.md                       # Future improvements roadmap
|   |-- ROLLBACK.md                      # Rollback procedures for all tiers
|   |-- SECURITY.md                      # Security controls and best practices
|   |-- TROUBLESHOOTING.md              # Common failure scenarios and fixes
|   |-- index.html                       # Documentation portal (Vercel web app)
|   |-- vercel.json                      # Vercel routing config for docs subdomain
|
|-- environments/
|   |-- dev/
|   |   |-- backend.tf                   # S3 remote state backend config
|   |   |-- main.tf                      # Root module composition
|   |   |-- outputs.tf                   # Environment outputs
|   |   |-- providers.tf                 # AWS provider config
|   |   |-- terraform.tfvars             # Dev variable values
|   |   |-- variables.tf                 # Variable declarations
|   |-- staging/
|   |   |-- backend.tf
|   |   |-- main.tf
|   |   |-- outputs.tf
|   |   |-- providers.tf
|   |   |-- terraform.tfvars
|   |   |-- variables.tf
|   |-- prod/
|   |   |-- backend.tf
|   |   |-- main.tf
|   |   |-- outputs.tf
|   |   |-- providers.tf
|   |   |-- terraform.tfvars
|   |   |-- variables.tf
|   |-- index.html                       # Environments portal (Vercel web app)
|   |-- vercel.json                      # Vercel routing config for environments subdomain
|
|-- modules/
|   |-- acm/                             # ACM certificate management
|   |   |-- main.tf
|   |   |-- outputs.tf
|   |   |-- variables.tf
|   |-- alb/                             # Application Load Balancer
|   |   |-- main.tf
|   |   |-- outputs.tf
|   |   |-- variables.tf
|   |-- asg/                             # Auto Scaling Group + Launch Template
|   |   |-- main.tf
|   |   |-- outputs.tf
|   |   |-- variables.tf
|   |-- cloudfront/                      # CloudFront CDN distribution
|   |   |-- main.tf
|   |   |-- outputs.tf
|   |   |-- variables.tf
|   |-- cloudwatch/                      # Alarms, dashboards, log groups
|   |   |-- main.tf
|   |   |-- outputs.tf
|   |   |-- variables.tf
|   |-- iam/                             # IAM roles, policies, instance profiles
|   |   |-- main.tf
|   |   |-- outputs.tf
|   |   |-- variables.tf
|   |-- rds/                             # RDS MySQL + Secrets Manager
|   |   |-- main.tf
|   |   |-- outputs.tf
|   |   |-- variables.tf
|   |-- route53/                         # DNS alias records
|   |   |-- main.tf
|   |   |-- outputs.tf
|   |   |-- variables.tf
|   |-- s3/                              # Static assets + access logs buckets
|   |   |-- main.tf
|   |   |-- outputs.tf
|   |   |-- variables.tf
|   |-- security_groups/                 # Least-privilege SG chain
|   |   |-- main.tf
|   |   |-- outputs.tf
|   |   |-- variables.tf
|   |-- vpc/                             # VPC, subnets, IGW, NAT, route tables
|   |   |-- main.tf
|   |   |-- outputs.tf
|   |   |-- variables.tf
|   |-- index.html                       # Modules portal (Vercel web app)
|   |-- vercel.json                      # Vercel routing config for modules subdomain
|
|-- src/
|   |-- app/
|   |   |-- index.js                     # Node.js Express application entry point
|   |   |-- package.json                 # Application dependencies (express, mysql2, pg, aws-sdk)
|   |   |-- package-lock.json            # Locked dependency versions
|   |   |-- Dockerfile                   # Multi-stage production Docker build
|   |   |-- .dockerignore                # Docker build exclusions
|   |   |-- public/
|   |       |-- index.html               # Frontend operations console (served by Express)
|   |-- scripts/
|   |   |-- user_data.sh.tpl             # EC2 Auto Scaling launch bootstrap script
|   |-- index.html                       # Source code portal (Vercel web app)
|   |-- vercel.json                      # Vercel routing config for src subdomain
|
|-- .gitignore                           # Git exclusion rules
|-- Dockerfile                           # Root-level Docker build manifest
|-- index.html                           # Root operations console (Vercel main domain)
|-- package.json                         # Root Node.js manifest for Vercel
|-- vercel.json                          # Root Vercel routing and rewrites config
|-- README.md                            # This file
```

---

## Module Documentation

| Module | Description | Key Inputs | Key Outputs |
|--------|-------------|-----------|------------|
| vpc | VPC with 3-tier subnets, IGW, NAT GWs, route tables | vpc_cidr, availability_zones, single_nat_gateway | vpc_id, public_subnet_ids, private_app_subnet_ids |
| security_groups | Chained SGs: ALB to App to RDS | vpc_id, app_port, db_port | alb_security_group_id, app_security_group_id, rds_security_group_id |
| iam | EC2 role with SSM, CloudWatch, S3, Secrets Manager | s3_bucket_arns | instance_profile_name, role_arn |
| s3 | Static assets bucket (OAC) + logs bucket | cloudfront_arn, force_destroy | static_bucket_arn, logs_bucket_id |
| acm | ACM certificate with DNS validation | domain_name, hosted_zone_id | arn |
| alb | ALB with target group, HTTPS listener, HTTP redirect | certificate_arn, target_port, health_check_path | alb_dns_name, target_group_arn |
| asg | Launch template + ASG + scaling policies | instance_type, min/max/desired, user_data_base64 | asg_name, asg_arn |
| rds | MySQL Multi-AZ, KMS encryption, Secrets Manager | instance_class, multi_az, allocated_storage | db_endpoint, secret_arn |
| cloudfront | CDN with OAC (S3) + custom origin (ALB) | s3_bucket_domain_name, alb_dns_name, acm_certificate_arn | distribution_domain_name, distribution_arn |
| route53 | Alias A/AAAA records | domain_name, target_domain_name, hosted_zone_id | a_record_fqdn |
| cloudwatch | Dashboard, alarms (CPU/5xx/storage), SNS, log groups | asg_name, alb_arn_suffix, alarm_email | log_group_name, sns_topic_arn |

---

## Environment Configurations

| Parameter | Dev | Staging | Production |
|-----------|-----|---------|------------|
| Availability Zones | 2 | 2 | 3 |
| NAT Gateways | 1 (single) | 2 (multi-AZ) | 3 (multi-AZ) |
| EC2 Instance Type | t3.micro | t3.small | c6i.large |
| ASG Size (min/desired/max) | 1/1/3 | 2/2/4 | 3/3/12 |
| RDS Instance Class | db.t4g.micro | db.t4g.small | db.r6g.xlarge |
| RDS Multi-AZ | No | Yes | Yes |
| RDS Storage | 20 GB | 30 GB | 100 GB |
| Backup Retention | 7 days | 7 days | 30 days |
| Deletion Protection | No | No | Yes |
| Est. Monthly Cost | ~$97 | ~$230 | ~$1,144 |

---

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/terraform.yml`) provides:

1. On Pull Request: terraform fmt, terraform validate, Checkov security scan, terraform plan (posted as PR comment)
2. On Merge to Main: Manual approval gate, terraform apply

---

## Vercel Deployment Architecture

This project deploys five separate Vercel apps from subdirectories of a single GitHub repository:

| Vercel App | Root Directory | Purpose |
|---|---|---|
| three-tier-app | / (root) | Main operations console and serverless API |
| three-tier-app-src | src/ | Source code explorer and API sandbox |
| three-tier-app-modules | modules/ | Terraform modules visualizer |
| three-tier-app-environments | environments/ | Multi-environment dashboard |
| three-tier-app-docs | docs/ | Documentation and knowledge base |

Each subdirectory contains its own `vercel.json` for routing configuration. The root `api/index.js` provides serverless endpoints (`/api/health`, `/api/info`, `/api/db-status`, `/api/connect-db`, `/api/exec`) that power the interactive console.

---

## Documentation

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Detailed architecture deep-dive with diagrams |
| [DEPLOYMENT.md](docs/DEPLOYMENT.md) | Step-by-step deployment from init to live URL |
| [ROLLBACK.md](docs/ROLLBACK.md) | Rollback procedures for ASG, RDS, Terraform state |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | 10 common failure scenarios with diagnostic commands |
| [SECURITY.md](docs/SECURITY.md) | Security controls matrix and best practices |
| [COST_ESTIMATION.md](docs/COST_ESTIMATION.md) | Per-environment cost breakdown and optimization |
| [INTERVIEW_QUESTIONS.md](docs/INTERVIEW_QUESTIONS.md) | 20 interview Q&A with model answers |
| [ROADMAP.md](docs/ROADMAP.md) | Phased improvement roadmap (WAF, ECS, Aurora, DR) |

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/improvement`)
3. Commit changes (`git commit -am 'Add new feature'`)
4. Push to branch (`git push origin feature/improvement`)
5. Open a Pull Request -- CI will run format, validate, and security checks automatically

---

## License

This project is licensed under the MIT License.

```
MIT License

Copyright (c) 2024

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
```
