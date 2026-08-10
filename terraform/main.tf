terraform {
  required_version = ">= 1.15.0"
  required_providers {
    helm = {
      source = "hashicorp/helm"
      version = "~> 3.2"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 3.2"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

variable "keycloak_fqdn" {
  type = string
}

variable "wildcard_fqdn" {
  type = string
}

variable "keycloak_password" {
  type = string
  sensitive = true
}

variable "postgres_password" {
  type = string
  sensitive = true
}

resource "kubernetes_namespace_v1" "keycloak" {
  metadata {
    name = "keycloak"
  }
}

resource "kubernetes_secret_v1" "keycloak_password" {
  metadata {
    name = "keycloak-password"
    namespace = "keycloak"
  }

  data = {
    KEYCLOAK_PASSWORD = trimspace(var.keycloak_password)
  }

  type = "Opaque"
}

resource "kubernetes_secret_v1" "postgres_password" {
  metadata {
    name = "postgres-password"
    namespace = "keycloak"
  }

  data = {
    POSTGRES_PASSWORD = trimspace(var.postgres_password)
  }

  type = "Opaque"
}

resource "helm_release" "keycloak_db" {
  name = "postgres"
  repository = "oci://ghcr.io/11notes/charts"
  chart = "postgres"
  namespace = "keycloak"
  version = "1.0.0"

  wait = true
  wait_for_jobs = true
  timeout = 300

  values = [
    yamlencode({
      image = {
        tag = "18"
      }
      postgres = {
        existingSecret = "postgres-password"
        existingSecretKey = "POSTGRES_PASSWORD"
      }
      persistence = {
        etc = {
          size = "16Mi"
        }
        var = {
          size = "32Gi"
        }
      }
    })
  ]
}

resource "helm_release" "keycloak" {
  name = "keycloak"
  repository = "oci://ghcr.io/11notes/charts"
  chart = "keycloak"
  namespace = "keycloak"
  version = "0.0.1"

  values = [
    yamlencode({
      image = {
        tag = "26.7.1"
      }
      keycloak = {
        fqdn = trimspace(var.keycloak_fqdn)
        existingSecret = "keycloak-password"
        existingSecretKey = "KEYCLOAK_PASSWORD"
      }
      postgres = {
        existingSecret = "postgres-password"
        existingSecretKey = "POSTGRES_PASSWORD"
        serviceName = "postgres"
      }
    })
  ]

  depends_on = [helm_release.keycloak_db]
}

resource "kubernetes_ingress_v1" "keycloak_ingress" {
  metadata {
    name = "keycloak-ingress"
    namespace = "keycloak"
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    }
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts = [trimspace(var.keycloak_fqdn)]
      secret_name = "wildcard-${replace(trimspace(var.wildcard_fqdn), ".", "-")}-tls"
    }

    rule {
      host = trimspace(var.keycloak_fqdn)
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "keycloak"
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }
}