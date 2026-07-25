# Route53 Alias A Record
resource "aws_route53_record" "alias_a" {
  zone_id = var.hosted_zone_id
  name    = var.record_name != "" ? "${var.record_name}.${var.domain_name}" : var.domain_name
  type    = "A"

  alias {
    name                   = var.target_domain_name
    zone_id                = var.target_zone_id
    evaluate_target_health = true
  }
}

# Route53 Alias AAAA Record for IPv6
resource "aws_route53_record" "alias_aaaa" {
  zone_id = var.hosted_zone_id
  name    = var.record_name != "" ? "${var.record_name}.${var.domain_name}" : var.domain_name
  type    = "AAAA"

  alias {
    name                   = var.target_domain_name
    zone_id                = var.target_zone_id
    evaluate_target_health = true
  }
}
