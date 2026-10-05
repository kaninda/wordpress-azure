variable "project" {
  description = "Nom du projet, utilisé dans les noms et les tags"
  type        = string
  default     = "wordpress-azure"
}

variable "location" {
  description = "Région Azure"
  type        = string
  default     = "switzerlandnorth"
}

variable "owner" {
  description = "Propriétaire des ressources"
  type        = string
  default     = "arnaud"
}

variable "etape" {
  description = "Étape courante du lab"
  type        = string
  default     = "02-vm"
}

variable "admin_ip" {
  description = "IP publique de mon poste, en CIDR /32"
  type        = string
}

variable "ssh_public_key_path" {
  description = "clé public SSH du lab"
  type        = string
  default     = "~/.ssh/az-wp-lab.pub"
}

