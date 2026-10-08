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
  default     = "05-stockage"
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

variable "vm_size" {
  description = "Taille des VMs (série B indisponible : quota)"
  type        = string
  default     = "Standard_D2als_v6"
}

variable "mysql_admin_password" {
  description = "Mot de passe admin MySQL (dans terraform.tfvars, ignoré par git)"
  type        = string
  sensitive   = true
}

