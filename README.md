# Script to create a Lab environment in AWS automatically

## What is it?
This Terraform script will create a dedicated Lab environment in your AWS Account that consists of:
- a dedicated VPC with a public and a private subnet (IP-Ranges can be defined)
- Internet connectivity for all elements, for private subnet via NAT GW
- an internet facing (Linux) Jumphost
- a (defined by variables) Number of Linux (Ubuntu) and Windows Instances

## How does it work?

### Prerequisites:
- git needs to be installed
- aws cli needs to be installed and properly configured for your AWS environment
- Terraform needs to be installed and properly configured
- Optionally Ansible needs to be installed and properly configured

## What to do?

- pull the repo
```
  git clone https://github.com/VolkerMarschner/aws_lab_env.git
```
- cd into directory aws_lab_env
```
  cd aws_lab_env
```
- edit the file variables.tf and adjust values according to your needs. At minimum you should edit the variable "prefix", which controls the naming of newly created ressources.
 
- Let Terraform do its magic by issuing the following commands
```
 terraform init
 terraform plan
 terraform apply
```
- After a successful run, you will find information about IPs, DNS Names, private SSH keys etc. in the same directory
- Important: Before you use the ssh keys (.pem files) first do a
```
chmod 400 ./*.pem
```
-after all is setup in AWS, things need to be configured. First, do a
```
ansible -i ./inventory jumphost -m ping
```
If that works, continue with
```
ansible-playbook -i inventory jumphost-setup.yml
```
Once that is successfully finished, the Jumphost should reboot automatically -if not, do it manually (ssh into it or do it from the AWS Console).

Next Step is then
```
ansible -i ./inventory linux_workload -m ping
- it may be needed at first contact to go to each one individually, like
ansible -i ./inventory linux-wl-0 -m ping
ansible -i ./inventory linux-wl-1 -m ping
... and so on
```
Once that works, finish with
```
ansible-playbook -i inventory workload-setup.yml
```
and all should be set. Now you should have someting like this:

graph TB
    subgraph AWS_Cloud["AWS Cloud"]
        subgraph VPC["VPC (var.vpc_cidr)"]
            subgraph PublicSubnet["Public Subnet (Region a)"]
                JumpHost["Ubuntu Linux Jumphost"]
            end
            
            subgraph PrivateSubnet["Private Subnet (Region b)"]
                LinuxWL["Ubuntu Linux Workloads
                (var.linux_instance_count)"]
                WindowsWL["Windows Server 2022 Workloads
                (var.windows_instance_count)"]
            end
            
            IGW["Internet Gateway"]
            NGW["NAT Gateway"]
            EIP["Elastic IP"]
            
            JumpHostSG["Jumphost Security Group
            Port 22 from 0.0.0.0/0"]
            WorkloadSG["Workload Security Group
            All Traffic"]
        end
    end
    
    Internet((Internet))
    User((User))
    
    %% Connections
    Internet <--> IGW
    IGW <--> PublicSubnet
    PublicSubnet <--> NGW
    NGW <--> PrivateSubnet
    EIP --> NGW
    
    User -- "SSH" --> JumpHost
    JumpHost -- "SSH to Linux" --> LinuxWL
    JumpHost -- "WinRM to Windows" --> WindowsWL
    
    JumpHostSG --- JumpHost
    WorkloadSG --- LinuxWL
    WorkloadSG --- WindowsWL
    
    %% Styling
    classDef vpc fill:#ECF3FF,stroke:#3178C6,stroke-width:2px
    classDef subnet fill:#BBDEFB,stroke:#1976D2,stroke-width:2px
    classDef instance fill:#C8E6C9,stroke:#388E3C,stroke-width:2px
    classDef gateway fill:#FFECB3,stroke:#FFA000,stroke-width:2px
    classDef sg fill:#E1BEE7,stroke:#8E24AA,stroke-width:2px
    classDef external fill:#FAFAFA,stroke:#616161,stroke-width:2px,stroke-dasharray: 5 5
    
    class VPC vpc
    class PublicSubnet,PrivateSubnet subnet
    class JumpHost,LinuxWL,WindowsWL instance
    class IGW,NGW,EIP gateway
    class JumpHostSG,WorkloadSG sg
    class Internet,User external

    


## Once you do no longer need the environment, simply do a
```
  terraform destroy
```
