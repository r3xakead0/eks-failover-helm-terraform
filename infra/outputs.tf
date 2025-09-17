output "primary_cluster_name" { value = module.eks_primary.cluster_name }
output "primary_cluster_endpoint" { value = module.eks_primary.cluster_endpoint }
output "primary_web_lb_hostname" { value = kubernetes_service.web_primary.status[0].load_balancer[0].ingress[0].hostname }


output "secondary_cluster_name" { value = module.eks_secondary.cluster_name }
output "secondary_cluster_endpoint" { value = module.eks_secondary.cluster_endpoint }
output "secondary_web_lb_hostname" { value = kubernetes_service.web_secondary.status[0].load_balancer[0].ingress[0].hostname }


output "app_url" {
  value = "http://${var.app_subdomain}.${var.domain_name}"
}