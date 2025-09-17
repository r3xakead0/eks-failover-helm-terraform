module "vpc_secondary" {
  source    = "terraform-aws-modules/vpc/aws"
  version   = "~> 5.0"
  providers = { aws = aws.secondary }


  name = "eks-demo-vpc-secondary"
  cidr = "10.20.0.0/16"


  azs             = ["${var.secondary_region}a", "${var.secondary_region}b", "${var.secondary_region}c"]
  public_subnets  = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
  private_subnets = ["10.20.101.0/24", "10.20.102.0/24", "10.20.103.0/24"]


  enable_nat_gateway = true
  single_nat_gateway = true


  tags = {
    "kubernetes.io/cluster/${var.cluster_name_secondary}" = "shared"
  }
  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}