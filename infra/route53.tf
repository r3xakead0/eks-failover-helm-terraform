# Health check HTTP al Load Balancer de la región primaria
resource "aws_route53_health_check" "primary_web" {
  # Comprobamos el hostname del Service LB primario
  fqdn              = kubernetes_service.web_primary.status[0].load_balancer[0].ingress[0].hostname
  port              = 80
  type              = "TCP"
  # type              = "HTTP"
  # resource_path     = "/"
  failure_threshold = 1
  request_interval  = 15
}


# Registros de failover (usa un subdominio para poder CNAME al LB)
resource "aws_route53_record" "app_primary" {
  zone_id        = var.route53_zone_id
  name           = "${var.app_subdomain}.${var.domain_name}"
  type           = "CNAME"
  ttl            = 60
  set_identifier = "primary"
  failover_routing_policy { type = "PRIMARY" }
  health_check_id = aws_route53_health_check.primary_web.id
  records         = [kubernetes_service.web_primary.status[0].load_balancer[0].ingress[0].hostname]
}


resource "aws_route53_record" "app_secondary" {
  zone_id        = var.route53_zone_id
  name           = "${var.app_subdomain}.${var.domain_name}"
  type           = "CNAME"
  ttl            = 60
  set_identifier = "secondary"
  failover_routing_policy { type = "SECONDARY" }
  records = [kubernetes_service.web_secondary.status[0].load_balancer[0].ingress[0].hostname]
}