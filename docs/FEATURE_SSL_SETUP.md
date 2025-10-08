# Feature: Nachträgliche SSL-Zertifikat-Einrichtung - v1.3.2

## Neue Funktion

Du kannst jetzt **nachträglich** SSL-Zertifikate für bereits registrierte Websites einrichten!

## Neuer Befehl: `hostkit ssl-setup`

```bash
hostkit ssl-setup <domain|id>
```

## Motivation

Manchmal möchte man:
- SSL-Setup während der Registrierung überspringen
- Zuerst testen ohne SSL
- Warten bis DNS propagiert ist
- SSL später hinzufügen wenn alles läuft

## Verwendung

### SSL für existierende Website einrichten

```bash
# Mit Domain-Name
sudo hostkit ssl-setup example.com

# Mit Website-ID
sudo hostkit ssl-setup 0
```

### Interaktiver Prozess

```bash
sudo hostkit ssl-setup example.com

╔═══════════════════════════════════════════════════════════╗
║          SSL Certificate Setup                            ║
╚═══════════════════════════════════════════════════════════╝

ℹ Setting up SSL certificate for: example.com
Additional domains: www.example.com

Prerequisites:
  ✓ Domain(s) must point to this server's IP
  ✓ Port 80 must be accessible
  ✓ Nginx must be running

Note: Let's Encrypt rate limit is 5 certificates per domain per week

Continue with SSL setup? [Y/n]: y

Email for Let's Encrypt notifications: admin@example.com

➜ Requesting SSL certificate from Let's Encrypt...
✓ SSL certificate obtained successfully!
➜ Updating Nginx configuration...
✓ Nginx configuration updated
✓ Nginx reloaded
✓ SSL setup completed!

Your website is now accessible via HTTPS:
  https://example.com
  https://www.example.com

ℹ Certificate will auto-renew before expiry
```

## Was passiert?

1. **Prüfung**: Checkt ob Website existiert
2. **Voraussetzungen**: Zeigt Prerequisites an
3. **Email-Abfrage**: Für Let's Encrypt Benachrichtigungen
4. **Certbot-Anfrage**: Holt Zertifikat von Let's Encrypt
5. **Nginx-Update**: Konfiguriert HTTPS mit SSL
6. **Reload**: Startet Nginx neu
7. **Auto-Renewal**: Richtet automatische Verlängerung ein

## Features

### Automatische Domain-Erkennung

Alle Domains aus der Website-Konfiguration werden automatisch einbezogen:
- Hauptdomain
- Redirect-Domains (z.B. www-Variante)

```json
{
  "domain": "example.com",
  "redirect_domains": ["www.example.com"],
  "all_domains": ["example.com", "www.example.com"]
}
```

Alle Domains erhalten das gleiche Zertifikat (SAN - Subject Alternative Name).

### SSL-Konfiguration

Die Nginx-Konfiguration wird automatisch aktualisiert:

**HTTP → HTTPS Redirect:**
```nginx
server {
    listen 80;
    server_name example.com www.example.com;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 301 https://$server_name$request_uri;
    }
}
```

**HTTPS Server:**
```nginx
server {
    listen 443 ssl http2;
    server_name example.com www.example.com;
    
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    
    # Modern SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:...';
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    
    location / {
        proxy_pass http://127.0.0.1:3000;
        # ... proxy headers
    }
}
```

### Automatische Verlängerung

Ein Cron-Job wird automatisch eingerichtet:

```bash
# Läuft 2x täglich (00:00 und 12:00 Uhr)
0 0,12 * * * /usr/bin/certbot renew --quiet --post-hook 'systemctl reload nginx'
```

### Zertifikat-Erneuerung

Existierendes Zertifikat wird erkannt:

```bash
⚠ SSL certificate already exists for example.com
ℹ Current certificate expires: Dec 15 23:59:59 2025 GMT

Do you want to renew/replace the certificate? [Y/n]: 
```

## Verwandte Befehle

### SSL-Status prüfen

```bash
# Alle Domains
sudo hostkit ssl-status

# Spezifische Domain
sudo hostkit ssl-status example.com
sudo hostkit ssl-status 0
```

**Ausgabe:**
```
╔═══════════════════════════════════════════════════════════╗
║          SSL Certificate Status                           ║
╚═══════════════════════════════════════════════════════════╝

Domain: example.com
  Status: Valid
  Days left: 87
  Expires: Dec 15 23:59:59 2025 GMT
  Issuer: CN=R3,O=Let's Encrypt,C=US
```

**Status-Farben:**
- 🟢 **Grün**: Gültig (>7 Tage)
- 🟡 **Gelb**: Läuft bald ab (<7 Tage)
- 🔴 **Rot**: Abgelaufen

### SSL-Zertifikat erneuern

```bash
# Alle Zertifikate
sudo hostkit ssl-renew

# Spezifisches Zertifikat
sudo hostkit ssl-renew example.com
sudo hostkit ssl-renew 0
```

## Workflows

### Workflow 1: SSL während Registrierung überspringen

```bash
# Registrierung ohne SSL
sudo hostkit register
# Bei "Setup SSL certificates?" → n

# Später SSL hinzufügen
sudo hostkit ssl-setup example.com
```

### Workflow 2: DNS propagieren lassen

```bash
# Domain registrieren
sudo hostkit register

# SSL überspringen weil DNS noch nicht propagiert
# Bei "Setup SSL certificates?" → n

# 24 Stunden warten...

# Jetzt SSL einrichten
sudo hostkit ssl-setup example.com
```

### Workflow 3: Testing ohne SSL

```bash
# Für Entwicklung ohne SSL registrieren
sudo hostkit register
# SSL überspringen

# Deployment testen mit HTTP
curl http://example.com

# Wenn alles läuft, SSL aktivieren
sudo hostkit ssl-setup example.com
```

## Voraussetzungen

Für erfolgreiche SSL-Einrichtung benötigt:

✅ **DNS konfiguriert**: Domain zeigt auf Server-IP  
✅ **Port 80 offen**: Firewall erlaubt HTTP-Traffic  
✅ **Nginx läuft**: `systemctl status nginx`  
✅ **Valide Email**: Für Let's Encrypt Benachrichtigungen  

### DNS-Prüfung

```bash
# Prüfe ob Domain auf Server zeigt
dig +short example.com
# Sollte deine Server-IP zurückgeben

# Oder
nslookup example.com
```

### Firewall-Prüfung

```bash
# Port 80 und 443 öffnen
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Status prüfen
sudo ufw status
```

## Fehlerbehebung

### "Failed to obtain SSL certificate"

**Mögliche Ursachen:**

1. **DNS nicht propagiert**
   ```bash
   # Prüfen
   dig +short example.com
   
   # Warten und nochmal versuchen
   ```

2. **Port 80 blockiert**
   ```bash
   # Firewall prüfen
   sudo ufw status
   sudo ufw allow 80/tcp
   ```

3. **Nginx nicht erreichbar**
   ```bash
   # Status prüfen
   sudo systemctl status nginx
   
   # Neu starten
   sudo systemctl restart nginx
   ```

4. **Rate Limit erreicht**
   ```
   Let's Encrypt: 5 Zertifikate pro Domain pro Woche
   
   # Warten oder Staging-Server testen:
   certbot certonly --staging ...
   ```

### "Domain not pointing to this server"

```bash
# DNS-Propagation prüfen
dig example.com
nslookup example.com

# Kann 24-48 Stunden dauern nach DNS-Änderung
```

### Zertifikat existiert bereits

Wenn du das Zertifikat ersetzen willst:

```bash
sudo hostkit ssl-setup example.com
# Frage mit Y beantworten
```

Oder manuell entfernen:

```bash
sudo certbot delete --cert-name example.com
sudo hostkit ssl-setup example.com
```

## Sicherheit

### SSL-Konfiguration

Die Nginx SSL-Konfiguration folgt Best Practices:

- ✅ **TLS 1.2 & 1.3**: Moderne Protokolle
- ✅ **Starke Ciphers**: ECDHE mit AES-GCM
- ✅ **HSTS**: Strict-Transport-Security Header
- ✅ **Security Headers**: X-Frame-Options, X-Content-Type-Options
- ✅ **HTTP/2**: Bessere Performance

### Zertifikats-Verwaltung

- ✅ **Auto-Renewal**: Automatische Verlängerung vor Ablauf
- ✅ **Notifications**: Email bei Problemen
- ✅ **Monitoring**: `ssl-status` zeigt Days-Left
- ✅ **Rollback**: Alte Nginx-Config wird bei Fehler wiederhergestellt

## Technische Details

### Certbot-Kommando

```bash
certbot certonly --nginx \
  -d example.com \
  -d www.example.com \
  --non-interactive \
  --agree-tos \
  --email admin@example.com
```

### Zertifikats-Speicherort

```
/etc/letsencrypt/live/example.com/
├── fullchain.pem    → Komplettes Zertifikat (Server + Intermediate)
├── privkey.pem      → Private Key (GEHEIM!)
├── cert.pem         → Server-Zertifikat
└── chain.pem        → Intermediate-Zertifikat
```

### Nginx-Konfiguration

Wird gespeichert in:
```
/etc/nginx/sites-available/example.com
/etc/nginx/sites-enabled/example.com → symlink
```

### Logs

SSL-Setup-Logs:
```bash
# Certbot-Logs
/var/log/letsencrypt/letsencrypt.log

# Nginx-Logs
/var/log/nginx/example.com_access.log
/var/log/nginx/example.com_error.log
```

## Bash-Completion

Auto-Completion für SSL-Befehle:

```bash
hostkit ssl-<TAB>
# ssl-setup  ssl-status  ssl-renew

hostkit ssl-setup <TAB>
# example.com  test.com  0  1  2
```

## Version

- **Feature in**: v1.3.2
- **Abhängigkeiten**: Certbot, Nginx, OpenSSL
- **Kompatibilität**: Ubuntu 20.04+, Debian 11+

## Beispiele

### Kompletter Workflow

```bash
# 1. Website ohne SSL registrieren
sudo hostkit register
# Domain: example.com
# Bei SSL-Setup: n

# 2. Deployment testen
sudo hostkit deploy example.com app.tar
curl http://example.com

# 3. SSL hinzufügen wenn alles funktioniert
sudo hostkit ssl-setup example.com

# 4. Status prüfen
sudo hostkit ssl-status example.com

# 5. Zugriff via HTTPS
curl https://example.com
```

### Mehrere Domains

```bash
# Hauptdomain + Subdomains
sudo hostkit register
# Domain: example.com
# Redirects: www.example.com, app.example.com

# SSL für alle Domains
sudo hostkit ssl-setup example.com
# Alle 3 Domains erhalten das gleiche Zertifikat
```

### Wildcard-Zertifikat (Fortgeschritten)

Für Wildcard-Zertifikate (*.example.com) benötigst du DNS-Challenge:

```bash
sudo certbot certonly --manual \
  --preferred-challenges dns \
  -d "*.example.com" \
  -d example.com
```

Dann manuell Nginx-Konfiguration anpassen.

## Support

Bei Problemen:

```bash
# Certbot-Status
sudo certbot certificates

# Nginx-Test
sudo nginx -t

# Logs prüfen
sudo tail -f /var/log/letsencrypt/letsencrypt.log

# HostKit-Status
sudo hostkit ssl-status all
```
