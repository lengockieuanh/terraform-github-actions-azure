resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.azure_region
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}-${var.environment}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Public Subnet
resource "azurerm_subnet" "public" {
  name                 = "${var.project_name}-${var.environment}-public-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Private Subnet
resource "azurerm_subnet" "private" {
  name                 = "${var.project_name}-${var.environment}-private-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Public IP for NAT Gateway
resource "azurerm_public_ip" "nat_gateway" {
  name                = "${var.project_name}-${var.environment}-nat-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# NAT Gateway
resource "azurerm_nat_gateway" "main" {
  count               = var.enable_nat_gateway ? 1 : 0
  name                = "${var.project_name}-${var.environment}-nat"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Standard"
}

# NAT Gateway Association
resource "azurerm_nat_gateway_public_ip_association" "main" {
  count                 = var.enable_nat_gateway ? 1 : 0
  nat_gateway_id        = azurerm_nat_gateway.main[0].id
  public_ip_address_id  = azurerm_public_ip.nat_gateway.id
}

# Associate NAT Gateway with Private Subnet
resource "azurerm_subnet_nat_gateway_association" "private" {
  count          = var.enable_nat_gateway ? 1 : 0
  subnet_id      = azurerm_subnet.private.id
  nat_gateway_id = azurerm_nat_gateway.main[0].id
}

# Public IP for VM
resource "azurerm_public_ip" "vm" {
  name                = "${var.project_name}-${var.environment}-vm-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Interface Card for VM
resource "azurerm_network_interface" "vm" {
  name                = "${var.project_name}-${var.environment}-vm-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

# Network Security Group
resource "azurerm_network_security_group" "main" {
  name                = "${var.project_name}-${var.environment}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Allow SSH
  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTP
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTPS
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Deny all other inbound traffic
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow all outbound traffic
  security_rule {
    name                       = "AllowAllOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSG with NIC
resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.vm.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# SSH Key Generation (Development use)
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "main" {
  name                = "${var.project_name}-${var.environment}-vm"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = var.vm_size

  admin_username = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  network_interface_ids = [
    azurerm_network_interface.vm.id,
  ]

  depends_on = [
    azurerm_network_interface_security_group_association.main
  ]
}

# Route Table for Public Subnet
resource "azurerm_route_table" "public" {
  name                = "${var.project_name}-${var.environment}-public-rt"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  route {
    name           = "DefaultRoute"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }
}

# Associate Route Table with Public Subnet
resource "azurerm_subnet_route_table_association" "public" {
  subnet_id      = azurerm_subnet.public.id
  route_table_id = azurerm_route_table.public.id
}

# Route Table for Private Subnet
resource "azurerm_route_table" "private" {
  name                = "${var.project_name}-${var.environment}-private-rt"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Associate Route Table with Private Subnet
resource "azurerm_subnet_route_table_association" "private" {
  subnet_id      = azurerm_subnet.private.id
  route_table_id = azurerm_route_table.private.id
}
