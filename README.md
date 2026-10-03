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
