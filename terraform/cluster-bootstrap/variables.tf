variable "kubeconfig_path" {
  description = "Path to the kubeconfig file consumed by this module, relative to the cluster-bootstrap module"
  default     = "../../kubeconfig"
}