
cd infra/bootstrap

terraform init
terraform init -upgrade

terraform fmt -recursive
terraform validate

terraform apply -var-file=envs/dev.tfvars

terraform destroy -var-file=envs/dev.tfvars