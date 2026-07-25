# Troubleshooting Guide: AWS Three-Tier Web Application

---

## 1. ALB 502 Bad Gateway

**Symptoms**: Users see `502 Bad Gateway`. ALB access logs show `502` responses.

**Root Causes**:
- EC2 instances not listening on target port (8080)
- Application crashed or not started
- Security group blocking ALB → EC2 traffic

**Diagnostic Commands**:
```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn "arn:aws:elasticloadbalancing:..." \
  --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table

# Check if app is listening on instance (via SSM)
aws ssm start-session --target i-0123456789abc
# Inside instance:
sudo systemctl status three-tier-app
sudo ss -tlnp | grep 8080
sudo journalctl -u three-tier-app --no-pager -n 50

# Check Security Group allows traffic
aws ec2 describe-security-groups --group-ids sg-app123 \
  --query 'SecurityGroups[].IpPermissions[]'
```

**Fix**: Restart the app service, fix user_data errors, or correct security group rules.

**Prevention**: Implement ALB health check with appropriate thresholds. Monitor target health via CloudWatch.

---

## 2. ALB 503 Service Unavailable

**Symptoms**: All targets unhealthy. ALB returns `503`.

**Root Causes**:
- ASG scaled to 0 instances
- All instances failing health checks
- Launch template has invalid AMI ID

**Diagnostic Commands**:
```bash
# Check ASG instance count
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "three-tier-prod-asg-xxx" \
  --query 'AutoScalingGroups[].[DesiredCapacity,MinSize,MaxSize,Instances[].HealthStatus]'

# Check recent ASG activity
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name "three-tier-prod-asg-xxx" \
  --max-items 10 \
  --query 'Activities[].[StatusCode,Description,StartTime]' \
  --output table
```

**Fix**: Ensure min_size >= 1, fix launch template, or manually set desired capacity.

---

## 3. ASG Not Scaling

**Symptoms**: High CPU / request count but no new instances launching.

**Root Causes**:
- Scaling policy not attached or misconfigured
- ASG already at `max_size`
- EC2 instance limits reached in account
- Launch template AMI not found or instance type unavailable

**Diagnostic Commands**:
```bash
# Check scaling policies
aws autoscaling describe-policies \
  --auto-scaling-group-name "three-tier-prod-asg-xxx" \
  --output table

# Check ASG limits
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "three-tier-prod-asg-xxx" \
  --query 'AutoScalingGroups[].[MinSize,MaxSize,DesiredCapacity]'

# Check EC2 service limits
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A
```

**Fix**: Increase `max_size`, request EC2 limit increase, or fix launch template configuration.

---

## 4. RDS Connection Timeouts

**Symptoms**: Application logs show `ETIMEDOUT` or `Connection refused` to RDS.

**Root Causes**:
- RDS security group doesn't allow port 3306 from app security group
- Wrong RDS endpoint in application config
- Max connections exceeded
- RDS instance in `maintenance` or `rebooting` state

**Diagnostic Commands**:
```bash
# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier "three-tier-prod-mysql" \
  --query 'DBInstances[].[DBInstanceStatus,Endpoint.Address,Endpoint.Port]'

# Check security group rules
aws ec2 describe-security-groups --group-ids sg-rds123 \
  --query 'SecurityGroups[].IpPermissions[]'

# Check current connections (CloudWatch)
aws cloudwatch get-metric-statistics \
  --namespace "AWS/RDS" \
  --metric-name "DatabaseConnections" \
  --dimensions Name=DBInstanceIdentifier,Value=three-tier-prod-mysql \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 --statistics Maximum

# Test connection from EC2 (via SSM)
# Inside instance:
mysql -h <rds-endpoint> -u admin -p -e "SELECT 1;"
```

**Fix**: Correct security group rules, verify Secrets Manager secret has correct endpoint, or increase `max_connections` parameter.

---

## 5. CloudFront 403 Forbidden

**Symptoms**: Static assets return `403 Access Denied` from CloudFront.

**Root Causes**:
- Origin Access Control (OAC) not configured correctly
- S3 bucket policy missing or incorrect
- Object doesn't exist in S3 (returns 403 instead of 404 when public access blocked)
- S3 public access block preventing CloudFront access

**Diagnostic Commands**:
```bash
# Check CloudFront distribution origin config
aws cloudfront get-distribution-config \
  --id "E1234567890ABC" \
  --query 'DistributionConfig.Origins.Items[].[Id,DomainName,OriginAccessControlId]'

# Check S3 bucket policy
aws s3api get-bucket-policy --bucket "three-tier-prod-static-xxx" | jq .

# Check if object exists
aws s3 ls "s3://three-tier-prod-static-xxx/index.html"

# Test direct S3 access with credentials
aws s3api head-object --bucket "three-tier-prod-static-xxx" --key "index.html"
```

**Fix**: Ensure S3 bucket policy allows `s3:GetObject` from CloudFront service principal with `AWS:SourceArn` condition matching the distribution ARN. Upload missing objects.

---

## 6. ACM Validation Stuck in `PENDING_VALIDATION`

**Symptoms**: ACM certificate status stays `PENDING_VALIDATION` for >30 minutes.

**Root Causes**:
- DNS CNAME validation records not created or propagated
- Records created in wrong hosted zone
- Conflicting CNAME record already exists
- Using Route53 in different account than ACM

**Diagnostic Commands**:
```bash
# Check required validation records
aws acm describe-certificate \
  --certificate-arn "arn:aws:acm:us-east-1:..." \
  --query 'Certificate.DomainValidationOptions[].[DomainName,ValidationStatus,ResourceRecord]' \
  --output table

# Check if DNS records exist
dig _acme-challenge.yourdomain.com CNAME +short

# Check Route53 for the validation record
aws route53 list-resource-record-sets \
  --hosted-zone-id "Z1234567890ABC" \
  --query "ResourceRecordSets[?Type=='CNAME']"
```

**Fix**: Create the CNAME records shown in `DomainValidationOptions`. Ensure they're in the correct hosted zone. Wait up to 72 hours for DNS propagation in worst case.

---

## 7. EC2 User Data Failures

**Symptoms**: Instances launch but application doesn't start. Health checks fail.

**Diagnostic Commands**:
```bash
# Connect via SSM and check logs
aws ssm start-session --target i-0123456789abc

# Inside instance:
cat /var/log/user-data.log
sudo journalctl -u three-tier-app --no-pager
cat /opt/three-tier-app/.env  # Check env vars (permissions required)
node -v  # Verify Node.js installed
ls -la /opt/three-tier-app/   # Verify files exist
```

**Fix**: Fix the user_data.sh.tpl template, update launch template, trigger ASG instance refresh.

---

## 8. SSM Session Manager Connection Issues

**Symptoms**: `aws ssm start-session` fails with `TargetNotConnected`.

**Root Causes**:
- EC2 instance missing `AmazonSSMManagedInstanceCore` IAM policy
- No NAT Gateway for outbound SSM API calls from private subnet
- SSM agent not running on instance

**Diagnostic Commands**:
```bash
# Check instance IAM role
aws ec2 describe-instances --instance-ids i-0123456789abc \
  --query 'Reservations[].Instances[].IamInstanceProfile.Arn'

# Check SSM managed instances
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=i-0123456789abc"

# Check NAT Gateway status
aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available" \
  --query 'NatGateways[].[NatGatewayId,SubnetId,State]'
```

**Fix**: Attach correct IAM policy, ensure NAT Gateway exists and route table for private subnet points to it.

---

## 9. Terraform State Lock Issues

**Symptoms**: `Error acquiring the state lock` when running terraform commands.

**Diagnostic Commands**:
```bash
# Check DynamoDB lock table
aws dynamodb scan --table-name "three-tier-tf-locks-prod" \
  --query 'Items[]' --output json
```

**Fix**:
```bash
# Force unlock (use with caution - ensure no other apply is running)
terraform force-unlock <LOCK_ID>

# If DynamoDB item is stuck, delete it directly
aws dynamodb delete-item \
  --table-name "three-tier-tf-locks-prod" \
  --key '{"LockID":{"S":"three-tier-tf-state-prod/prod/terraform.tfstate"}}'
```

---

## 10. CloudWatch Alarms Not Firing

**Symptoms**: High CPU/errors but no alarm notifications.

**Root Causes**:
- Wrong metric dimensions (e.g., wrong ASG name)
- SNS subscription not confirmed (email pending)
- Alarm evaluation period too long
- Alarm in `INSUFFICIENT_DATA` state

**Diagnostic Commands**:
```bash
# Check alarm state
aws cloudwatch describe-alarms \
  --alarm-names "three-tier-prod-asg-high-cpu" \
  --query 'MetricAlarms[].[AlarmName,StateValue,MetricName,Dimensions]'

# Check SNS subscription status
aws sns list-subscriptions-by-topic \
  --topic-arn "arn:aws:sns:us-east-1:...:three-tier-prod-alarms-topic" \
  --query 'Subscriptions[].[Endpoint,SubscriptionArn]'
```

**Fix**: Verify alarm dimensions match actual resource names. Confirm SNS email subscription. Adjust evaluation period/threshold.
