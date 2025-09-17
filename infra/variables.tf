variable "primary_region" {
  description = "Región primaria"
  type        = string
  default     = "us-east-1"
}


variable "secondary_region" {
  description = "Región secundaria"
  type        = string
  default     = "us-east-2"
}


variable "cluster_name_primary" {
  type    = string
  default = "demo-eks-primary"
}


variable "cluster_name_secondary" {
  type    = string
  default = "demo-eks-secondary"
}


variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}


variable "desired_size" {
  type    = number
  default = 2
}


# Dominio y zona de Route 53 (subdominio recomendado para poder usar CNAME)
variable "route53_zone_id" {
  description = "Hosted Zone ID de Route 53 (p.ej., Z123EXAMPLE)"
  type        = string
  default     = "Z01773651YO1ZWU0YA561"
}


variable "app_subdomain" {
  description = "Subdominio para la app (p.ej., app). Se creará app.<tu-dominio>"
  type        = string
  default     = "app"
}


variable "domain_name" {
  description = "Dominio raíz de la zona (p.ej., ejemplo.com)"
  type        = string
  default     = "info.awscochabamba.org"
}