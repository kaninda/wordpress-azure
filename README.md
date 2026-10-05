# WordPress sur Azure — Terraform + Ansible

Lab de préparation à l'**AZ-104** : reconstruction sur Azure d'une architecture WordPress
déjà réalisée sur AWS, en Infrastructure as Code.

- **Terraform** : infrastructure (provider `azurerm`)
- **Ansible** : configuration des VM (à partir de l'étape 03)
- **Région** : Switzerland North
- Une étape = un tag git annoté

## Architecture cible

<img src="docs/architecture.png" alt="Architecture WordPress sur Azure" width="700">

## Roadmap

| Étape | Contenu | Ressources payantes | Coût estimé | Statut |
|---|---|---|---|---|
| 00 | Socle : repo, provider, RG, budget | aucune (RG gratuit) | 0 | ✅ |
| 01 | Réseau : VNet, subnets, NSG, NAT Gateway | NAT Gateway | à estimer | ⏳ |
| 02 | VM WordPress + jumpbox | VM, disques, IP publique | à estimer | ⏳ |
| 03 | Load Balancer + Ansible | LB Standard, IP publique | à estimer | ⏳ |
| 04 | MySQL Flexible + WordPress | MySQL Flexible | à estimer | ⏳ |
| 05 | Azure Bastion | Bastion | à estimer | ⏳ |
| 06 | Stockage | Storage account | à estimer | ⏳ |
| 07 | Identité | — | à estimer | ⏳ |
| 08 | Monitoring / backup | Log Analytics, Backup | à estimer | ⏳ |

Coûts à estimer avec la [calculatrice Azure](https://azure.microsoft.com/pricing/calculator/).
Règle : `terraform destroy` en fin de chaque session.

## Étape 00 — Socle

**Objectif** : poser les fondations, sans aucune ressource payante.

**Réalisé**
- Structure du repo (`terraform/`, `ansible/`)
- Terraform `~> 1.16`, provider `azurerm ~> 5.8`, lockfile versionné
- Resource group `rg-wordpress-azure` avec tags communs (`projet`, `etape`, `owner`)
- Budget mensuel sur la subscription, avec alertes à 50 / 80 / 100 % du réel et 100 % du prévisionnel (portail)

**Prérequis**
```bash
az login
export ARM_SUBSCRIPTION_ID="<subscription-id>"
```

**Utilisation**
```bash
cd terraform
terraform init
terraform plan
terraform apply
terraform destroy   # en fin de session
```

## Étape 01 — Réseau

### Plan d'adressage
| Subnet | CIDR | IP utilisables | Rôle |
|---|---|---|---|
| snet-app | 10.0.1.0/24 | 251 | VM WordPress, sortie via NAT Gateway |
| snet-data | 10.0.2.0/24 | 251 | MySQL Flexible (étape 04) |
| snet-jumpbox | 10.0.3.0/27 | 27 | Jumpbox, SSH depuis le poste admin |
| AzureBastionSubnet | 10.0.4.0/26 | — | Réservé, étape 05 (non créé) |

VNet : `10.0.0.0/16`, région Switzerland North.

### Choix
- Un NSG par subnet, associé au subnet. SSH : poste admin → jumpbox → app.
- NAT Gateway Standard sur snet-app uniquement.
- `default_outbound_access_enabled = false` sur tous les subnets : aucune sortie implicite.
- Délégation MySQL de snet-data reportée à l'étape 04.

### Prérequis
Créer `terraform/terraform.tfvars` (non commité) :
admin_ip = "x.x.x.x/32"

## Roadmap
- [x] 00 socle
- [x] 01 réseau
- [x] 02 VM + jumpbox
- [ ] 03 LB + Ansible
- [ ] 04 MySQL + WordPress
- [ ] 05 Bastion
- [ ] 06 stockage
- [ ] 07 identité
- [ ] 08 monitoring/backup

## Étape 02 — VM WordPress + jumpbox

**Ajouté**
- Jumpbox `vm-jumpbox` dans snet-jumpbox, IP publique Standard statique
- VM `vm-app` dans snet-app, sans IP publique (sortie via NAT Gateway)
- Ubuntu 24.04 LTS Gen2, `Standard_D2als_v6`, disque StandardSSD (NVMe), Trusted launch
- Accès SSH par clé ed25519 uniquement (mot de passe désactivé)
- nsg-jumpbox : règle `Deny-VNet-Inbound` (priorité 4000)

**Accès**
​```
Mac ──22──► jumpbox (IP publique) ──22──► vm-app (10.0.1.4)
​```
`~/.ssh/config` avec `ProxyJump az-jumpbox`.

**Tests validés**
- `ssh az-jumpbox` / `ssh az-app`
- Sortie de vm-app = IP de la NAT Gateway ; sortie de la jumpbox = sa propre IP
- vm-app → jumpbox:22 bloqué

**Choix**
- Série D au lieu de B : Bs v1 fermée pour la souscription, Bsv2 avec quota à 0
