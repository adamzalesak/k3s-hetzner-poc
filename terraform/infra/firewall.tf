resource "hcloud_firewall" "firewall" {
  name = "${var.cluster_name}-firewall"
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      var.admin_cidr
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "6443"
    source_ips = [
      var.admin_cidr
    ]
  }

  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = [
      var.admin_cidr
    ]
  }
}
