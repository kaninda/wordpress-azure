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

| Étape | Contenu | Ressources payantes | Coût constaté / session | Statut |
|---|---|---|---|---|
| 00 | Socle : repo, provider, RG, budget | aucune (RG gratuit) | 0.00 CHF | ✅ |
| 01 | Réseau : VNet, subnets, NSG, NAT Gateway | NAT Gateway | ~0.05 CHF | ✅ |
| 02 | VM WordPress + jumpbox | VM, disques, IP publique | ~0.07 CHF | ✅ |
| 03 | Load Balancer + Ansible | LB Standard, IP publique | ~0.14 CHF | ✅ |
| 04 | MySQL Flexible + WordPress | MySQL Flexible | ~0.23 CHF | ✅ |
| 05 | Stockage (Azure Files) | Storage account, private endpoint | ~0.51 CHF | ✅ |
| 06 | Identité / secrets | Key Vault, private endpoint | à compléter (J+1) | ✅ |
| 07 | Monitoring / backup | Log Analytics, Backup | — | ⏳ |
| 08 | Azure Bastion | Bastion | — | ⏳ |

Coût constaté : Cost Management → Cost analysis, granularité *Daily*, groupé par tag `etape`
(coûts cumulés du lab sur une session, `destroy` inclus ; remontée avec 8 à 24 h de retard).
Règle : `terraform destroy` en fin de chaque session.

## Démarrage rapide

```
az account show → terraform apply → ~/.ssh/config → ansible-playbook → tests → terraform destroy
```

**Prérequis** : Terraform ~> 1.16, Azure CLI, Ansible (`brew install ansible`),
clé SSH `~/.ssh/az-wp-lab`, hôtes `az-jumpbox` et `az-app` dans `~/.ssh/config`.
Aucun mot de passe à fournir : Terraform les génère et les dépose dans Key Vault (étape 06).

```bash
# 1. Authentification (az login seulement si la session a expiré)
az account show

# 2. Infrastructure  ⚠️ facturé à l'heure dès l'apply
cd terraform
terraform init
terraform apply             # 403 sur un secret au 1er apply → attendre 1-2 min, relancer
terraform output            # jumpbox_public_ip, lb_public_ip, key_vault_name…

# 3. SSH : l'IP de la jumpbox change à chaque apply
#    → reporter jumpbox_public_ip dans HostName de az-jumpbox (~/.ssh/config)
ssh-keygen -R 10.0.1.4
ssh az-jumpbox exit && ssh az-app exit

# 4. Configuration de la VM (vm-app lit ses secrets dans Key Vault)
cd ../ansible
ansible-playbook wordpress.yml      # 2e passage : changed=0

# 5. Vérification
curl http://$(terraform -chdir=../terraform output -raw lb_public_ip)/healthz   # → ok

# 6. Fin de session : obligatoire
cd ../terraform && terraform destroy
```

> `admin_ip` (terraform.tfvars) doit correspondre à ton IP publique (`curl ifconfig.me`),
> sinon le SSH vers la jumpbox **et** l'écriture des secrets dans Key Vault sont bloqués.


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
| AzureBastionSubnet | 10.0.4.0/26 | — | Réservé, étape 08 (non créé) |
| snet-pe | 10.0.5.0/27 | 27 | Private endpoints (storage, puis Key Vault) — étape 05 |

VNet : `10.0.0.0/16`, région Switzerland North.

### Choix
- Un NSG par subnet, associé au subnet. SSH : poste admin → jumpbox → app.
- NAT Gateway Standard sur snet-app uniquement.
- `default_outbound_access_enabled = false` sur tous les subnets : aucune sortie implicite.
- Délégation MySQL de snet-data reportée à l'étape 04.

### Prérequis
Créer `terraform/terraform.tfvars` (non commité) :
admin_ip = "x.x.x.x/32"

## Étape 02 — VM WordPress + jumpbox

**Ajouté**
- Jumpbox `vm-jumpbox` dans snet-jumpbox, IP publique Standard statique
- VM `vm-app` dans snet-app, sans IP publique (sortie via NAT Gateway)
- Ubuntu 24.04 LTS Gen2, `Standard_D2als_v6`, disque StandardSSD (NVMe), Trusted launch
- Accès SSH par clé ed25519 uniquement (mot de passe désactivé)
- nsg-jumpbox : règle `Deny-VNet-Inbound` (priorité 4000)

**Accès**
```
Mac ──22──► jumpbox (IP publique) ──22──► vm-app (10.0.1.4)
```
`~/.ssh/config` avec `ProxyJump az-jumpbox`.

**Tests validés**
- `ssh az-jumpbox` / `ssh az-app`
- Sortie de vm-app = IP de la NAT Gateway ; sortie de la jumpbox = sa propre IP
- vm-app → jumpbox:22 bloqué

**Choix**
- Série D au lieu de B : Bs v1 fermée pour la souscription, Bsv2 avec quota à 0

## Étape 03 — Load Balancer + Ansible (Nginx)

### Ce qui est ajouté
- **Load Balancer Standard public** (`lb.tf`) : IP publique Standard statique, frontend `fe-public`,
  backend pool `bep-app` (NIC de vm-app), probe HTTP:80 sur `/`, règle 80 → 80.
- **`disable_outbound_snat = true`** : le sortant passe uniquement par la NAT Gateway.
- **Cloisonnement `nsg-app`** : 100 SSH depuis snet-jumpbox · 110 HTTP depuis Internet · 4000 Deny VNet.
  Les probes (tag `AzureLoadBalancer`, règle par défaut 65001) restent autorisées.
- **Ansible** (`ansible/`) : playbook `nginx.yml` qui installe Nginx et déploie une page affichant le hostname.
- Variables : `etape = "03-lb"`, taille des VMs dans `vm_size`.

```
Internet ──80──► LB (IP publique) ──► probe HTTP:80 ──► vm-app (Nginx)
vm-app ──sortant──► NAT Gateway
Poste ──SSH──► jumpbox ──ProxyJump──► vm-app   (Ansible passe par là)
```

### Lancer Ansible
Prérequis : `brew install ansible`, hôtes `az-jumpbox` et `az-app` dans `~/.ssh/config`.

```bash
# Après chaque apply : l'IP publique de la jumpbox change
terraform -chdir=terraform output jumpbox_public_ip   # → HostName de az-jumpbox dans ~/.ssh/config
ssh-keygen -R 10.0.1.4 && ssh az-jumpbox exit && ssh az-app exit

cd ansible                     # ansible.cfg n'est lu que depuis ce dossier
ansible app -m ping
ansible-playbook nginx.yml     # 2e passage : changed=0 (idempotence)
```

### Tests réalisés
| Test | Résultat |
|---|---|
| `curl` LB avant Nginx | timeout (aucun backend sain) |
| `curl http://<lb_public_ip>` après playbook | page `vm-app-wordpress-azure` |
| 2e passage du playbook | `changed=0` |
| Arrêt de Nginx | probe KO, Health Probe Status → 0 %, `curl` en timeout |
| Relance via le playbook | `changed=1`, site de nouveau OK |

<img src="docs/test_nginx_off.webp" alt="Health Probe Status : 0 % → 100 % → chute à l'arrêt de Nginx" width="700">

> `nginx.yml` a été remplacé par `wordpress.yml` à l'étape 04 (consultable via le tag `etape-03`).

## Étape 04 — MySQL Flexible + WordPress

### Ce qui est ajouté
- **Délégation** de snet-data à `Microsoft.DBforMySQL/flexibleServers`.
- **Zone DNS privée** `wp-lab.private.mysql.database.azure.com` + lien VNet (sans auto-registration).
- **MySQL Flexible Server** en accès privé : MySQL 8.4, Burstable `B_Standard_B1ms`, 20 Go,
  sans autogrow ni IOPS auto, sans HA, backup 1 jour. Nom unique via `random_string`.
- **Base `wordpress`** (utf8mb4) et output `mysql_fqdn`.
- **Cloisonnement `nsg-data`** : 100 Allow 3306 depuis snet-app · 4000 Deny VNet.
- **Probe du LB sur `/healthz`** (WordPress répond 302 sur `/` avant installation).
- **Ansible** : `wordpress.yml` (remplace `nginx.yml`) — Nginx, PHP-FPM, WordPress,
  templates `wp-config.php.j2` et `wordpress.conf.j2`, handler de reload.

```
Internet ──80──► LB (probe /healthz) ──► vm-app : Nginx ──► PHP-FPM
                                                              │ 3306 / TLS
vm-app ──DNS──► zone privée (CNAME) ──► 10.0.2.4 ◄────────────┘ MySQL Flexible (snet-data)
jumpbox ──3306──► ✗ bloqué par nsg-data
```

### Choix
- **Mot de passe** : variable d'environnement `TF_VAR_mysql_admin_password`, lue par
  Terraform (convention `TF_VAR_`) et par Ansible (`lookup('env')`). Aucun fichier.
- **FQDN** : lu par Ansible directement dans les outputs Terraform (`lookup('pipe')`).
- **TLS conservé** (`require_secure_transport`) : `MYSQL_CLIENT_FLAGS = MYSQLI_CLIENT_SSL`.
- **MySQL 8.4** : le support standard de la 8.0 a pris fin le 31 mai 2026 (support étendu payant).
- **Clés WordPress** dérivées du mot de passe (sha256) : stables, donc playbook idempotent.

### Tests réalisés
| Test | Résultat |
|---|---|
| `nslookup` du FQDN depuis le Mac | NXDOMAIN (invisible depuis Internet) |
| `nslookup` depuis vm-app | CNAME → zone privée → `10.0.2.4` |
| `mysql` depuis vm-app | connecté, base `wordpress` présente, `Ssl_cipher` = TLS_AES_256_GCM_SHA384 |
| `nc` 3306 depuis la jumpbox | résolution OK, connexion en **timeout** (Deny NSG) |
| Playbook, 2e passage | `changed=0` |
| Assistant WordPress via le LB + article publié | OK |

<img src="docs/test_wordpress_article.png" alt="Article publié via le Load Balancer" width="700">

### Dette
- ~~Mot de passe MySQL en clair dans le state~~ → ✅ traité à l'étape 06 (`administrator_password_wo` + Key Vault).
- ~~WordPress se connecte avec le compte admin MySQL~~ → ✅ traité à l'étape 06 (utilisateur `wpuser`).
- Site en HTTP uniquement (HTTPS hors périmètre).

## Étape 05 — Stockage (Azure Files)

### Ce qui est ajouté
- **Storage account** `stwp<suffixe>` : StorageV2, Standard, LRS, secure transfer (HTTPS + SMB chiffré),
  TLS 1.2 min., accès public au blob désactivé, **accès réseau public désactivé**.
- **File share** `wp-uploads` : SMB, quota 1 Go, Transaction optimized.
- **Subnet `snet-pe`** (10.0.5.0/27) dédié aux private endpoints.
- **Private endpoint** `pe-storage-file` (sous-ressource `file`) + zone `privatelink.file.core.windows.net` liée au VNet.
- **Ansible** : cifs-utils, credentials root 600, montage persistant (fstab) sur `wp-content/uploads` (uid/gid www-data).

```
vm-app ──445 / SMB 3.1.1──► 10.0.5.4 (PE, snet-pe) ──► stwpxxx / wp-uploads
   DNS : stwpxxx.file.core.windows.net → CNAME privatelink → 10.0.5.4
Mac ──► stwpxxx.file.core.windows.net (IP publique) ──► ✗ 403 (accès public désactivé)
```

### Choix
- **Azure Files plutôt que Blob** : WordPress écrit sur un système de fichiers → aucun plugin (équivalent EFS).
- **Private endpoint plutôt que service endpoint** : IP privée, accès public fermable, même schéma que MySQL.
- **`storage_account_id`** sur le partage : Terraform passe par ARM → apply/destroy OK avec l'accès public fermé.
- **azurerm 5.x** : `public_network_access = "Disabled"` (le booléen est déprécié), lien DNS via `private_dns_zone_id`.
- **Options de montage** jointes par `join(',')` : aucun espace dans fstab.

### Tests réalisés
| Test | Résultat |
|---|---|
| `mount` depuis vm-app | `addr=10.0.5.4` (PE), `vers=3.1.1`, `uid=33` (www-data) |
| Upload d'une image dans WordPress | 4 fichiers (original + miniatures) dans `wp-uploads/2026/10` |
| Storage browser (accès public ouvert) | fichiers visibles (Access key) |
| Storage browser en Entra ID | 403 : Owner ≠ rôle data |
| Reboot de vm-app | partage remonté via fstab, image toujours affichée |
| Accès public désactivé, Storage browser depuis le Mac | 403 réseau |
| Après fermeture, `ls` depuis vm-app | fichiers accessibles via le PE |
| Playbook, 2e passage | `changed=0` |
| `destroy` avec accès public fermé | OK (plan de contrôle ARM) |

### Dette
- ~~Clé du storage dans l'output et passée par Ansible~~ → ✅ étape 06 : lue dans Key Vault par la VM.
  Elle reste dans le state comme attribut du storage account (inévitable).
- ~~Limite d'upload PHP à 2 Mo~~ → ✅ étape 06 : 64 Mo.
- Bonus non réalisé : snapshot du partage, soft delete, SAS, lifecycle (Blob).

## Étape 06 — Identité et secrets (Key Vault + Managed Identity)

### Ce qui est ajouté
- **Key Vault** `kv-wp-<suffixe>` : Standard, modèle **RBAC**, soft delete 7 jours, purge protection désactivée,
  accès public refusé sauf `admin_ip` (Terraform écrit les secrets depuis le poste admin).
- **Private endpoint** `pe-keyvault` (sous-ressource `vault`) dans snet-pe + zone `privatelink.vaultcore.azure.net`.
- **Managed Identity** system-assigned sur vm-app.
- **RBAC** (portée : le vault) : poste admin = `Key Vault Secrets Officer` · vm-app = `Key Vault Secrets User`.
- **`secrets.tf`** : 3 `ephemeral "random_password"` + 4 secrets en `value_wo`
  (`storage-account-key`, `mysql-admin-password`, `wp-db-password`, `wp-salt-seed`).
- **MySQL** : `administrator_password_wo` ; variable `mysql_admin_password` supprimée (plus de `TF_VAR`).
- **Ansible** : token IMDS + lecture des secrets (`uri`, `no_log`), utilisateur `wpuser`
  (`wordpress.*`, depuis `10.0.1.%`), clés WordPress dérivées de la graine, upload 64 Mo (Nginx + PHP).
- **Outputs** : `key_vault_name` ajouté, `storage_account_key` supprimé.

```
Terraform ──value_wo──► Key Vault ◄──PE 10.0.5.5── vm-app ◄── token ◄── IMDS (Managed Identity)
(rien dans le state)                                  │
                                                      ├──► MySQL (wpuser, TLS)
                                                      └──► Azure Files (clé SMB)
Mac ──vault.azure.net──► Key Vault : ip_rules = admin_ip (écriture des secrets)
```

### Choix
- **RBAC plutôt qu'access policies** : modèle recommandé ; un Contributor ne peut pas s'octroyer l'accès aux secrets.
- **Purge protection OFF + nom aléatoire** : `destroy`/`apply` sans blocage (en production : ON).
- **System-assigned** : une seule VM, identité liée à son cycle de vie.
- **Ephemeral + write-only** : mots de passe générés pendant le run, jamais écrits dans le state.
- **Une graine pour les 8 clés WordPress** : 1 secret au lieu de 8, playbook idempotent.
- **`99-uploads.ini`** plutôt qu'une édition de `php.ini` : surcharge simple et idempotente.

### Tests réalisés
| Test | Résultat |
|---|---|
| `nslookup` du vault depuis le Mac | IP publique (pas de zone privée) |
| `nslookup` depuis vm-app et la jumpbox | `10.0.5.5` (PE) |
| Lecture d'un secret depuis vm-app (token IMDS) | OK |
| Token IMDS depuis la jumpbox | `invalid_request` (aucune identité) |
| Lecture du secret depuis la jumpbox | **401** (non authentifiée) |
| Assistant WordPress avec `wpuser` | OK |
| Upload d'une image > 2 Mo | OK |
| Playbook, 2e passage | `changed=0` |
| State : `administrator_password` / `_wo` | `null` / `null` |
| State : valeur des 4 secrets | vide |
| `grep` du mot de passe `wpuser` dans le state et le backup | 0 occurrence |
| `destroy` | OK, vault purgé |

### Problèmes rencontrés
- **403 `ForbiddenByFirewall`** : IP publique changée en cours de session → retour sur la bonne IP, `apply` relancé.
- **`Access denied` pour `wpadmin`** : apply interrompu après la création de MySQL → mot de passe différent
  dans MySQL et dans Key Vault. Correction : incrémenter **ensemble** `administrator_password_wo_version`
  et `value_wo_version` (= procédure de rotation).

### Dette
- Clé du storage dans le state (attribut de `azurerm_storage_account`).
- `community.mysql.mysql_user` déprécié → `ansible.mysql.mysql_user`.
- Certificat TLS MySQL non vérifié côté PHP (optionnel).
- Rotation manuelle des secrets (incrément des versions).
- Site en HTTP uniquement.
