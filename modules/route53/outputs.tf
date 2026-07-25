output "a_record_fqdn" {
  description = "FQDN of the Route53 A record"
  value       = aws_route53_record.alias_a.fqdn
}

output "aaaa_record_fqdn" {
  description = "FQDN of the Route53 AAAA record"
  value       = aws_route53_record.alias_aaaa.fqdn
}
