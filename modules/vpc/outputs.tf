output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "List of IDs of private application subnets"
  value       = aws_subnet.private_app[*].id
}

output "private_data_subnet_ids" {
  description = "List of IDs of private database subnets"
  value       = aws_subnet.private_data[*].id
}

output "nat_gateway_ips" {
  description = "List of Public Elastic IP addresses associated with NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}
