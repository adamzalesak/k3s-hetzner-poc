resource "hcloud_ssh_key" "admin" {
  name       = "${var.cluster_name}-admin"
  public_key = file("${path.module}/${var.ssh_public_key_path}")
}
