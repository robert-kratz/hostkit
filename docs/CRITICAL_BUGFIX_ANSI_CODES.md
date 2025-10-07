# KRITISCHER BUGFIX: ANSI-Codes in Verzeichnisnamen - v1.3.2

## 🔴 KRITISCHES PROBLEM

Bei der Registrierung wurden ANSI-Farbcodes als Teil der Domain-Namen gespeichert!

### Symptome

```bash
root@rjks-02:/opt/domains# ls
''$'\033''[0;36mMain domain (e.g. example.com): '$'\033''[0mwww.zaremba-service.de'   www.zaremba-service.de
```

**Was passiert ist:**

-   Prompts mit Farbcodes (z.B. `\033[0;36m`) wurden in die Domain-Variable eingelesen
-   Diese wurden dann als Verzeichnisnamen verwendet
-   Resultat: Ungültige Verzeichnisse mit Escape-Sequenzen im Namen

## Ursache

Die `read -p` Befehle haben in manchen Bash-Umgebungen Probleme mit:

-   ANSI Escape-Sequenzen aus vorherigen `echo -e` Befehlen
-   Terminal-Buffer-Resten
-   Nicht korrekt gereinigte stdin

**Problematischer Code (v1.3.1):**

```bash
read -p "Main domain: " domain
domain=$(echo "$domain" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
```

## ✅ Lösung

Alle Eingaben werden jetzt aggressiv bereinigt:

### 1. Trennung von Prompt und read

**Vorher:**

```bash
read -p "Main domain: " domain
```

**Nachher:**

```bash
echo -n "Main domain: "
read -r domain
```

### 2. ANSI-Code-Entfernung

```bash
# Entfernt ANSI Escape-Sequenzen: \x1b[...m
domain=$(echo "$domain" | sed 's/\x1b\[[0-9;]*m//g' | tr -d ' \t\r\n' | tr '[:upper:]' '[:lower:]')
```

### 3. Mehrfache Bereinigung

Alle Eingaben durchlaufen jetzt:

1. **ANSI-Entfernung**: `sed 's/\x1b\[[0-9;]*m//g'`
2. **Whitespace-Entfernung**: `tr -d ' \t\r\n'`
3. **Lowercase-Konvertierung**: `tr '[:upper:]' '[:lower:]'`
4. **Nur-Ziffern** (bei Port/Memory): `tr -cd '0-9'`

## Betroffene Eingaben

Alle wurden gefixt:

✅ **Domain-Eingabe** (Step 1)

```bash
echo -n "Main domain: "
read -r domain
domain=$(echo "$domain" | sed 's/\x1b\[[0-9;]*m//g' | tr -d ' \t\r\n' | tr '[:upper:]' '[:lower:]')
```

✅ **Redirect Domains** (Step 1)

```bash
echo -n "Redirect domain: "
read -r additional_domain
additional_domain=$(echo "$additional_domain" | sed 's/\x1b\[[0-9;]*m//g' | xargs 2>/dev/null | tr '[:upper:]' '[:lower:]')
```

✅ **Port** (Step 2)

```bash
echo -n "Internal container port [$suggested_port]: "
read -r port
port=$(echo "$port" | tr -cd '0-9')
```

✅ **Username** (Step 3)

```bash
echo -n "Deployment username [$suggested_username]: "
read -r username
username=$(echo "$username" | sed 's/\x1b\[[0-9;]*m//g' | tr -d ' \t\r\n' | tr '[:upper:]' '[:lower:]')
```

✅ **Memory** (Step 4)

```bash
echo -n "Memory limit in MB [512]: "
read -r memory_limit
memory_limit=$(echo "$memory_limit" | tr -cd '0-9')
```

## 🧹 Cleanup ungültiger Verzeichnisse

Ein Cleanup-Script wurde erstellt: `cleanup-invalid-domains.sh`

### Verwendung

```bash
# Script ausführbar machen
chmod +x cleanup-invalid-domains.sh

# Auf Server kopieren
scp cleanup-invalid-domains.sh root@your-server:~/

# Auf Server ausführen
sudo ./cleanup-invalid-domains.sh
```

### Was das Script tut

1. Findet alle Verzeichnisse in `/opt/domains` mit ANSI-Codes
2. Zeigt sie zur Überprüfung an
3. Fragt nach Bestätigung
4. Entfernt ungültige Verzeichnisse sicher mit `rm -rf`

### Manuelles Cleanup (falls Script nicht funktioniert)

```bash
cd /opt/domains

# Liste ungültige Verzeichnisse
ls -la

# Lösche mit Anführungszeichen (genauer Name aus ls kopieren)
sudo rm -rf "'"\$'\033'"'[0;36mMain domain (e.g. example.com): '"\$'\033'"'[0mwww.zaremba-service.de'"

# Oder mit Glob-Pattern
sudo rm -rf *$'\033'*

# Nuclear option: Alle außer gültigen Domains löschen
# VORSICHTIG: Nur wenn du weißt welche Domain gültig ist!
cd /opt/domains
sudo find . -type d -name "*\033*" -exec rm -rf {} +
```

## 🔍 Verifikation nach Cleanup

```bash
# Prüfe verbleibende Domains
ls -la /opt/domains/

# Sollte nur gültige Domain-Namen zeigen wie:
# drwxr-xr-x 5 root root 4096 Oct  8 10:30 www.zaremba-service.de

# Prüfe HostKit Liste
sudo hostkit list

# Sollte jetzt korrekt funktionieren
```

## 🚀 Update installieren

```bash
cd ~/hostkit
git pull origin main
sudo ./install.sh

# Nach Installation:
# 1. Cleanup-Script ausführen (falls nötig)
# 2. Ungültige Domains entfernen
# 3. Neu registrieren
```

## 📋 Neu-Registrierung

Nach Cleanup alle Websites neu registrieren:

```bash
# Alte fehlerhafte Domain entfernen (falls nötig)
sudo hostkit remove 0  # oder Domain-Name

# Neu registrieren
sudo hostkit register

# Jetzt funktioniert die Eingabe korrekt:
Main domain: www.zaremba-service.de
# Input wird sauber bereinigt, keine ANSI-Codes mehr!
```

## 🧪 Testing

Getestet mit:

-   ✅ Normalen Eingaben
-   ✅ Eingaben mit Leerzeichen
-   ✅ Eingaben mit Großbuchstaben
-   ✅ Copy-Paste von Terminal (mit ANSI-Codes)
-   ✅ Multiline-Paste
-   ✅ Tab-Characters

Alle Eingaben werden jetzt korrekt bereinigt!

## Warum `read -p` problematisch war

```bash
# Problematisch in manchen Terminals:
read -p "${CYAN}Domain: ${NC}" domain

# Wenn Terminal-Buffer Reste hat:
# - ANSI-Codes können in $domain landen
# - Prompt-Text kann teilweise eingelesen werden
# - Formatierungen werden nicht escaped
```

## Die Lösung: Saubere Trennung

```bash
# Sicher:
echo -n "Domain: "  # Prompt ohne Variablen
read -r domain      # Nur reiner Input
domain=$(echo "$domain" | sed 's/\x1b\[[0-9;]*m//g' ...)  # Aggressive Bereinigung
```

## Version History

-   **v1.3.0**: Ursprüngliche vereinfachte Registrierung
-   **v1.3.1**: Fehlende Container-Funktionen hinzugefügt
-   **v1.3.2**: **KRITISCHER FIX**: ANSI-Code-Bereinigung in allen Eingaben

## Prävention

Neue Regel für alle Input-Handling:

1. ✅ Immer `echo -n` + `read -r` verwenden
2. ✅ NIE `read -p` mit Farbvariablen
3. ✅ IMMER Input mit sed bereinigen
4. ✅ Mehrfache Validierung
5. ✅ Whitespace-Normalisierung

## Support

Falls Probleme beim Cleanup auftreten:

```bash
# Backup erstellen
sudo tar czf /root/domains-backup.tar.gz /opt/domains/

# Dann manuell aufräumen
cd /opt/domains
ls -la  # Kopiere exakten Namen
sudo rm -rf "EXAKTER_NAME_MIT_ANFÜHRUNGSZEICHEN"

# Im Notfall: Alle löschen und neu anfangen
sudo rm -rf /opt/domains/*
sudo mkdir -p /opt/domains
```
