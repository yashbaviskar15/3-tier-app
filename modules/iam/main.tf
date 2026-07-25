# Assume Role Policy for EC2
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# EC2 Instance IAM Role
resource "aws_iam_role" "ec2" {
  name               = "${var.name_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-ec2-role"
    }
  )
}

# Attach AWS Managed Policy for SSM Session Manager (No SSH keys required)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach AWS Managed Policy for CloudWatch Agent
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Least-privilege policy for S3 bucket read access & Secrets Manager get secret
data "aws_iam_policy_document" "app_permissions" {
  statement {
    sid       = "S3ReadAccess"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = length(var.s3_bucket_arns) > 0 ? concat(var.s3_bucket_arns, [for arn in var.s3_bucket_arns : "${arn}/*"]) : ["*"]
  }

  statement {
    sid       = "SecretsManagerGetSecret"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "app_permissions" {
  name        = "${var.name_prefix}-app-policy"
  description = "Allows S3 read access and Secrets Manager access for the application"
  policy      = data.aws_iam_policy_document.app_permissions.json
}

resource "aws_iam_role_policy_attachment" "app_permissions" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.app_permissions.arn
}

# EC2 Instance Profile
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.name_prefix}-ec2-instance-profile"
  role = aws_iam_role.ec2.name

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-ec2-instance-profile"
    }
  )
}
