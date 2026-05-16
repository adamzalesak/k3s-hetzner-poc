output "control_plane_public_ip" {
  description = "Public IPv4 of the control-plane node"
  value       = hcloud_server.control_plane[0].ipv4_address
}

output "agent_public_ips" {
  description = "Public IPv4 addresses of the agent nodes"
  value       = hcloud_server.agent[*].ipv4_address # equal to [for agent in hcloud_server.agent : agent.ipv4_address]
}