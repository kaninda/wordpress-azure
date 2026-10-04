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
  default     = "01-reseau"
}

variable "admin_ip" {
  description = "IP publique de mon poste, en CIDR /32"
  type        = string
}

