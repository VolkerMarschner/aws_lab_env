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
Once that is successfully finished, reboot the Jumphost (ssh into it or do it from the AWS Console).

Next Step is then
```
ansible -i ./inventory linux_workload -m ping
- it may be needed at first contact to go to each one individually, like
ansible -i ./inventory linux-wl-0 -m ping
ansible -i ./inventory linux-wl-1 -m ping
... and so on
``
Once that works, finish with
```
ansible-playbook -i inventory workload-setup.yml
```
and all should be set.


## Once you do no longer need the environment, simply do a
```
  terraform destroy
```
