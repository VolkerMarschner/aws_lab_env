#########################
#  create VPC
#################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.prefix}-VPC"
    
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"

  tags = {
    Name = "${var.vpc_name}-public-subnet"
  }
}

# Private Subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "${var.region}b"

  tags = {
    Name = "private-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "${var.vpc_name}-nat-gw"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.vpc_name}-public-rt"
  }
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.vpc_name}-private-rt"
  }
}

# Associate public subnet with public route table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Associate private subnet with private route table
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

###################################
# Create SGs for Jumphost and WLs
###################################

# Security group for Jumphost instance
resource "aws_security_group" "Jumphost-SG" {
  name        = "${var.prefix}-Jumphost-SG"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}

# Security group for Workload instances
resource "aws_security_group" "workload-sg" {
  name        = "${var.prefix}-Workload-SG"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow Any"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_Any"
  }
}


# Create SSH Keys and Passwords
##################################

# Create SSH key for JH (Jump Host)
resource "tls_private_key" "jh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "jh_key_pair" {
  key_name   = "${var.prefix}-JH"
  public_key = tls_private_key.jh_key.public_key_openssh
}

# Create SSH key for WL (Workload)
resource "tls_private_key" "wl_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "wl_key_pair" {
  key_name   = "${var.prefix}-WL"
  public_key = tls_private_key.wl_key.public_key_openssh
}

# Save private keys to local files
resource "local_file" "jh_private_key" {
  content  = tls_private_key.jh_key.private_key_pem
  filename = "${path.module}/${var.prefix}-JH-private-key.pem"
}

resource "local_file" "wl_private_key" {
  content  = tls_private_key.wl_key.private_key_pem
  filename = "${path.module}/${var.prefix}-WL-private-key.pem"
}

# Fetch AMI Information
##########################

data "aws_ami" "windows" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}



# Create EC2 Instances
##########################

# create Jumphost
# create  Jumphost EC2 instances
resource "aws_instance" "jh-linux" {
  count                  = 1
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.Jumphost-SG.id]
  key_name               = aws_key_pair.jh_key_pair.key_name
  subnet_id              = aws_subnet.public.id

  tags = {
    Name = "${var.prefix}-Jumphost"
  }
}

# create  WorkloadLinux EC2 instances
resource "aws_instance" "linux" {
  count                  = var.linux_instance_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.workload-sg.id]
  key_name               = aws_key_pair.wl_key_pair.key_name
  subnet_id              = aws_subnet.private.id

  tags = {
    Name = "${var.prefix}-WL-Linux-${count.index + 1}"
  }
}

# Windows EC2 instances
resource "aws_instance" "windows" {
  count                  = var.windows_instance_count
  ami                    = data.aws_ami.windows.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.workload-sg.id]
  key_name               = aws_key_pair.wl_key_pair.key_name
  subnet_id              = aws_subnet.private.id

  tags = {
    Name = "${var.prefix}-WL-Windows-${count.index + 1}"
  }
}


#############################
# Outputs - Dokument everything
#############################

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = aws_subnet.private.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.main.id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

# Write outputs to a file
resource "local_file" "vpc-data" {
  content = <<-EOT
    VPC ID: ${aws_vpc.main.id}
    Public Subnet ID: ${aws_subnet.public.id}
    Private Subnet ID: ${aws_subnet.private.id}
    NAT Gateway ID: ${aws_nat_gateway.main.id}
    Internet Gateway ID: ${aws_internet_gateway.main.id}
  EOT
  filename = "${path.module}/vpc_data.txt"
}

# Output EC2 Instances
##############################

output "linux_jh_instance_ids" {
  description = "IDs of created Linux-JH EC2 instances"
  value       = aws_instance.jh-linux[*].id
}

output "linux_instance_ids" {
  description = "IDs of created Linux EC2 instances"
  value       = aws_instance.linux[*].id
}

output "linux-jh_public_ips" {
  description = "Public IPs of created Linux-JH EC2 instances"
  value       = aws_instance.jh-linux[*].public_ip
}

output "jumphost_public_dns" {
  description = "Public DNS hostname of the Jumphost instance"
  value       = aws_instance.jh-linux[0].public_dns
}

output "linux_private_ips" {
  description = "Private IPs of created Linux EC2 instances"
  value       = aws_instance.linux[*].private_ip
}

output "windows_instance_ids" {
  description = "IDs of created Windows EC2 instances"
  value       = aws_instance.windows[*].id
}

output "windows_private_ips" {
  description = "Private IPs of created Windows EC2 instances"
  value       = aws_instance.windows[*].private_ip
}

# Write outputs to a file
resource "local_file" "ec2-instance-data" {
  content = <<-EOT
    Linux-JH Instance ID: ${jsonencode(aws_instance.jh-linux[*].id)}
    Linux-WL Instance IDs: ${jsonencode(aws_instance.linux[*].id)}
    Windows Instance IDs: ${jsonencode(aws_instance.windows[*].id)}

    Jumphost Public DNS: ${aws_instance.jh-linux[0].public_dns}
    Jumphost Public IP: ${jsonencode(aws_instance.jh-linux[*].public_ip)}

    Linux-WL Private IPs: ${jsonencode(aws_instance.linux[*].private_ip)}
    Windows Public IPs: ${jsonencode(aws_instance.windows[*].public_ip)}
  EOT
  filename = "${path.module}/ec2-instance-data.txt"
}

# create Ansible Inventory file
#################################

resource "local_file" "ansible_inventory" {
  content = <<-EOT
[jumphost]
${aws_instance.jh-linux[0].public_dns} ansible_host=${aws_instance.jh-linux[0].public_ip} ansible_ssh_private_key_file="${path.module}/${var.prefix}-JH-private-key.pem"

[linux_workload]
%{ for index, instance in aws_instance.linux ~}
linux-wl-${index} ansible_host=${instance.private_ip} ansible_ssh_private_key_file="${path.module}/${var.prefix}-WL-private-key.pem"
%{ endfor ~}

[windows]
%{ for index, instance in aws_instance.windows ~}
windows-${index} ansible_host=${instance.public_ip}
%{ endfor ~}

[windows:vars]
ansible_connection=winrm
ansible_winrm_server_cert_validation=ignore
ansible_winrm_transport=basic

[linux_workload:vars]
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -q -i ${path.module}/${var.prefix}-JH-private-key.pem ubuntu@${aws_instance.jh-linux[0].public_dns}"'
ansible_host_key_checking=False

[all:vars]
ansible_user=ubuntu
  EOT
  filename = "${path.module}/inventory"

  # Make sure the inventory file is created after the key files
  depends_on = [
    local_file.jh_private_key,
    local_file.wl_private_key
  ]
}
