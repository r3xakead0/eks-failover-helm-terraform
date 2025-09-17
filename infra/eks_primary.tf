module "eks_primary" {
  source    = "terraform-aws-modules/eks/aws"
  version   = "~> 20.8"
  providers = { aws = aws.primary }


  cluster_name    = var.cluster_name_primary
  cluster_version = "1.29"


  vpc_id     = module.vpc_primary.vpc_id
  subnet_ids = module.vpc_primary.private_subnets


  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = false


  enable_irsa = true


  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
  }


  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = 1
      desired_size   = var.desired_size
      max_size       = 5
    }
  }


  # Acceso admin a quien ejecuta Terraform
  access_entries = {
    admin = {
      principal_arn = data.aws_caller_identity.current.arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }


  tags = { Project = "eks-demo-mr" }
}