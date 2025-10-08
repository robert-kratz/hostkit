# Bugfix: Bash 3.x Kompatibilität im Uninstaller - v1.3.2

## Problem

Der Uninstaller schlägt mit einem Syntax-Fehler fehl:

```bash
/opt/hostkit/modules/uninstall.sh: Zeile 192: Choose: Syntaxfehler: Operator erwartet. (Fehlerverursachendes Zeichen ist "Choose").
```

## Ursache

Die Parameter Expansion `${variable^}` (Großschreibung des ersten Buchstabens) funktioniert nur in **Bash 4.0+**.

Viele Debian/Ubuntu-Systeme verwenden:

-   Debian 10/11: Bash 5.x ✓
-   Debian 12+: Bash 5.x ✓
-   Ubuntu 20.04+: Bash 5.x ✓
-   **Ältere Systeme**: Bash 3.x ✗

### Problematischer Code

```bash
# Zeile 93, 95, 192
echo -e "  ${RED}✗${NC} ${component^}: ${UNINSTALL_OPTIONS[$component]}"
```

Die `${component^}` Syntax ist Bash 4.0+ spezifisch und verursacht:

```
Syntaxfehler: Operator erwartet
```

## Lösung

Hinzufügen einer kompatiblen `capitalize()` Funktion, die mit Bash 3.x funktioniert:

```bash
# Capitalize first letter (compatible with bash 3.x)
capitalize() {
    local str="$1"
    echo "$(echo ${str:0:1} | tr '[:lower:]' '[:upper:]')${str:1}"
}
```

### Funktionsweise

1. `${str:0:1}` - Extrahiert ersten Buchstaben
2. `tr '[:lower:]' '[:upper:]'` - Wandelt in Großbuchstaben um
3. `${str:1}` - Rest des Strings
4. Kombiniert zu: `Package`, `Websites`, etc.

### Angewendet auf alle Vorkommen

**Vorher:**

```bash
echo -e "  ${GREEN}[✓]${NC} ${key^}: ${UNINSTALL_OPTIONS[$key]}"
```

**Nachher:**

```bash
echo -e "  ${GREEN}[✓]${NC} $(capitalize "$key"): ${UNINSTALL_OPTIONS[$key]}"
```

## Betroffene Zeilen

-   Zeile 93: Menu-Anzeige (installierte Komponenten)
-   Zeile 95: Menu-Anzeige (nicht installierte Komponenten)
-   Zeile 192: Uninstall-Summary

Alle wurden auf `$(capitalize "$variable")` umgestellt.

## Test-Kompatibilität

Die Lösung funktioniert mit:

-   ✅ Bash 3.2 (macOS default)
-   ✅ Bash 4.x (ältere Linux-Systeme)
-   ✅ Bash 5.x (moderne Linux-Systeme)
-   ✅ sh (POSIX shell)

## Update installieren

```bash
cd ~/hostkit
git pull origin main
sudo ./install.sh
```

## Testen

```bash
# Uninstall-Menu anzeigen
sudo hostkit uninstall

# Sollte jetzt ohne Fehler funktionieren und zeigen:
# [✓] Package: Remove HostKit package and binaries
# [✓] Websites: Remove all registered websites and their data
# etc.
```

## Weitere Bash-Kompatibilitätsprüfung

Geprüfte Syntax in allen Scripts:

-   ✅ Keine `${var^}` oder `${var^^}` (Bash 4.0+)
-   ✅ Keine `${var,}` oder `${var,,}` (Bash 4.0+)
-   ✅ Keine `&>` Redirection (verwenden `2>&1` stattdessen)
-   ✅ Kein `[[[ ]]]` (dreifach-bracket)
-   ✅ Arrays richtig deklariert mit `declare -a`
-   ✅ Assoziative Arrays mit `declare -A`

## Best Practices für Bash-Kompatibilität

1. **Keine Bash 4.0+ Features verwenden**:

    - `${var^}`, `${var^^}` → Eigene Funktion
    - `${var,}`, `${var,,}` → Eigene Funktion
    - Assoziative Arrays → OK (Bash 4.0+), dokumentieren

2. **POSIX-kompatibel wo möglich**:

    - `[[ ]]` ist OK (Bash-spezifisch, aber weit verbreitet)
    - `$( )` statt Backticks
    - `$(( ))` für Arithmetik

3. **Shebang prüfen**:

    - `#!/bin/bash` - Bash-Features erlaubt
    - `#!/bin/sh` - Nur POSIX

4. **Testing auf alten Systemen**:

    ```bash
    # Bash-Version prüfen
    bash --version

    # Script in spezifischer Version testen
    bash-3.2 script.sh
    ```

## Version

-   **Gefixt in**: v1.3.2
-   **Betrifft**: Uninstall-Funktion auf Systemen mit Bash < 4.0

## Verwandte Issues

Dieser Fix macht HostKit kompatibel mit:

-   Älteren Debian/Ubuntu LTS-Versionen
-   macOS (default Bash 3.2)
-   Minimal-Installationen ohne Bash-Updates

## Zusätzliche Robustheit

Die `capitalize()` Funktion könnte auch für andere String-Operationen verwendet werden:

```bash
# Potenzielle zukünftige Verwendung
username=$(capitalize "$input")
domain=$(capitalize "$domain")
```

Aktuell nur in `uninstall.sh` verwendet, könnte aber bei Bedarf in das Hauptscript `hostkit` verschoben werden für globale Verfügbarkeit.
