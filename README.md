# Setup

Export your public key to tf variable

```bash
export TF_VAR_public_key=$(cat ~/.ssh/id_rsa.pub)
```

Initialize terraform

```bash
terraform init
```

Create a plan

```bash
terraform plan -out=planfile
```

Import default security group

```bash
terraform import aws_security_group.default $(aws ec2 describe-security-groups --filters Name=group-name,Values=default | jq -r '.SecurityGroups[0].GroupId')
```

Apply the plan

```bash
terraform apply planfile
```

# Destroy

Destroy the infrastructure

```bash
terraform plan -destroy -out=destroyplan
terraform apply destroyplan
```


# Create a new user

```bash
public_name=$(terraform output -json | jq -r '.public_dns.value')
public_ip=$(terraform output -json | jq -r '.public_ip.value')


```