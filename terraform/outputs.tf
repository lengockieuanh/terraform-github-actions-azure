output "vm_public_ip" {
  description = "Public IP of the VM"
  value       = azurerm_public_ip.vm.ip_address
}

output "vm_private_ip" {
  description = "Private IP of the VM"
  value       = azurerm_network_interface.vm.private_ip_address
}

output "nat_gateway_public_ip" {
  description = "Public IP of NAT Gateway"
  value       = azurerm_public_ip.nat_gateway.ip_address
}

output "resource_group_name" {
  description = "Resource Group name"
  value       = azurerm_resource_group.main.name
}

output "vm_id" {
  description = "VM ID"
  value       = azurerm_linux_virtual_machine.main.id
}

output "nsg_id" {
  description = "Network Security Group ID"
  value       = azurerm_network_security_group.main.id
}

output "vnet_id" {
  description = "Virtual Network ID"
  value       = azurerm_virtual_network.main.id
}

output "ssh_private_key" {
  description = "SSH Private Key"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}
