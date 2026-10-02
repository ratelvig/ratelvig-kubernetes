terraform {
  required_version = ">= 1.5.0"
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc10"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = var.pm_tls_insecure
  pm_timeout          = 600
}

resource "proxmox_vm_qemu" "k3s_servers" {
  count       = var.server_count
  target_node = var.proxmox_target_node
  vmid        = var.server_vmid_start + count.index
  name        = "k3s-master-${format("%02d", count.index + 1)}"
  clone       = var.vm_template
  full_clone  = true
  agent       = 1
  os_type     = "cloud-init"

  cpu {
    cores   = var.server_cores
    sockets = 1
    type    = "host"
  }
  memory = var.server_memory
  scsihw = "virtio-scsi-pci"
  boot   = "order=scsi0"

  disks {
    scsi {
      scsi0 {
        disk {
          storage = var.storage_pool
          size    = var.server_disk_size
        }
      }
    }
    ide {
      ide2 {
        cloudinit {
          storage = var.storage_pool
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = var.network_bridge
  }

  ipconfig0    = "ip=${cidrhost(var.network_cidr, var.server_ip_start + count.index)}/${var.network_prefix},gw=${var.network_gateway}"
  nameserver   = var.network_gateway
  searchdomain = var.searchdomain
  ciuser       = var.ci_user
  sshkeys      = var.ssh_public_key
}

resource "proxmox_vm_qemu" "k3s_agents" {
  count       = var.agent_count
  target_node = var.proxmox_target_node
  vmid        = var.agent_vmid_start + count.index
  name        = "k3s-worker-${format("%02d", count.index + 1)}"
  clone       = var.vm_template
  full_clone  = true
  agent       = 1
  os_type     = "cloud-init"

  cpu {
    cores   = var.agent_cores
    sockets = 1
    type    = "host"
  }
  memory = var.agent_memory
  scsihw = "virtio-scsi-pci"
  boot   = "order=scsi0"

  disks {
    scsi {
      scsi0 {
        disk {
          storage = var.storage_pool
          size    = var.agent_disk_size
        }
      }
    }
    ide {
      ide2 {
        cloudinit {
          storage = var.storage_pool
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = var.network_bridge
  }

  ipconfig0    = "ip=${cidrhost(var.network_cidr, var.agent_ip_start + count.index)}/${var.network_prefix},gw=${var.network_gateway}"
  nameserver   = var.network_gateway
  searchdomain = var.searchdomain
  ciuser       = var.ci_user
  sshkeys      = var.ssh_public_key
}
