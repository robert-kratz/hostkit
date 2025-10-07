# HostKit Dokumentation

Willkommen in der HostKit-Dokumentation! Hier finden Sie detaillierte Anleitungen, Beispiele und Best Practices für die Verwendung von HostKit.

## 📚 Dokumentations-Übersicht

### Haupt-Dokumentation

-   **[README](../README.md)** - Hauptdokumentation mit Quick Start Guide
-   **[GitHub Actions Examples](github-actions-example.md)** - Vollständige CI/CD-Workflows

### SSH & Sicherheit

-   **[SSH Key Management](SSH_KEY_MANAGEMENT.md)** - Multi-Key-System und Verwaltung
-   **[SSH Key Workflows](SSH_KEY_WORKFLOWS.md)** - Praktische Workflows und Use Cases
-   **[Security Enhancements](SECURITY_ENHANCEMENTS.md)** - Sicherheits-Features im Detail

### System & Verwaltung

-   **[Input Validation](INPUT_VALIDATION.md)** - Validierungssystem und Retry-Logik
-   **[Uninstall Guide](UNINSTALL.md)** - Deinstallationsoptionen
-   **[Migration Guide](MIGRATION_WEB-MANAGER_TO_HOSTKIT.md)** - Upgrade von web-manager

---

## 🚀 Schnellstart-Links

### Für Einsteiger

1. [Installation](../README.md#-installation)
2. [Quick Start](../README.md#-quick-start)
3. [Erste Website registrieren](../README.md#1-erste-website-registrieren)
4. [GitHub Actions Setup](github-actions-example.md#basis-workflow)

### Für Fortgeschrittene

1. [Multi-Key SSH Management](SSH_KEY_MANAGEMENT.md)
2. [Multi-Stage Deployment](github-actions-example.md#multi-stage-deployment)
3. [Blue-Green Deployment](github-actions-example.md#blue-green-deployment)
4. [Security Best Practices](SECURITY_ENHANCEMENTS.md)

---

## 📖 Dokumentation nach Themen

### Deployment & CI/CD

| Dokument                                                                   | Beschreibung                       | Level           |
| -------------------------------------------------------------------------- | ---------------------------------- | --------------- |
| [GitHub Actions Examples](github-actions-example.md)                       | 5+ vollständige Workflow-Beispiele | Alle            |
| [GitHub Actions - Basis](github-actions-example.md#basis-workflow)         | Einfacher Deployment-Workflow      | Einsteiger      |
| [Multi-Stage Deployment](github-actions-example.md#multi-stage-deployment) | Staging & Production Environments  | Fortgeschritten |
| [Blue-Green Deployment](github-actions-example.md#blue-green-deployment)   | Zero-Downtime Deployments          | Fortgeschritten |
| [Rollback Workflow](github-actions-example.md#rollback-bei-fehlern)        | Automatisches Rollback             | Fortgeschritten |

### SSH Key Management

| Dokument                                                        | Beschreibung                 | Level           |
| --------------------------------------------------------------- | ---------------------------- | --------------- |
| [SSH Key Management](SSH_KEY_MANAGEMENT.md)                     | Vollständige Anleitung       | Alle            |
| [Key Creation & Deletion](SSH_KEY_MANAGEMENT.md#befehle)        | Keys erstellen und verwalten | Einsteiger      |
| [CI/CD Integration](SSH_KEY_MANAGEMENT.md#integration-mit-cicd) | Keys in Pipelines nutzen     | Mittel          |
| [Key Rotation](SSH_KEY_MANAGEMENT.md#best-practices)            | Regelmäßiger Key-Austausch   | Fortgeschritten |
| [Workflow Examples](SSH_KEY_WORKFLOWS.md)                       | Praktische Beispiele         | Alle            |

### Sicherheit

| Dokument                                                            | Beschreibung                   | Level           |
| ------------------------------------------------------------------- | ------------------------------ | --------------- |
| [Security Enhancements](SECURITY_ENHANCEMENTS.md)                   | Alle Sicherheits-Features      | Alle            |
| [SSH Hardening](SECURITY_ENHANCEMENTS.md#ssh-hardening)             | SSH-Absicherung im Detail      | Fortgeschritten |
| [User Isolation](SECURITY_ENHANCEMENTS.md#user-isolation)           | Isolation von Deployment-Usern | Mittel          |
| [Command Restriction](SECURITY_ENHANCEMENTS.md#command-restriction) | Eingeschränkte SSH-Befehle     | Fortgeschritten |

### System-Administration

| Dokument                                               | Beschreibung              | Level  |
| ------------------------------------------------------ | ------------------------- | ------ |
| [Input Validation](INPUT_VALIDATION.md)                | Validierung & Retry-Logik | Mittel |
| [Uninstall Guide](UNINSTALL.md)                        | Deinstallation & Cleanup  | Alle   |
| [Migration Guide](MIGRATION_WEB-MANAGER_TO_HOSTKIT.md) | Upgrade-Anleitung         | Alle   |

---

## 🎯 Häufige Aufgaben

### Website-Management

```bash
# Website registrieren
sudo hostkit register

# Status prüfen
sudo hostkit list
sudo hostkit info <domain|id>

# Logs anzeigen
sudo hostkit logs <domain|id>
```

👉 [Vollständige Befehls-Referenz](../README.md#-befehls-referenz)

### Deployment

```bash
# Manuell deployen
sudo hostkit deploy <domain|id> /path/to/image.tar

# Versionen verwalten
sudo hostkit versions <domain|id>
sudo hostkit switch <domain|id> <version>
```

👉 [GitHub Actions Integration](github-actions-example.md)

### SSH Keys

```bash
# Keys auflisten
sudo hostkit list-keys <domain|id>

# Neuen Key erstellen
sudo hostkit add-key <domain|id> <key-name>

# Key anzeigen
sudo hostkit show-key <domain|id> <key-name>
```

👉 [SSH Key Management Guide](SSH_KEY_MANAGEMENT.md)

---

## 🔍 Suche & Navigation

### Nach Feature suchen

-   **GitHub Actions** → [github-actions-example.md](github-actions-example.md)
-   **SSH Keys** → [SSH_KEY_MANAGEMENT.md](SSH_KEY_MANAGEMENT.md)
-   **Sicherheit** → [SECURITY_ENHANCEMENTS.md](SECURITY_ENHANCEMENTS.md)
-   **Multi-Stage** → [github-actions-example.md#multi-stage-deployment](github-actions-example.md#multi-stage-deployment)
-   **Rollback** → [github-actions-example.md#rollback-bei-fehlern](github-actions-example.md#rollback-bei-fehlern)

### Nach Problem suchen

-   **Permission Denied** → [README Troubleshooting](../README.md#-fehlerbehebung)
-   **Container startet nicht** → [README Troubleshooting](../README.md#-fehlerbehebung)
-   **SSL-Probleme** → [README Troubleshooting](../README.md#-fehlerbehebung)
-   **Deployment Fehler** → [GitHub Actions Troubleshooting](github-actions-example.md#fehlerbehebung)

---

## 💡 Tipps & Tricks

### Produktivitäts-Tipps

1. **Nutzen Sie IDs statt Domain-Namen**

    ```bash
    # Statt
    sudo hostkit info example.com

    # Nutzen Sie
    sudo hostkit list  # Zeigt IDs
    sudo hostkit info 0
    ```

2. **Tab-Completion aktivieren**

    ```bash
    # Wird bei Installation automatisch eingerichtet
    hostkit <TAB><TAB>  # Zeigt alle Commands
    hostkit info <TAB><TAB>  # Zeigt Domains & IDs
    ```

3. **Mehrere Keys für verschiedene Zwecke**
    ```bash
    sudo hostkit add-key example.com github-actions
    sudo hostkit add-key example.com gitlab-ci
    sudo hostkit add-key example.com manual-deploy
    ```

### Best Practices

1. **Regelmäßige Key-Rotation** - Siehe [SSH Key Management](SSH_KEY_MANAGEMENT.md#best-practices)
2. **Multi-Stage Deployment** - Siehe [GitHub Actions Examples](github-actions-example.md#multi-stage-deployment)
3. **Health Checks** - Siehe [Blue-Green Deployment](github-actions-example.md#blue-green-deployment)
4. **Monitoring** - Nutzen Sie `hostkit ssl-status` regelmäßig

---

## 🆘 Hilfe & Support

### Support-Kanäle

-   📖 **Dokumentation durchsuchen**: Nutzen Sie Strg+F / Cmd+F
-   🐛 **Bug melden**: [GitHub Issues](https://github.com/robert-kratz/hostkit/issues)
-   💬 **Frage stellen**: [GitHub Discussions](https://github.com/robert-kratz/hostkit/discussions)
-   📧 **Direkter Kontakt**: Siehe [README](../README.md#-support)

### Bevor Sie eine Frage stellen

1. ✅ Relevante Dokumentation gelesen?
2. ✅ [Troubleshooting](../README.md#-fehlerbehebung) durchgegangen?
3. ✅ `hostkit logs` überprüft?
4. ✅ GitHub Issues durchsucht?

---

## 📝 Dokumentation beitragen

Möchten Sie die Dokumentation verbessern?

1. Fork das Repository
2. Bearbeiten Sie die Markdown-Dateien
3. Erstellen Sie einen Pull Request
4. Beschreiben Sie Ihre Änderungen

**Dokumentations-Richtlinien:**

-   Klare, präzise Sprache
-   Code-Beispiele für alle Konzepte
-   Screenshots wo sinnvoll
-   Links zu verwandten Themen

---

## 📚 Externe Ressourcen

-   [Docker Dokumentation](https://docs.docker.com/)
-   [GitHub Actions Dokumentation](https://docs.github.com/en/actions)
-   [Nginx Dokumentation](https://nginx.org/en/docs/)
-   [Let's Encrypt Dokumentation](https://letsencrypt.org/docs/)

---

<div align="center">

**[⬆ Zurück zur Hauptseite](../README.md)**

Made with ❤️ by the HostKit Team

</div>
