variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "admin_cidr" {
  description = "CIDR block for admin access (e.g., admin's home IP address)"
  type        = string
  validation {
    condition     = can(cidrnetmask(var.admin_cidr))
    error_message = "The admin_cidr variable must be a valid CIDR block (e.g., 192.168.1.0/24)"
  }
}
