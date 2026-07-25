# Cost Estimation: AWS Three-Tier Web Application

> All pricing based on AWS us-east-1 (N. Virginia) On-Demand rates as of 2024. Actual costs may vary.

---

## Development Environment (~$150–200/month)

| Service | Configuration | Monthly Cost |
|---------|--------------|-------------|
| **VPC** | 1 VPC, subnets, route tables | $0.00 |
| **NAT Gateway** | 1x NAT Gateway (single AZ) | $32.40 |
| **NAT Data Processing** | ~10 GB/month | $4.50 |
| **Elastic IP** | 1x EIP attached | $0.00 |
| **ALB** | 1x ALB, ~10 LCU-hours/day | $22.27 |
| **EC2 (ASG)** | 1x t3.micro (On-Demand) | $7.59 |
| **RDS MySQL** | 1x db.t4g.micro, Single-AZ, 20GB gp3 | $12.41 |
| **S3** | 2 buckets, ~5GB storage, 10K requests | $0.15 |
| **CloudFront** | ~10 GB transfer, 100K requests | $1.35 |
| **Route 53** | 1 hosted zone, ~100K queries | $0.54 |
| **ACM** | 1 certificate | $0.00 |
| **CloudWatch** | 3 alarms, 1 dashboard, 5GB logs | $13.00 |
| **Secrets Manager** | 1 secret, ~100 API calls | $0.40 |
| **KMS** | 1 CMK, ~100 requests | $1.03 |
| **Data Transfer** | ~20 GB outbound | $1.80 |
| **Total (Dev)** | | **~$97/month** |

---

## Staging Environment (~$350–450/month)

| Service | Configuration | Monthly Cost |
|---------|--------------|-------------|
| **VPC** | 1 VPC, subnets, route tables | $0.00 |
| **NAT Gateway** | 2x NAT Gateways (multi-AZ) | $64.80 |
| **NAT Data Processing** | ~30 GB/month | $13.50 |
| **Elastic IPs** | 2x EIP attached | $0.00 |
| **ALB** | 1x ALB, ~25 LCU-hours/day | $38.27 |
| **EC2 (ASG)** | 2x t3.small (On-Demand) | $30.37 |
| **RDS MySQL** | 1x db.t4g.small, Multi-AZ, 30GB gp3 | $49.06 |
| **S3** | 2 buckets, ~20GB storage, 50K requests | $0.52 |
| **CloudFront** | ~50 GB transfer, 500K requests | $5.75 |
| **Route 53** | 1 hosted zone, ~500K queries | $0.70 |
| **ACM** | 1 certificate | $0.00 |
| **CloudWatch** | 3 alarms, 1 dashboard, 15GB logs | $20.00 |
| **Secrets Manager** | 1 secret, ~500 API calls | $0.42 |
| **KMS** | 1 CMK, ~500 requests | $1.15 |
| **Data Transfer** | ~60 GB outbound | $5.40 |
| **Total (Staging)** | | **~$230/month** |

---

## Production Environment (~$1,500–2,500/month)

| Service | Configuration | Monthly Cost |
|---------|--------------|-------------|
| **VPC** | 1 VPC, subnets, route tables | $0.00 |
| **NAT Gateway** | 3x NAT Gateways (3 AZs, HA) | $97.20 |
| **NAT Data Processing** | ~200 GB/month | $90.00 |
| **Elastic IPs** | 3x EIP attached | $0.00 |
| **ALB** | 1x ALB, ~100 LCU-hours/day | $82.27 |
| **EC2 (ASG)** | 3x c6i.large (On-Demand) | $183.96 |
| **RDS MySQL** | 1x db.r6g.xlarge, Multi-AZ, 100GB gp3 | $549.60 |
| **S3** | 2 buckets, ~100GB storage, 1M requests | $2.74 |
| **CloudFront** | ~500 GB transfer, 5M requests | $51.50 |
| **Route 53** | 1 hosted zone, ~5M queries | $2.50 |
| **ACM** | 1 certificate | $0.00 |
| **CloudWatch** | 3 alarms, 1 dashboard, 50GB logs | $40.00 |
| **Secrets Manager** | 1 secret, ~5K API calls | $0.60 |
| **KMS** | 1 CMK, ~5K requests | $1.30 |
| **Data Transfer** | ~500 GB outbound | $42.50 |
| **Total (Prod)** | | **~$1,144/month** |

---

## Annual Cost Projection

| Environment | Monthly | Annual |
|-------------|---------|--------|
| Development | ~$97 | ~$1,164 |
| Staging | ~$230 | ~$2,760 |
| Production | ~$1,144 | ~$13,728 |
| **All Environments** | **~$1,471** | **~$17,652** |

---

## Cost-Optimized Production Alternative

| Change | Standard Config | Optimized Config | Monthly Savings |
|--------|----------------|-----------------|----------------|
| NAT Gateway | 3x NAT GW ($97.20) | 1x NAT GW ($32.40) | $64.80 |
| NAT Data | 3-AZ processing ($90) | Single NAT ($30) | $60.00 |
| EC2 Instances | 3x c6i.large On-Demand ($184) | 3x c6i.large 1yr RI ($110) | $73.96 |
| RDS Instance | db.r6g.xlarge Multi-AZ ($550) | db.r6g.large Single-AZ ($200) | $349.60 |
| CloudFront | PriceClass_100 ($51.50) | PriceClass_100 ($51.50) | $0.00 |
| CloudWatch Logs | 50GB ($40) | 20GB retained ($20) | $20.00 |
| **Total** | **~$1,144/month** | **~$576/month** | **~$568/month (50% savings)** |

> [!WARNING]
> The cost-optimized variant trades high availability and performance for savings. **Not recommended for mission-critical production workloads.** Single NAT Gateway creates a single point of failure for AZ outage; Single-AZ RDS has no automatic failover.

---

## Top Cost Optimization Recommendations

1. **Reserved Instances / Savings Plans**: Commit to 1-year or 3-year terms for EC2 and RDS for 30–60% savings
2. **Right-sizing**: Use AWS Compute Optimizer to identify over-provisioned instances
3. **Spot Instances**: Use Spot for non-critical ASG capacity (mixed instance policy)
4. **S3 Intelligent Tiering**: Automatically move infrequently accessed static assets to cheaper tiers
5. **NAT Gateway Alternatives**: Consider NAT instances (t4g.nano ~$3/month) for dev environments
6. **Log Retention Policies**: Set aggressive retention on non-critical log groups
7. **Scheduled Scaling**: Scale down dev/staging ASG to 0 instances outside business hours
8. **CloudFront Caching**: Maximize cache hit ratio to reduce ALB origin requests
