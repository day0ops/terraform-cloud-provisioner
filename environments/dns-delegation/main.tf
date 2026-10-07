# Cloud-neutral: delegates a child zone hosted in ANY provider's native DNS (Cloud DNS,
# Azure DNS, or a second Route53 account) from the primary Route53 parent zone, via a plain
# NS record. Doesn't know or care which cloud created the child zone -- only its name servers.
resource "aws_route53_record" "child_ns" {
  zone_id = var.dns_parent_zone_id
  name    = "${var.dns_child_zone_name}.${var.dns_parent_domain}"
  type    = "NS"
  ttl     = 300
  records = var.dns_child_nameservers
}
