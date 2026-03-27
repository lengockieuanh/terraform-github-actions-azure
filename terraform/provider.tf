terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
  # Lưu trạng thái .tfstate lên Azure Blob Storage
  backend "azurerm" {
    resource_group_name  = "rg-terraform-test"
    storage_account_name = "tfstateahrtest"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}
