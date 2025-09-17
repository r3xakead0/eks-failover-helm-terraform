resource "kubernetes_namespace" "demo_secondary" {
  provider   = kubernetes.secondary
  depends_on = [module.eks_secondary]
  metadata { name = "demo" }
}


resource "kubernetes_config_map" "app_cfg_secondary" {
  provider   = kubernetes.secondary
  depends_on = [module.eks_secondary]
  metadata {
    name      = "web-config"
    namespace = kubernetes_namespace.demo_secondary.metadata[0].name
  }
  data = {
    CLUSTER_NAME = var.cluster_name_secondary
    "index.html" = kubernetes_config_map.app_cfg_primary.data["index.html"]
  }
}


resource "kubernetes_deployment" "web_secondary" {
  provider   = kubernetes.secondary
  depends_on = [module.eks_secondary]
  metadata {
    name      = "web"
    namespace = kubernetes_namespace.demo_secondary.metadata[0].name
    labels    = { app = "web" }
  }
  spec {
    replicas = 2
    selector { match_labels = { app = "web" } }
    template {
      metadata {
        labels = { app = "web" }
        annotations = {
          "checksum/config" = sha1(join("", [
            kubernetes_config_map.app_cfg_secondary.data["index.html"],
            kubernetes_config_map.app_cfg_secondary.data.CLUSTER_NAME
          ]))
        }
      }
      spec {
        volume {
          name = "webroot"
          empty_dir {}
        }
        volume {
          name = "template"
          config_map { name = kubernetes_config_map.app_cfg_secondary.metadata[0].name }
        }


        init_container {
          name    = "render-template"
          image   = "alpine:3.20"
          command = ["sh", "-c"]
          args = [
            "apk add --no-cache gettext >/dev/null 2>&1 && envsubst '$CLUSTER_NAME $POD_NAME' < /template/index.html > /usr/share/nginx/html/index.html"
          ]
          env {
            name  = "CLUSTER_NAME"
            value = kubernetes_config_map.app_cfg_secondary.data.CLUSTER_NAME
          }
          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }
          volume_mount {
            name       = "webroot"
            mount_path = "/usr/share/nginx/html"
          }
          volume_mount {
            name       = "template"
            mount_path = "/template"
            read_only  = true
          }
        }


        container {
          name  = "nginx"
          image = "nginx:1.27-alpine"
          port { container_port = 80 }
          volume_mount {
            name       = "webroot"
            mount_path = "/usr/share/nginx/html"
          }
          resources {
            requests = {
              cpu    = "50m",
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m",
              memory = "128Mi"
            }
          }
          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
          }
          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 2
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "web_secondary" {
  provider   = kubernetes.secondary
  depends_on = [module.eks_secondary]
  metadata {
    name      = "web"
    namespace = kubernetes_namespace.demo_secondary.metadata[0].name
  }
  spec {
    selector = { app = kubernetes_deployment.web_secondary.metadata[0].labels.app }
    port {
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }
}