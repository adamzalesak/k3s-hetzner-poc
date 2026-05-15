resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

resource "hcloud_server" "control_plane" {
  count        = var.control_plane_count
  name         = "${var.cluster_name}-control-plane-${count.index + 1}"
  server_type  = "cx22"
  image        = "ubuntu-24.04"
  location     = "fsn1"
  ssh_keys     = [hcloud_ssh_key.admin.id]
  firewall_ids = [hcloud_firewall.firewall.id]
}

resource "hcloud_server_network" "control_plane_network" {
  count      = var.control_plane_count
  server_id  = hcloud_server.control_plane[count.index].id
  network_id = hcloud_network.private.id
  depends_on = [hcloud_network_subnet.private]
}