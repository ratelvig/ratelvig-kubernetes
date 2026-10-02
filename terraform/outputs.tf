output "k3s_servers" {
  description = "List of provisioned K3s control-plane server nodes"
  value = [
    for idx, s in proxmox_vm_qemu.k3s_servers : {
      hostname = s.name
      vmid     = s.vmid
      ip       = cidrhost(var.network_cidr, var.server_ip_start + idx)
    }
  ]
}

output "k3s_agents" {
  description = "List of provisioned K3s worker agent nodes"
  value = [
    for idx, a in proxmox_vm_qemu.k3s_agents : {
      hostname = a.name
      vmid     = a.vmid
      ip       = cidrhost(var.network_cidr, var.agent_ip_start + idx)
    }
  ]
}

output "ansible_inventory_content" {
  description = "Generated inventory template format ready for hosts.ini"
  value = join("\n", concat(
    ["[k3s_servers]"],
    [for idx, s in proxmox_vm_qemu.k3s_servers : "${s.name} ansible_host=${cidrhost(var.network_cidr, var.server_ip_start + idx)}"],
    ["", "[k3s_agents]"],
    [for idx, a in proxmox_vm_qemu.k3s_agents : "${a.name} ansible_host=${cidrhost(var.network_cidr, var.agent_ip_start + idx)}"],
    ["", "[k3s_cluster:children]", "k3s_servers", "k3s_agents"]
  ))
}
