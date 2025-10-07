# SSH Key Management

HostKit bietet umfangreiches SSH-Key-Management für Ihre Websites. Sie können mehrere SSH-Schlüsselpaare pro Website erstellen, verwalten und automatisch in die authorized_keys integrieren lassen.

## Konzept

Jede registrierte Website hat:

-   **Default SSH Keys**: Standard-Schlüsselpaar (RSA + Ed25519) in `/opt/domains/<domain>/.ssh/`
-   **Additional SSH Keys**: Mehrere benannte Schlüsselpaare in `/opt/domains/<domain>/.ssh/keys/`

## Vorteile mehrerer Keys

-   **Verschiedene CI/CD-Pipelines**: GitHub Actions, GitLab CI, Jenkins, etc. mit eigenen Keys
-   **Mehrere Entwickler**: Jeder bekommt einen eigenen benannten Key
-   **Key-Rotation**: Einfacher Austausch ohne andere Keys zu beeinträchtigen
-   **Zugriffskontrolle**: Einzelne Keys können entfernt werden, ohne alle neu zu generieren

## Befehle

### Keys auflisten

Zeigt alle SSH-Keys für eine Website mit Status und Erstellungsdatum:

```bash
hostkit list-keys <domain|id>
```

**Beispiele:**

```bash
hostkit list-keys example.com
hostkit list-keys 0
```

**Ausgabe:**

```
╔══════════════════════════════════════════════════════════════════════════════╗
║ KEY NAME             ║ RSA          ║ ED25519      ║ CREATED                ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ github-actions       ║ ✓            ║ ✓            ║ 2025-01-15             ║
║ gitlab-ci            ║ ✓            ║ ✓            ║ 2025-01-20             ║
║ jenkins              ║ ✓            ║ ✗            ║ 2025-01-22             ║
╚══════════════════════════════════════════════════════════════════════════════╝

Total: 3 key(s)

Commands:
  hostkit add-key 0 <name>     - Create new SSH key
  hostkit show-key 0 <name>    - Display key content
  hostkit remove-key 0 <name>  - Remove SSH key
```

### Key erstellen

Erstellt ein neues SSH-Schlüsselpaar (RSA 4096-bit + Ed25519):

```bash
hostkit add-key <domain|id> <keyname>
```

**Key-Namen:**

-   Nur Buchstaben, Zahlen, Bindestriche und Unterstriche
-   Beispiele: `github-actions`, `dev-server`, `ci_deploy`

**Beispiele:**

```bash
hostkit add-key example.com github-actions
hostkit add-key 0 deployment-key
hostkit add-key 1 team-member-alice
```

**Was passiert:**

1. RSA 4096-bit Key wird generiert
2. Ed25519 Key wird generiert
3. Public Keys werden automatisch zur `authorized_keys` des Users hinzugefügt
4. Private Keys werden in `/opt/domains/<domain>/.ssh/keys/` gespeichert

### Key anzeigen

Zeigt den Inhalt eines SSH-Keys mit Kopieranweisungen:

```bash
hostkit show-key <domain|id> <keyname> [rsa|ed25519|all]
```

**Beispiele:**

```bash
# Alle Keys anzeigen (Standard)
hostkit show-key example.com github-actions

# Nur RSA Key
hostkit show-key 0 github-actions rsa

# Nur Ed25519 Key
hostkit show-key 0 github-actions ed25519
```

**Ausgabe:**

```
RSA Private Key:
cat << 'EOF' > ~/.ssh/hostkit-example-com-github-actions-rsa
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
EOF
chmod 600 ~/.ssh/hostkit-example-com-github-actions-rsa

RSA Public Key:
ssh-rsa AAAAB3NzaC1yc2EA... hostkit-example-com-github-actions-rsa

Ed25519 Private Key:
cat << 'EOF' > ~/.ssh/hostkit-example-com-github-actions-ed25519
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
EOF
chmod 600 ~/.ssh/hostkit-example-com-github-actions-ed25519

Ed25519 Public Key:
ssh-ed25519 AAAAC3NzaC1lZDI1NT... hostkit-example-com-github-actions-ed25519

GitHub Actions Secret Configuration:
Add the following secrets to your GitHub repository:

Secret name: DEPLOY_SSH_KEY
Secret value: Copy the Private Key content above
```

### Key entfernen

Entfernt einen SSH-Key und löscht ihn aus authorized_keys:

```bash
hostkit remove-key <domain|id> <keyname>
```

**Beispiele:**

```bash
hostkit remove-key example.com old-key
hostkit remove-key 0 deprecated
```

**Was passiert:**

1. Sicherheitsabfrage zur Bestätigung
2. Public Keys werden aus `authorized_keys` entfernt
3. Private und Public Key-Dateien werden gelöscht

## Integration mit CI/CD

### GitHub Actions

1. **Key erstellen:**

    ```bash
    hostkit add-key example.com github-actions
    ```

2. **Key anzeigen:**

    ```bash
    hostkit show-key example.com github-actions
    ```

3. **Als GitHub Secret hinzufügen:**

    - Repository Settings → Secrets and variables → Actions
    - New repository secret
    - Name: `DEPLOY_SSH_KEY`
    - Value: Private Key Inhalt (RSA oder Ed25519)

4. **In Workflow verwenden:**
    ```yaml
    - name: Deploy to VPS
      uses: appleboy/scp-action@master
      with:
          host: ${{ secrets.VPS_HOST }}
          username: deploy-example-com
          key: ${{ secrets.DEPLOY_SSH_KEY }}
          source: "build/*.tar"
          target: "/opt/domains/example.com/deploy/"
    ```

### GitLab CI

1. **Key erstellen:**

    ```bash
    hostkit add-key example.com gitlab-ci
    ```

2. **Key anzeigen und kopieren:**

    ```bash
    hostkit show-key example.com gitlab-ci rsa
    ```

3. **Als GitLab Variable hinzufügen:**

    - Project → Settings → CI/CD → Variables
    - Key: `SSH_PRIVATE_KEY`
    - Value: Private Key Inhalt
    - Type: File

4. **In Pipeline verwenden:**
    ```yaml
    deploy:
        script:
            - chmod 600 $SSH_PRIVATE_KEY
            - scp -i $SSH_PRIVATE_KEY build/*.tar deploy-example-com@your-vps:/opt/domains/example.com/deploy/
    ```

## Best Practices

### Key-Naming

-   **CI/CD-System**: `github-actions`, `gitlab-ci`, `jenkins`
-   **Umgebung**: `production-deploy`, `staging-deploy`
-   **Team-Member**: `dev-alice`, `dev-bob`, `ops-team`
-   **Zeitbasiert**: `deploy-2025-q1`, `temp-access-jan`

### Key-Rotation

Regelmäßige Key-Rotation erhöht die Sicherheit:

```bash
# Alten Key entfernen
hostkit remove-key example.com github-actions-old

# Neuen Key erstellen
hostkit add-key example.com github-actions-new

# Key in CI/CD aktualisieren
hostkit show-key example.com github-actions-new
```

### Key-Typen wählen

-   **RSA 4096**: Maximale Kompatibilität, funktioniert überall
-   **Ed25519**: Schneller, sicherer, moderner (empfohlen wenn unterstützt)

Beide werden automatisch erstellt, Sie können wählen welchen Sie verwenden.

## Verzeichnisstruktur

```
/opt/domains/example.com/.ssh/
├── id_rsa                    # Default RSA Private Key
├── id_rsa.pub                # Default RSA Public Key
├── id_ed25519                # Default Ed25519 Private Key
├── id_ed25519.pub            # Default Ed25519 Public Key
└── keys/                     # Additional Keys Directory
    ├── key-github-actions.rsa
    ├── key-github-actions.rsa.pub
    ├── key-github-actions.ed25519
    ├── key-github-actions.ed25519.pub
    ├── key-gitlab-ci.rsa
    ├── key-gitlab-ci.rsa.pub
    └── ...

/home/deploy-example-com/.ssh/
└── authorized_keys           # Alle Public Keys (default + additional)
```

## Automatische authorized_keys Synchronisation

HostKit synchronisiert automatisch alle Public Keys:

1. **Bei Key-Erstellung**: Public Keys werden zu `authorized_keys` hinzugefügt
2. **Bei Key-Löschung**: Public Keys werden aus `authorized_keys` entfernt
3. **Permissions**: Automatische Rechteverwaltung (600 für authorized_keys)

Sie müssen sich nicht um die manuelle Verwaltung der `authorized_keys` kümmern!

## Info-Command Integration

Der `info`-Command zeigt eine Übersicht aller Keys:

```bash
hostkit info example.com
```

**Key-Sektion in der Ausgabe:**

```
SSH KEYS (Default)
  RSA Key:             ✓ Present (4096 bit)
  Ed25519 Key:         ✓ Present

SSH KEYS (Additional)
  Total Keys:          3 key(s)
  • github-actions:    RSA: ✓  Ed25519: ✓
  • gitlab-ci:         RSA: ✓  Ed25519: ✓
  • jenkins:           RSA: ✓  Ed25519: ✗

  Use 'hostkit list-keys 0' for more details
```

## Tab-Completion

Alle Commands unterstützen Tab-Completion:

```bash
# Domain/ID Completion
hostkit add-key <TAB><TAB>
# Zeigt: example.com example2.com 0 1 2

# Key-Name Completion (für show-key und remove-key)
hostkit show-key example.com <TAB><TAB>
# Zeigt: github-actions gitlab-ci jenkins
```

## Fehlerbehebung

### "Key already exists"

Der Key-Name ist bereits vergeben. Wählen Sie einen anderen Namen oder entfernen Sie den alten Key:

```bash
hostkit remove-key example.com old-name
hostkit add-key example.com new-name
```

### "Invalid key name"

Key-Namen dürfen nur Buchstaben, Zahlen, Bindestriche und Unterstriche enthalten:

```bash
# ✓ Gültig
github-actions
deploy_key_2025
ci-cd-pipeline

# ✗ Ungültig
github actions  # Leerzeichen
deploy@key      # @-Zeichen
my.key          # Punkt
```

### "Permission denied" bei SSH

1. **Key korrekt kopiert?**

    ```bash
    hostkit show-key example.com github-actions
    ```

2. **Permissions richtig gesetzt?**

    ```bash
    chmod 600 ~/.ssh/hostkit-example-com-github-actions-rsa
    ```

3. **Key in authorized_keys?**
    ```bash
    # Auf dem Server als Website-User
    cat ~/.ssh/authorized_keys | grep github-actions
    ```

## Beispiel-Workflow

Kompletter Workflow für neues Projekt:

```bash
# 1. Website registrieren (erstellt Default Keys)
hostkit register

# 2. Zusätzliche Keys für verschiedene Zwecke erstellen
hostkit add-key example.com github-actions
hostkit add-key example.com gitlab-ci
hostkit add-key example.com dev-team

# 3. Keys anzeigen und in CI/CD konfigurieren
hostkit show-key example.com github-actions

# 4. Übersicht prüfen
hostkit list-keys example.com
hostkit info example.com

# 5. Bei Bedarf alten Key rotieren
hostkit remove-key example.com old-key
hostkit add-key example.com new-key

# 6. Key-Inhalt jederzeit erneut abrufen
hostkit show-key example.com github-actions rsa
```

## Sicherheitshinweise

-   **Private Keys nie committen**: Keys niemals in Git-Repositories speichern
-   **CI/CD Secrets verwenden**: Immer verschlüsselte Secret-Variablen nutzen
-   **Key-Rotation**: Regelmäßig Keys austauschen (z.B. alle 90 Tage)
-   **Zugriff limitieren**: Nur benötigte Keys erstellen
-   **Keys dokumentieren**: Notieren Sie wofür jeder Key verwendet wird
-   **Alte Keys entfernen**: Ungenutzte Keys sofort löschen

## Weiterführende Commands

```bash
# Standard User-Key-Management
hostkit list-users          # Alle User mit Key-Status
hostkit show-keys <domain>  # Default Keys anzeigen
hostkit regenerate-keys <domain>  # Default Keys neu generieren

# Zusätzliches Key-Management (neu)
hostkit list-keys <domain>  # Alle zusätzlichen Keys
hostkit add-key <domain> <name>    # Neuen Key erstellen
hostkit show-key <domain> <name>   # Key-Inhalt anzeigen
hostkit remove-key <domain> <name> # Key entfernen
```
