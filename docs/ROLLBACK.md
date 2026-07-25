# Rollback Guide: AWS Three-Tier Web Application

This guide provides procedures for safely rolling back failed deployments across all tiers.

---

## 1. Rollback Decision Framework

| Scenario | Action | Time to Recovery |
|----------|--------|-----------------|
| App returning 5xx errors after deploy | Roll back ASG launch template | 5-10 min |
| Database migration broke queries | Restore RDS from snapshot | 15-30 min |
| Bad static assets deployed to S3 | Restore S3 object versions | 2-5 min |
| CloudFront serving stale/wrong content | Invalidate cache | 5-15 min |
| Terraform apply broke infrastructure | Restore Terraform state | 10-20 min |
| Complete environment failure | Full Terraform redeploy | 20-40 min |

> **Rule of thumb**: If the fix is understood and takes <15 minutes, roll forward. Otherwise, roll back immediately.

---

## 2. ASG Instance Refresh Rollback

### Cancel In-Progress Instance Refresh

```bash
ASG_NAME="three-tier-prod-asg-XXXXXXXX"

# Check current refresh status
aws autoscaling describe-instance-refreshes \
  --auto-scaling-group-name "${ASG_NAME}" \
  --query 'InstanceRefreshes[0].[InstanceRefreshId,Status,PercentageComplete]' \
  --output table

# Cancel the refresh
aws autoscaling cancel-instance-refresh \
  --auto-scaling-group-name "${ASG_NAME}"
```

### Revert to Previous Launch Template Version

```bash
LAUNCH_TEMPLATE_ID="lt-0123456789abcdef0"

# List versions
aws ec2 describe-launch-template-versions \
  --launch-template-id "${LAUNCH_TEMPLATE_ID}" \
  --query 'LaunchTemplateVersions[].[VersionNumber,CreateTime,VersionDescription]' \
  --output table

# Update ASG to use previous version
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name "${ASG_NAME}" \
  --launch-template "LaunchTemplateId=${LAUNCH_TEMPLATE_ID},Version=<PREVIOUS_VERSION>"

# Start new instance refresh with good version
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name "${ASG_NAME}" \
  --preferences '{"MinHealthyPercentage": 50, "InstanceWarmup": 300}'
```

---

## 3. RDS Snapshot Restore

### Point-in-Time Recovery (Preferred)

```bash
# Restore to a specific time (creates NEW instance)
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier "three-tier-prod-mysql" \
  --target-db-instance-identifier "three-tier-prod-mysql-restored" \
  --restore-time "2024-01-15T10:30:00Z" \
  --db-instance-class "db.r6g.xlarge" \
  --vpc-security-group-ids "sg-0123456789abcdef0" \
  --db-subnet-group-name "three-tier-prod-db-subnet-group" \
  --multi-az \
  --no-publicly-accessible

# Wait for restore to complete
aws rds wait db-instance-available \
  --db-instance-identifier "three-tier-prod-mysql-restored"
```

### Manual Snapshot Restore

```bash
# List available snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier "three-tier-prod-mysql" \
  --query 'DBSnapshots[].{ID:DBSnapshotIdentifier,Time:SnapshotCreateTime,Status:Status}' \
  --output table

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier "three-tier-prod-mysql-restored" \
  --db-snapshot-identifier "rds:three-tier-prod-mysql-2024-01-15-03-00" \
  --db-instance-class "db.r6g.xlarge" \
  --vpc-security-group-ids "sg-0123456789abcdef0" \
  --db-subnet-group-name "three-tier-prod-db-subnet-group"
```

### Swap DNS / Update Application

After restoring, update Secrets Manager or application config to point to the new RDS endpoint, then terminate the old instance.

---

## 4. Terraform State Rollback

### Restore State from S3 Versioning

```bash
STATE_BUCKET="three-tier-tf-state-prod"
STATE_KEY="prod/terraform.tfstate"

# List state file versions
aws s3api list-object-versions \
  --bucket "${STATE_BUCKET}" \
  --prefix "${STATE_KEY}" \
  --query 'Versions[].[VersionId,LastModified,Size]' \
  --output table

# Download a previous state version
aws s3api get-object \
  --bucket "${STATE_BUCKET}" \
  --key "${STATE_KEY}" \
  --version-id "PREVIOUS_VERSION_ID" \
  terraform.tfstate.backup

# Upload as current state (overwrite)
aws s3 cp terraform.tfstate.backup \
  "s3://${STATE_BUCKET}/${STATE_KEY}"

# Re-initialize Terraform to pick up the restored state
terraform init -reconfigure
terraform plan  # Verify state matches reality
```

### Force Unlock State

```bash
# If state is locked (e.g., interrupted apply)
terraform force-unlock LOCK_ID
```

---

## 5. CloudFront Cache Invalidation

```bash
CF_DIST_ID="E1234567890ABC"

# Invalidate all cached content
aws cloudfront create-invalidation \
  --distribution-id "${CF_DIST_ID}" \
  --paths "/*"

# Check invalidation status
aws cloudfront get-invalidation \
  --distribution-id "${CF_DIST_ID}" \
  --id "I1234567890ABC"
```

---

## 6. S3 Object Version Restore

Since versioning is enabled on the static assets bucket:

```bash
BUCKET="three-tier-prod-static-abcd1234"

# List object versions
aws s3api list-object-versions \
  --bucket "${BUCKET}" \
  --prefix "index.html" \
  --query 'Versions[].[VersionId,LastModified,IsLatest]' \
  --output table

# Restore a previous version by copying it over the current
aws s3api copy-object \
  --bucket "${BUCKET}" \
  --key "index.html" \
  --copy-source "${BUCKET}/index.html?versionId=PREVIOUS_VERSION_ID"
```

---

## 7. Blue/Green Deployment Notes

To implement blue/green with this architecture:

1. **Create a second ASG** ("green") with the new launch template alongside the existing one ("blue")
2. **Register green target group** with the ALB
3. **Use weighted target groups** on the ALB listener to gradually shift traffic (canary)
4. **Monitor error rates** via CloudWatch alarms during traffic shift
5. **Complete cutover** by setting green weight to 100%
6. **Drain and terminate** the blue ASG

```bash
# Modify listener rule to use weighted target groups
aws elbv2 modify-rule \
  --rule-arn "arn:aws:elasticloadbalancing:..." \
  --actions '[
    {"Type":"forward","ForwardConfig":{
      "TargetGroups":[
        {"TargetGroupArn":"arn:blue-tg","Weight":90},
        {"TargetGroupArn":"arn:green-tg","Weight":10}
      ]
    }}
  ]'
```

---

## 8. Emergency Rollback Runbook (P1 Incident)

**Time target: <15 minutes to stable state**

```
Step 1: ASSESS (1 min)
  └─ Check ALB Target Group health, CloudWatch alarms, error rates

Step 2: DECIDE (1 min)
  ├─ App code issue? → Go to Step 3
  ├─ Data issue?     → Go to Step 4
  └─ Infra issue?    → Go to Step 5

Step 3: ASG ROLLBACK (5-10 min)
  ├─ Cancel in-progress instance refresh
  ├─ Revert launch template to last known good version
  └─ Start new instance refresh

Step 4: RDS ROLLBACK (15-30 min)
  ├─ Initiate point-in-time recovery to pre-incident timestamp
  ├─ Update Secrets Manager with new endpoint
  └─ Restart application instances

Step 5: TERRAFORM STATE ROLLBACK (10-20 min)
  ├─ Download previous state from S3 versioned bucket
  ├─ Upload as current state
  └─ Run terraform plan to verify state matches reality
```

---

## 9. Post-Rollback Validation Checklist

- [ ] ALB returning 200 on `/api/health`
- [ ] CloudWatch 5xx alarm back to `OK` state
- [ ] ASG instance count matches desired capacity
- [ ] RDS connections stable (check `DatabaseConnections` metric)
- [ ] CloudFront serving correct content (test from different regions)
- [ ] Application logs clean of errors (`/aws/ec2/three-tier-*-app`)
- [ ] Incident documented with root cause and timeline
- [ ] Post-mortem scheduled within 48 hours
