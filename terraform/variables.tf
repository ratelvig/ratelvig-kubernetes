variable "pm_api_url" {
  type        = string
  description = "Proxmox API endpoint URL (e.g. https://proxmox.local:8006/api2/json)"
}

variable "pm_api_token_id" {
  type        = string
  description = "Proxmox API Token ID (e.g. terraform@pve!terraform-token)"
}

variable "pm_api_token_secret" {
  type        = string
  description = "Proxmox API Token Secret UUID"
  sensitive   = true
}

variable "pm_tls_insecure" {
  type        = bool
  description = "Disable TLS verification for self-signed certificates"
  default     = true
}

variable "proxmox_target_node" {
  type        = string
  description = "Target Proxmox node name"
  default     = "pve"
}

variable "vm_template" {
  type        = string
  description = "Name of the Proxmox Cloud-Init VM template to clone"
  default     = "cloud-initv2"
}

variable "vm_template_id" {
  type        = number
  description = "VMID of the Proxmox Cloud-Init VM template"
  default     = 901
}

variable "ci_user" {
  type        = string
  description = "Default cloud-init user provisioned on VMs"
  default     = "root"
}

variable "storage_pool" {
  type        = string
  description = "Target storage pool for container rootfs"
  default     = "local-lvm"
}

variable "network_bridge" {
  type        = string
  description = "Bridge interface on Proxmox node"
  default     = "vmbr0"
}

variable "network_cidr" {
  type        = string
  description = "Base subnet CIDR for nodes"
  default     = "192.168.2.0/24"
}

variable "network_prefix" {
  type        = number
  description = "Subnet mask prefix"
  default     = 24
}

variable "network_gateway" {
  type        = string
  description = "Default gateway for node network"
  default     = "192.168.2.1"
}

variable "searchdomain" {
  type        = string
  description = "Default DNS search domain"
  default     = "ratelvig.local"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key injected into nodes for Ansible administration"
}

# Master (Server) Node Variables
variable "server_count" {
  type        = number
  description = "Number of K3s server (control plane) nodes"
  default     = 1
}

variable "server_vmid_start" {
  type        = number
  description = "Starting VMID for K3s servers"
  default     = 200
}

variable "server_ip_start" {
  type        = number
  description = "Last octet / host offset in CIDR for first server node (10 = 192.168.2.10)"
  default     = 10
}

variable "server_cores" {
  type        = number
  description = "CPU cores allocated per server node"
  default     = 2
}

variable "server_memory" {
  type        = number
  description = "RAM allocated per server node in MB"
  default     = 3072
}

variable "server_swap" {
  type        = number
  description = "Swap memory per server node in MB"
  default     = 512
}

variable "server_disk_size" {
  type        = string
  description = "Disk size for server node rootfs"
  default     = "20G"
}

# Worker (Agent) Node Variables
variable "agent_count" {
  type        = number
  description = "Number of K3s agent (worker) nodes"
  default     = 1
}

variable "agent_vmid_start" {
  type        = number
  description = "Starting VMID for K3s agents"
  default     = 210
}

variable "agent_ip_start" {
  type        = number
  description = "Last octet / host offset in CIDR for first agent node (11 = 192.168.2.11)"
  default     = 11
}

variable "agent_cores" {
  type        = number
  description = "CPU cores allocated per agent node"
  default     = 2
}

variable "agent_memory" {
  type        = number
  description = "RAM allocated per agent node in MB"
  default     = 4096
}

variable "agent_swap" {
  type        = number
  description = "Swap memory per agent node in MB"
  default     = 512
}

variable "agent_disk_size" {
  type        = string
  description = "Disk size for agent node rootfs"
  default     = "40G"
}
