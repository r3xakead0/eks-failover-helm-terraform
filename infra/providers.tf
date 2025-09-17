# Dos providers de AWS con alias para cada región
provider "aws" {
  alias  = "primary"
  region = var.primary_region
}


provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}


# Identidad actual (se usará para Access Entries de EKS)
data "aws_caller_identity" "current" {}


# Providers de Kubernetes (uno por clúster) con auth por exec (aws eks get-token)
provider "kubernetes" {
  alias                  = "primary"
  host                   = module.eks_primary.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_primary.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", module.eks_primary.cluster_name,
      "--region", var.primary_region
    ]
  }
}


provider "kubernetes" {
  alias                  = "secondary"
  host                   = module.eks_secondary.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_secondary.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", module.eks_secondary.cluster_name,
      "--region", var.secondary_region
    ]
  }
}