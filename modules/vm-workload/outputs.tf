output "vm_public_ip" {
  description = "Public IP address of the VM workload instance"
  value       = try(aws_instance.vm_workload[0].public_ip, null)
}

output "vm_private_ip" {
  description = "Private IP address of the VM workload instance"
  value       = try(aws_instance.vm_workload[0].private_ip, null)
}

output "vm_instance_id" {
  description = "Instance ID of the VM workload"
  value       = try(aws_instance.vm_workload[0].id, null)
}

output "vm_security_group_id" {
  description = "Security group ID for the VM workload"
  value       = try(aws_security_group.vm_workload[0].id, null)
}

output "vm_ssh_private_key_path" {
  description = "Local filesystem path to the generated SSH private key for the VM workload"
  value       = try(abspath(local_sensitive_file.vm_workload_private_key[0].filename), null)
}
