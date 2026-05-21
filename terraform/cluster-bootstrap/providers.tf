terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.0"
}

provider "helm" {
  kubernetes = {
    config_path = "${path.module}/${var.kubeconfig_path}"
  }
}

provider "kubernetes" {
  config_path = "${path.module}/${var.kubeconfig_path}"
}
