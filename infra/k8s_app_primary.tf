resource "kubernetes_namespace" "demo_primary" {
  provider   = kubernetes.primary
  depends_on = [module.eks_primary]
  metadata { name = "demo" }
}


resource "kubernetes_config_map" "app_cfg_primary" {
  provider   = kubernetes.primary
  depends_on = [module.eks_primary]
  metadata {
    name      = "web-config"
    namespace = kubernetes_namespace.demo_primary.metadata[0].name
  }
  data = {
    CLUSTER_NAME = var.cluster_name_primary
    "index.html" = <<-EOT
<html>
<head>
<meta charset="utf-8" />
<title>EKS Demo</title>
<style>
body { font-family: system-ui, sans-serif; padding: 2rem; }
.card { max-width: 640px; margin: auto; padding: 2rem; border-radius: 16px; box-shadow: 0 2px 20px rgba(0,0,0,0.08);}
h1 { margin: 0 0 1rem; }
code { background: #f5f5f5; padding: 0.2rem 0.4rem; border-radius: 6px; }
</style>
</head>
<body>
<div class="card">
<h1>🚀 EKS Demo</h1>
<p>Cluster: <code>$CLUSTER_NAME</code></p>
<p>Pod: <code>$POD_NAME</code></p>
</div>
</body>
</html>
EOT
  }
}


resource "kubernetes_deployment" "web_primary" {
  provider   = kubernetes.primary
  depends_on = [module.eks_primary]
  metadata {
    name      = "web"
    namespace = kubernetes_namespace.demo_primary.metadata[0].name
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
            kubernetes_config_map.app_cfg_primary.data["index.html"],
            kubernetes_config_map.app_cfg_primary.data.CLUSTER_NAME
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
          config_map { name = kubernetes_config_map.app_cfg_primary.metadata[0].name }
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
            value = kubernetes_config_map.app_cfg_primary.data.CLUSTER_NAME
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

resource "kubernetes_service" "web_primary" {
  provider   = kubernetes.primary
  depends_on = [module.eks_primary]
  metadata {
    name      = "web"
    namespace = kubernetes_namespace.demo_primary.metadata[0].name
  }
  spec {
    selector = { app = kubernetes_deployment.web_primary.metadata[0].labels.app }
    port {
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }
}