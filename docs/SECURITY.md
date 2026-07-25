# Security Best Practices: AWS Three-Tier Web Application

---

## Security Controls Matrix

| Control Category | Control | Status | Implementation |
|-----------------|---------|--------|---------------|
| **Network** | VPC network segmentation (3-tier subnets) | ✅ Implemented | `modules/vpc` |
| **Network** | Security Groups least-privilege chain | ✅ Implemented | `modules/security_groups` |
| **Network** | Private data subnets isolated (no internet route) | ✅ Implemented | `modules/vpc` |
| **Network** | No SSH keys - SSM Session Manager only | ✅ Implemented | `modules/iam` |
| **Network** | VPC Flow Logs | ⚠️ Recommended | Future roadmap |
| **Encryption** | S3 encryption at rest (AES-256) | ✅ Implemented | `modules/s3` |
| **Encryption** | RDS encryption at rest (KMS CMK) | ✅ Implemented | `modules/rds` |
| **Encryption** | KMS key rotation enabled | ✅ Implemented | `modules/rds` |
| **Encryption** | TLS 1.2/1.3 in transit (ALB + CloudFront) | ✅ Implemented | `modules/alb`, `modules/cloudfront` |
| **Encryption** | HTTPS enforced (HTTP→HTTPS redirect) | ✅ Implemented | `modules/alb` |
| **IAM** | EC2 Instance Profile (least-privilege) | ✅ Implemented | `modules/iam` |
| **IAM** | IMDSv2 enforced (no IMDSv1) | ✅ Implemented | `modules/asg` |
| **IAM** | No wildcard resource ARNs (except Secrets Manager) | ✅ Implemented | `modules/iam` |
| **Secrets** | DB credentials in Secrets Manager | ✅ Implemented | `modules/rds` |
| **Secrets** | No hardcoded secrets in code/Terraform | ✅ Implemented | All modules |
| **Data** | S3 public access blocked (all 4 settings) | ✅ Implemented | `modules/s3` |
| **Data** | CloudFront OAC (not legacy OAI) | ✅ Implemented | `modules/cloudfront` |
| **Data** | RDS not publicly accessible | ✅ Implemented | `modules/rds` |
| **Monitoring** | CloudWatch Alarms (CPU, 5xx, storage) | ✅ Implemented | `modules/cloudwatch` |
| **Monitoring** | CloudWatch Log Groups with retention | ✅ Implemented | `modules/cloudwatch` |
| **Monitoring** | AWS CloudTrail | ⚠️ Recommended | Future roadmap |
| **Detection** | AWS GuardDuty | ⚠️ Recommended | Future roadmap |
| **Compliance** | AWS Config Rules | ⚠️ Recommended | Future roadmap |
| **Perimeter** | AWS WAF on CloudFront/ALB | ⚠️ Recommended | Future roadmap |

---

## 1. Network Security

### VPC Network Segmentation

The architecture uses three distinct subnet tiers:

| Subnet Tier | Internet Access | NAT Egress | Purpose |
|------------|----------------|------------|---------|
| **Public** | Yes (IGW) | N/A | ALB, NAT Gateways |
| **Private-App** | No | Yes (NAT GW) | EC2 app instances |
| **Private-Data** | No | No | RDS database (isolated) |

- **Data subnets have NO route to the internet** — not even via NAT Gateway. This is intentional isolation.
- EC2 instances in app subnets can reach the internet only via NAT Gateway for package updates, SSM API calls, and Secrets Manager.

### Security Group Chain (Least Privilege)

```
Internet (0.0.0.0/0) ──[80,443]──► ALB SG ──[8080]──► App SG ──[3306]──► RDS SG
```

- **ALB SG**: Accepts HTTP/HTTPS from anywhere (public-facing)
- **App SG**: Accepts port 8080 **only from ALB SG** (not CIDR)
- **RDS SG**: Accepts port 3306 **only from App SG** (not CIDR), **no egress allowed**

### No SSH Access

- EC2 instances have **no SSH key pairs** and **port 22 is not open** in any security group
- Access is exclusively via **AWS SSM Session Manager**, which:
  - Requires IAM authentication
  - Provides audit trail in CloudTrail
  - Doesn't require inbound network access

---

## 2. Encryption

### At Rest

| Resource | Encryption | Key Management |
|----------|-----------|---------------|
| S3 Static Bucket | AES-256 (SSE-S3) | AWS-managed keys |
| S3 Logs Bucket | AES-256 (SSE-S3) | AWS-managed keys |
| RDS MySQL | AES-256 | KMS Customer-Managed Key (CMK) with annual rotation |
| Terraform State (S3) | AES-256 | AWS-managed keys |

### In Transit

| Connection | Protocol | Minimum Version |
|-----------|----------|----------------|
| Client → CloudFront | TLS | 1.2 (TLSv1.2_2021 policy) |
| Client → ALB | TLS | 1.2 (ELBSecurityPolicy-TLS13-1-2-2021-06) |
| ALB → EC2 | HTTP | Port 8080 (within VPC, encrypted at network level) |
| EC2 → RDS | MySQL/TLS | TLS available via `require_secure_transport` parameter |

---

## 3. Identity & Access Management

### EC2 Instance Profile Policies

The EC2 IAM role has exactly these managed/inline policies:

| Policy | Scope | Justification |
|--------|-------|--------------|
| `AmazonSSMManagedInstanceCore` | AWS Managed | SSM Session Manager access (no SSH) |
| `CloudWatchAgentServerPolicy` | AWS Managed | Push logs and custom metrics |
| Custom: S3 Read | `s3:GetObject`, `s3:ListBucket` on specific bucket ARNs | Read static assets |
| Custom: Secrets Manager | `secretsmanager:GetSecretValue` on `*` | Retrieve DB credentials at boot |

> [!NOTE]
> The Secrets Manager policy uses `*` resource because the secret ARN is not known at IAM policy creation time (circular dependency). In production, scope this to `arn:aws:secretsmanager:REGION:ACCOUNT:secret:three-tier-*`.

### IMDSv2 Enforcement

```hcl
metadata_options {
  http_endpoint               = "enabled"
  http_tokens                 = "required"  # IMDSv2 only
  http_put_response_hop_limit = 1           # Prevent SSRF token theft
}
```

This prevents SSRF attacks from extracting instance credentials via the metadata service.

---

## 4. Secrets Management

- **No hardcoded passwords**: RDS master password is auto-generated by `random_password` and stored in AWS Secrets Manager
- **No secrets in `.tfvars`**: Password variable defaults to empty; Terraform generates it
- **EC2 retrieves credentials at boot**: `user_data.sh.tpl` fetches from Secrets Manager via IAM role
- **Secrets Manager rotation**: Recommended to enable automatic rotation (30-60 day interval)

---

## 5. Data Protection

### S3 Public Access Block

All 4 public access block settings are enabled on both buckets:

```hcl
block_public_acls       = true
block_public_policy     = true
ignore_public_acls      = true
restrict_public_buckets = true
```

### CloudFront Origin Access Control (OAC)

- Uses modern OAC (not legacy OAI) for S3 access
- S3 bucket policy restricts access to CloudFront service principal with `AWS:SourceArn` condition
- Direct S3 URL access is denied

---

## 6. WAF Recommendation

Add AWS WAF to CloudFront and ALB with these managed rule groups:

| Rule Group | Purpose |
|-----------|---------|
| `AWSManagedRulesCommonRuleSet` | OWASP Top 10 protection |
| `AWSManagedRulesSQLiRuleSet` | SQL injection prevention |
| `AWSManagedRulesKnownBadInputsRuleSet` | Log4j, path traversal |
| `AWSManagedRulesAmazonIpReputationList` | Known malicious IPs |
| `AWSManagedRulesBotControlRuleSet` | Bot management |
| Rate-based rule | DDoS layer 7 protection (2000 req/5min) |

---

## 7. Additional Recommendations

| Service | Purpose | Priority |
|---------|---------|----------|
| **AWS GuardDuty** | Threat detection (reconnaissance, compromised instances) | P0 |
| **AWS CloudTrail** | API call audit logging | P0 |
| **AWS Config** | Resource compliance monitoring | P1 |
| **VPC Flow Logs** | Network traffic analysis | P1 |
| **AWS Security Hub** | Centralized security findings | P2 |
| **AWS Inspector** | EC2 vulnerability scanning | P2 |

---

## 8. Security Hardening Checklist

- [x] VPC with 3-tier network segmentation
- [x] Security Groups using SG-to-SG references (not CIDRs)
- [x] No SSH / port 22 access — SSM only
- [x] IMDSv2 enforced on all EC2 instances
- [x] S3 public access blocked on all buckets
- [x] RDS encrypted with KMS CMK, key rotation enabled
- [x] RDS not publicly accessible
- [x] HTTPS enforced via HTTP→HTTPS redirect
- [x] TLS 1.2+ minimum on ALB and CloudFront
- [x] Secrets in AWS Secrets Manager (not in code)
- [x] CloudFront OAC (not legacy OAI)
- [x] CloudWatch alarms for anomaly detection
- [ ] Enable AWS WAF on CloudFront/ALB
- [ ] Enable GuardDuty for threat detection
- [ ] Enable CloudTrail for audit logging
- [ ] Enable VPC Flow Logs
- [ ] Enable Secrets Manager automatic rotation
- [ ] Scope Secrets Manager IAM policy to specific ARN
