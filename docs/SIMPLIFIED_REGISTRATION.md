# Vereinfachte Registrierung - v1.3.1

## Änderungen

Die Benutzereingabe im Registrierungsprozess wurde drastisch vereinfacht, um Komplexität zu reduzieren und Fehler zu vermeiden.

## Vorher vs. Nachher

### Vorher (v1.3.0)

-   Komplexe `read_domain_input()`, `read_port_input()`, `read_username_input()` Funktionen
-   Command substitution mit stderr/stdout Redirection
-   Verschachtelte while-Loops mit ask_yes_no
-   Komplexe Fehlerbehandlung und Retry-Logik
-   Verkettungsfehler bei Prompts möglich

### Nachher (v1.3.1)

-   Direkte `read -p` Befehle
-   Einfache while-Loops mit klaren Abbruchbedingungen
-   Inline-Validierung
-   Keine Command-Substitution für Benutzereingaben
-   Saubere Trennung von Ausgabe und Eingabe

## Was wurde vereinfacht?

### 1. Domain-Eingabe

**Alt:**

```bash
domain=$(read_domain_input "Main domain")
```

**Neu:**

```bash
local domain=""
while [ -z "$domain" ]; do
    read -p "Main domain: " domain
    domain=$(echo "$domain" | tr -d ' ' | tr '[:upper:]' '[:lower:]')

    if [ -z "$domain" ]; then
        echo -e "${RED}✗ Domain cannot be empty${NC}"
        continue
    fi

    if [ -d "$WEB_ROOT/$domain" ]; then
        echo -e "${RED}✗ Domain already registered${NC}"
        domain=""
        continue
    fi

    if ! validate_domain "$domain"; then
        echo -e "${RED}✗ Invalid domain format${NC}"
        domain=""
        continue
    fi
done
```

**Vorteile:**

-   Keine Command-Substitution
-   Direkte Fehlerausgabe
-   Klarer Loop-Exit
-   Automatische Normalisierung (lowercase, trimming)

### 2. Redirect Domains

**Alt:**

```bash
while true; do
    echo -ne "${CYAN}Additional domain (press Enter to finish): ${NC}" >&2
    read -r additional_domain

    if [ -z "$additional_domain" ]; then
        print_info "Finished adding redirect domains" >&2
        break
    fi

    if ! validate_domain "$additional_domain"; then
        print_error "Invalid domain format: $additional_domain" >&2
        print_info "Please use a valid domain format like: subdomain.example.com" >&2
        continue
    fi

    # ... mehr Checks
done
```

**Neu:**

```bash
while true; do
    read -p "Redirect domain (or press Enter to finish): " additional_domain
    additional_domain=$(echo "$additional_domain" | tr -d ' ' | tr '[:upper:]' '[:lower:]')

    [ -z "$additional_domain" ] && break

    if validate_domain "$additional_domain" && [ ! -d "$WEB_ROOT/$additional_domain" ]; then
        redirect_domains+=("$additional_domain")
        echo -e "${GREEN}✓ Added: $additional_domain${NC}"
    else
        echo -e "${YELLOW}⚠ Skipped (invalid or already exists)${NC}"
    fi
done
```

**Vorteile:**

-   Kompakter Code
-   Kombinierte Validierung
-   Weniger Fehlermeldungen
-   Einfacher Exit mit Enter

### 3. Port-Eingabe

**Alt:**

```bash
port=$(read_port_input "Internal container port" "$suggested_port")
if [ $? -ne 0 ]; then
    print_error "Registration cancelled"
    return 1
fi
```

**Neu:**

```bash
local port=""
while [ -z "$port" ]; do
    read -p "Internal container port [$suggested_port]: " port
    port=${port:-$suggested_port}

    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1024 ] || [ "$port" -gt 65535 ]; then
        echo -e "${RED}✗ Port must be between 1024-65535${NC}"
        port=""
        continue
    fi

    if ! check_port_conflict "$port" ""; then
        echo -e "${RED}✗ Port already in use${NC}"
        suggested_port=$(get_next_available_port $((port + 1)))
        echo -e "${CYAN}ℹ Next available: $suggested_port${NC}"
        port=""
    fi
done
```

**Vorteile:**

-   Direktes Feedback
-   Vorschlag für nächsten freien Port
-   Keine Fehler bei Exit-Code-Prüfung

### 4. Username-Eingabe

**Alt:**

```bash
username=$(read_username_input "Deployment username" "$suggested_username")
if [ $? -ne 0 ]; then
    print_error "Registration cancelled"
    return 1
fi
```

**Neu:**

```bash
local username=""
while [ -z "$username" ]; do
    read -p "Deployment username [$suggested_username]: " username
    username=${username:-$suggested_username}
    username=$(echo "$username" | tr -d ' ' | tr '[:upper:]' '[:lower:]')

    if ! validate_username "$username"; then
        echo -e "${RED}✗ Invalid username (lowercase letters, numbers, hyphens only)${NC}"
        username=""
        continue
    fi

    if id "$username" &>/dev/null; then
        echo -e "${RED}✗ User already exists${NC}"
        username=""
    fi
done
```

**Vorteile:**

-   Keine Prompt-Verkettung
-   Automatische Normalisierung
-   Klare Fehlerausgabe

### 5. Memory-Eingabe

**Alt:**

```bash
source "/opt/hostkit/modules/memory.sh"
local memory_values=$(select_memory_limit "$domain" "")
local memory_limit=$(echo "$memory_values" | awk '{print $1}')
local memory_reservation=$(echo "$memory_values" | awk '{print $2}')
```

**Neu:**

```bash
local total_mem=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
local system_reserve=$((total_mem / 5))
[ "$system_reserve" -lt 512 ] && system_reserve=512
[ "$system_reserve" -gt 2048 ] && system_reserve=2048
local available=$((total_mem - system_reserve))

echo -e "${CYAN}System memory: ${total_mem}MB | Available: ${available}MB${NC}"

local memory_limit=""
while [ -z "$memory_limit" ]; do
    read -p "Memory limit in MB [512]: " memory_limit
    memory_limit=${memory_limit:-512}

    if ! [[ "$memory_limit" =~ ^[0-9]+$ ]] || [ "$memory_limit" -lt 128 ]; then
        echo -e "${RED}✗ Minimum 128MB required${NC}"
        memory_limit=""
        continue
    fi

    if [ "$memory_limit" -gt "$available" ]; then
        echo -e "${RED}✗ Exceeds available memory (${available}MB)${NC}"
        memory_limit=""
    fi
done

local memory_reservation=$((memory_limit / 2))
memory_limit="${memory_limit}m"
memory_reservation="${memory_reservation}m"
```

**Vorteile:**

-   Keine externe Funktion
-   Inline-Berechnung
-   Direktes Feedback über verfügbaren Speicher
-   Kompaktere Ausgabe

## Neue Benutzererfahrung

```bash
sudo hostkit register

╔═══════════════════════════════════════╗
║        HOSTKIT v1.3.1                 ║
║   VPS Website Management Tool         ║
╚═══════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 1: Domain Configuration
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Examples: example.com, subdomain.example.com

Main domain: example.com

Add redirect domains? (e.g., www.example.com) [Y/n]: y
Redirect domain (or press Enter to finish): www.example.com
✓ Added: www.example.com
Redirect domain (or press Enter to finish):

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 2: Port Assignment
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Internal container port [3000]:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 3: User Setup
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Deployment username [deploy-example-com]:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 4: Memory Allocation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Common: 512MB (small), 1024MB (medium), 2048MB (large)

System memory: 2048MB | Available: 1536MB

Memory limit in MB [512]:
✓ Memory limit: 512m (reservation: 256m)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Configuration Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Domain:   example.com
  Redirects: www.example.com
  Port:     3000
  User:     deploy-example-com
  Memory:   512m

Proceed with registration? [Y/n]:
```

## Technische Details

### Automatische Normalisierung

Alle Eingaben werden automatisch normalisiert:

-   **Domain/Username**: Lowercase, Leerzeichen entfernt
-   **Port/Memory**: Nur Zahlen, Standardwerte bei leer

### Validierung

Validierung erfolgt inline im Loop:

-   Ungültige Eingabe → Variable zurücksetzen, Loop fortsetzt
-   Gültige Eingabe → Loop bricht ab, weiter zum nächsten Schritt

### Fehlerbehandlung

-   **Keine Exit-Codes mehr zu prüfen**
-   Fehlermeldungen direkt bei Eingabe
-   Kein Abbruch durch Fehler in Subfunktionen

### stderr/stdout Separation

Problem gelöst durch:

-   Keine Command-Substitution für interaktive Eingaben
-   Direkte Variablenzuweisung
-   Alle Ausgaben gehen an stdout (außer wenn explizit anders)

## Entfernte Komplexität

### Gelöscht (nicht mehr benötigt):

-   `read_domain_input()` Funktion (43 Zeilen)
-   `read_port_input()` Funktion (30 Zeilen)
-   `read_username_input()` Funktion (34 Zeilen)
-   `select_memory_limit()` externe Aufruf-Logik

### Insgesamt:

-   **~100+ Zeilen Code entfernt**
-   **Keine verschachtelten Funktionsaufrufe mehr**
-   **Keine stderr-Probleme mehr möglich**

## Upgrade-Anleitung

```bash
cd ~/hostkit
git pull origin main
sudo ./install.sh
```

Das Update ist abwärtskompatibel - alle bestehenden Websites bleiben unverändert.

## Vorteile

✅ **Einfacher zu verstehen** - Direkter, linearer Code  
✅ **Weniger fehleranfällig** - Keine Command-Substitution-Probleme  
✅ **Bessere UX** - Sofortiges Feedback bei Eingaben  
✅ **Leichter wartbar** - Weniger Code, weniger Komplexität  
✅ **Konsistenter** - Alle Eingaben folgen gleichem Muster  
✅ **Robuster** - Automatische Normalisierung verhindert Fehler

## Testing

Getestet auf:

-   Ubuntu 22.04 LTS
-   Debian 12
-   Debian 13 (Trixie)

Alle Eingabeszenarien:

-   ✓ Leere Eingaben (Standardwerte)
-   ✓ Ungültige Eingaben (Fehlerbehandlung)
-   ✓ Sonderzeichen (Normalisierung)
-   ✓ Großbuchstaben (Konvertierung)
-   ✓ Leerzeichen (Entfernung)
-   ✓ Existierende Werte (Konfliktprüfung)
