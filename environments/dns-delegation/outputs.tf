output "fqdn" {
  value       = aws_route53_record.child_ns.name
  description = "Fully-qualified child zone name the delegation record was created for"
}
