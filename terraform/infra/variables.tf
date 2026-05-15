variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "admin_cidr" {
  description = "CIDR block for admin access (e.g., admin's home IP address)"
  type        = string
  validation {
    condition     = can(cidrnetmask(var.admin_cidr)) && var.admin_cidr != "0.0.0.0/0" && var.admin_cidr != "::/0"
    error_message = "The admin_cidr variable must be a valid CIDR block (e.g., 192.168.1.0/24)"
  }
}

variable "cluster_name" {
  description = "Name prefix for all Hetzner resources in this cluster"
  type        = string
  default     = "k8s-poc"
}

variable "ssh_public_key_path" {
  description = "Path to the committed SSH public key, relative to the infra module"
  type        = string
  default     = "keys/admin.pub"
}

variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 1
}