# Architecture Deep Dive: AWS Three-Tier Web Infrastructure

This document provides a comprehensive technical breakdown of the production-ready AWS Three-Tier Web Application deployed via Terraform.

## Tiered Architecture Diagram

```mermaid
flowchart TD
    subgraph Edge ["Edge Tier (DNS & CDN)"]
        User(["Client Browser"])
        R53["Route 53 Hosted Zone"]
        ACM_CF["ACM Certificate (us-east-1)"]
        CF["CloudFront CDN Distribution"]
        S3_Static["S3 Bucket: Static Assets (OAC Enforced)"]
    end

    subgraph VPC ["AWS Virtual Private Cloud (10.0.0.0/16)"]
        subgraph PublicSubnets ["Public Subnets (AZ1, AZ2, AZ3)"]
            IGW["Internet Gateway"]
            NAT["NAT Gateways (Egress Only)"]
            ALB["Application Load Balancer (Public)"]
            ACM_ALB["ACM Certificate (Regional)"]
        end

        subgraph PrivateAppSubnets ["Private Application Subnets (AZ1, AZ2, AZ3)"]
            ASG["Auto Scaling Group"]
            EC2_1["EC2 Instance (AZ1)"]
            EC2_2["EC2 Instance (AZ2)"]
            EC2_3["EC2 Instance (AZ3)"]
            SSM["AWS SSM Session Manager"]
            CW_Agent["CloudWatch Logs Agent"]
        end

        subgraph PrivateDataSubnets ["Isolated Private Data Subnets (AZ1, AZ2, AZ3)"]
            RDS_Primary["RDS MySQL Primary (AZ1)"]
            RDS_Standby["RDS MySQL Standby (AZ2)"]
            KMS["KMS Managed Key"]
            SM["AWS Secrets Manager"]
        end
    end

    User -->|DNS Query| R53
    User -->|HTTPS Request| CF
    CF -->|Static Content GET /index.html| S3_Static
    CF -->|Dynamic API Route /api/*| ALB
    ALB -->|Forward Port 8080| ASG
    ASG --> EC2_1 & EC2_2 & EC2_3
    EC2_1 & EC2_2 & EC2_3 -->|Fetch Credentials| SM
    EC2_1 & EC2_2 & EC2_3 -->|SQL 3306| RDS_Primary
    RDS_Primary -.->|Synchronous Replication| RDS_Standby
    EC2_1 & EC2_2 & EC2_3 -->|Egress via NAT| NAT --> IGW -->|Outbound Updates| User
    EC2_1 & EC2_2 & EC2_3 -.->|Logs & Metrics| CW_Agent
```

---

## Detailed Component Breakdown

### 1. Presentation Tier (Edge)
- **Route 53**: Resolves custom apex and subdomain requests using latency-based Alias A/AAAA records pointing directly to CloudFront distribution edge locations.
- **ACM SSL/TLS**: CloudFront uses a 2048-bit RSA / ECDSA certificate requested in `us-east-1` with DNS validation. ALB uses a separate regional ACM certificate.
- **CloudFront CDN**: Configured with Origin Access Control (OAC) to sign requests to the private S3 bucket. Low latency static assets cached globally; `/api/*` traffic forwarded to ALB origin without caching (`Cache-Control: no-cache`).

### 2. Application Tier (Compute)
- **Multi-AZ Network Layout**: Spans 3 Availability Zones (`us-east-1a`, `us-east-1b`, `us-east-1c`).
- **Application Load Balancer (ALB)**: Listens on port 80 (HTTP 301 redirect to HTTPS) and port 443. Performs active health checks against target instances at `/api/health`.
- **Auto Scaling Group (ASG)**: Bootstraps Amazon Linux 2023 instances running Node.js / Express web services via systemd. Scales dynamically using dual target tracking policies:
  - Average CPU Utilization = 70%
  - ALB Request Count Per Target = 1000 requests/instance

### 3. Data Tier (Persistence)
- **RDS MySQL Multi-AZ**: Primary node in AZ1, synchronous block-level standby node in AZ2. Automatic failover under 60 seconds.
- **Storage & KMS**: AES-256 storage encryption backed by AWS KMS customer-managed key. Automated snapshots retained for 7 to 30 days.
- **Secrets Management**: DB master credentials automatically generated, stored, and rotated inside AWS Secrets Manager. EC2 instances retrieve secrets via IAM Role + IAM policy without hardcoded credentials.

---

## Least Privilege Network Matrix

| Source Security Group | Destination Security Group | Allowed Port | Protocol | Purpose |
|-----------------------|----------------------------|--------------|----------|---------|
| Internet (`0.0.0.0/0`) | `alb-sg` | 80, 443 | TCP | Public Web Traffic |
| `alb-sg` | `app-sg` | 8080 | TCP | Load Balancer to EC2 App Instances |
| `app-sg` | `rds-sg` | 3306 | TCP | EC2 App Instances to MySQL Database |
| `app-sg` | Internet (`0.0.0.0/0`) via NAT | 443 | TCP | Outbound AWS API Calls (SSM, Secrets Manager, CloudWatch) |
