module "vpc_primary" {
  source    = "terraform-aws-modules/vpc/aws"
  version   = "~> 5.0"
  providers = { aws = aws.primary }


  name = "eks-demo-vpc-primary"
  cidr = "10.10.0.0/16"


  azs             = ["${var.primary_region}a", "${var.primary_region}b", "${var.primary_region}c"]
  public_subnets  = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
  private_subnets = ["10.10.101.0/24", "10.10.102.0/24", "10.10.103.0/24"]


  enable_nat_gateway = true
  single_nat_gateway = true


  tags = {
    "kubernetes.io/cluster/${var.cluster_name_primary}" = "shared"
  }
  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}