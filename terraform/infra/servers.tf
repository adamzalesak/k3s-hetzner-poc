resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

resource "hcloud_server" "control_plane" {
  count        = var.control_plane_count
  name         = "${var.cluster_name}-control-plane-${count.index + 1}"
  server_type  = "cx23"
  image        = "ubuntu-24.04"
  location     = "fsn1"
  ssh_keys     = [hcloud_ssh_key.admin.id]
  firewall_ids = [hcloud_firewall.firewall.id]
  user_data = templatefile("${path.module}/cloud-init/control-plane.yaml.tftpl", {
    k3s_token = random_password.k3s_token.result
  })
}

resource "hcloud_server_network" "control_plane_network" {
  count      = var.control_plane_count
  server_id  = hcloud_server.control_plane[count.index].id
  network_id = hcloud_network.private.id
  depends_on = [hcloud_network_subnet.private]
}


resource "hcloud_server" "agent" {
  count        = var.agent_count
  name         = "${var.cluster_name}-agent-${count.index + 1}"
  server_type  = "cx23"
  image        = "ubuntu-24.04"
  location     = "fsn1"
  ssh_keys     = [hcloud_ssh_key.admin.id]
  firewall_ids = [hcloud_firewall.firewall.id]
  user_data = templatefile("${path.module}/cloud-init/agent.yaml.tftpl", {
    k3s_token        = random_password.k3s_token.result,
    control_plane_ip = hcloud_server_network.control_plane_network[0].ip
  })
}

resource "hcloud_server_network" "agent_network" {
  count      = var.agent_count
  server_id  = hcloud_server.agent[count.index].id
  network_id = hcloud_network.private.id
  depends_on = [hcloud_network_subnet.private]
}

