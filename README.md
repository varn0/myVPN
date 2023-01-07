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
