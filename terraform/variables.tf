variable "azure_region" {
  description = "Azure region for resources"
  type        = string
  default     = "Germany West Central"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "terraform-demo"
}

variable "vm_size" {
  description = "VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username for VM"
  type        = string
  default     = "azureuser"
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway"
  type        = bool
  default     = true
}
