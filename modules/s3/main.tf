resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# 1. Access Logs S3 Bucket
resource "aws_s3_bucket" "logs" {
  bucket        = "${var.name_prefix}-logs-${random_id.bucket_suffix.hex}"
  force_destroy = var.force_destroy

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-logs"
    }
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "log-retention"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 90
    }
  }
}

# 2. Static Assets S3 Bucket
resource "aws_s3_bucket" "static" {
  bucket        = "${var.name_prefix}-static-${random_id.bucket_suffix.hex}"
  force_destroy = var.force_destroy

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-static"
    }
  )
}

resource "aws_s3_bucket_versioning" "static" {
  bucket = aws_s3_bucket.static.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static" {
  bucket = aws_s3_bucket.static.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "static" {
  bucket                  = aws_s3_bucket.static.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket Policy allowing CloudFront OAC read access
data "aws_iam_policy_document" "static_oac" {
  count = var.cloudfront_arn != "" ? 1 : 0

  statement {
    sid       = "AllowCloudFrontServicePrincipalReadOnly"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.static.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [var.cloudfront_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "static" {
  count  = var.cloudfront_arn != "" ? 1 : 0
  bucket = aws_s3_bucket.static.id
  policy = data.aws_iam_policy_document.static_oac[0].json

  depends_on = [aws_s3_bucket_public_access_block.static]
}
