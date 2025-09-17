Pasos

Exporta tus credenciales/AWS_PROFILE (debe ser la misma identidad para ambos providers y para aws eks get-token).

Asegúrate de tener una zona en Route 53 y define route53_zone_id + domain_name.


2) Inicializa y aplica en dos fases (primera vez)

```bash
terraform init -upgrade


# 1) Crear VPCs y EKS (endpoints listos antes de K8s/DNS)
terraform apply \
  -target=module.vpc_primary \
  -target=module.vpc_secondary \
  -target=module.eks_primary \
  -target=module.eks_secondary \
  -auto-approve

# 2) App K8s + registros Route 53 (CNAME + health check)
terraform apply -auto-approve
```

3) Verifica outputs y acceso


```bash
terraform output
# app_url, primary_web_lb_hostname, secondary_web_lb_hostname, etc.

# prueba
open "$(terraform output -raw app_url)"    # o usa tu navegador
# o
curl -s "$(terraform output -raw app_url)"
```

aws route53 list-hosted-zones-by-name --dns-name mr-demo.aws.bo

aws route53 list-resource-record-sets \
  --hosted-zone-id Z05225422XUL2JX723S1J \
  --query "ResourceRecordSets[?Name=='app.mr-demo.aws.bo.']"

aws route53 get-hosted-zone --id Z073291649WP8KQS4LP

aws eks update-kubeconfig --name demo-eks-primary --region us-east-1

kubectl scale deploy web -n demo --replicas=0
kubectl scale deploy web -n demo --replicas=2

aws eks update-kubeconfig --name demo-eks-secundary --region us-east-2


# 1) Borra recursos K8s primero
terraform destroy -target=kubernetes_service.web \
                  -target=kubernetes_deployment.web \
                  -target=kubernetes_config_map.app_cfg \
                  -target=kubernetes_namespace.demo
# 2) Luego el resto (EKS, VPC, etc.)
terraform destroy -auto-approve


aws eks update-kubeconfig --name demo-eks-primary   --region us-east-1 --alias primary
aws eks update-kubeconfig --name demo-eks-secondary --region us-east-2 --alias secondary


3) Finaliza el namespace a mano (el truco de /finalize)

Con jq:

kubectl --context primary   get ns demo -o json | jq 'del(.spec.finalizers)' > /tmp/ns-primary.json
kubectl --context secondary get ns demo -o json | jq 'del(.spec.finalizers)' > /tmp/ns-secondary.json

kubectl --context primary   replace --raw /api/v1/namespaces/demo/finalize -f /tmp/ns-primary.json
kubectl --context secondary replace --raw /api/v1/namespaces/demo/finalize -f /tmp/ns-secondary.json