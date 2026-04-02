# prefix_exif_date

Sprache: 🇩🇪 Deutsch | [🇬🇧 English](README.md)

Ein Bash-Skript, das den `DateTimeOriginal`-EXIF-Tag aus Bild- (und anderen Medien-)Dateien ausliest und den Dateinamen mit dem extrahierten Datum und der Uhrzeit als Präfix versieht. Es kann Dateien wahlweise **direkt umbenennen** oder **in ein separates Zielverzeichnis kopieren** – jeweils mit dem neuen Dateinamen.

---

## Inhaltsverzeichnis

- [Funktionen](#funktionen)
- [Voraussetzungen](#voraussetzungen)
- [Installation](#installation)
- [Konfiguration](#konfiguration)
- [Verwendung](#verwendung)
- [Beispiele](#beispiele)
  - [Regex-Muster Beispiele](#regex-muster-beispiele)
- [Ausgabe](#ausgabe)

---

## Funktionen

- Liest `DateTimeOriginal` aus den EXIF-Metadaten mithilfe von [ExifTool](https://exiftool.org/)
- Stellt Dateinamen ein sortierbares Zeitstempel-Präfix im Format `YYYY-MM-DDTHH-MM-SS` voran
- **Kopiermodus**: Quell- und Zielverzeichnis sind verschieden — Originaldateien bleiben erhalten
- **Umbenennungsmodus**: Quelle und Ziel sind identisch — Dateien werden direkt umbenannt
- Konfigurierbarer Dateifilter über ein reguläres Ausdrucksmuster (Regex)
- Interaktive Abfragen bei Konflikten (Datei bereits vorhanden) mit Stapelentscheidungen (*Alle überschreiben*, *Alle umbenennen*)
- Dateien ohne `DateTimeOriginal`-EXIF-Tag werden übersprungen
- Unterstützt macOS und Linux
- Erfordert ExifTool ≥ 12.00

---

## Voraussetzungen

| Abhängigkeit | Mindestversion | Hinweis |
|-------------|---------------|---------|
| `bash`      | 4.x           |         |
| `exiftool`  | 12.00         | [ExifTool von Phil Harvey](https://exiftool.org/) |
| `find`, `grep`, `sed` | — | Standard-POSIX-Werkzeuge |

ExifTool unter macOS mit Homebrew installieren:

```bash
brew install exiftool
```

ExifTool unter Debian/Ubuntu installieren:

```bash
sudo apt install libimage-exiftool-perl
```

---

## Installation

1. Dieses Repository klonen oder herunterladen.
2. Die Konfigurationsvorlage kopieren und anpassen:

   ```bash
   cp config/config.cnf.template config/config.cnf
   ```

3. `config/config.cnf` bearbeiten und mindestens die Variable `REGEX_PATTERN` setzen (siehe [Konfiguration](#konfiguration)).
4. Das Skript ausführbar machen:

   ```bash
   chmod +x bin/prefix_exif_date.sh
   ```

---

## Konfiguration

Das Skript liest `config/config.cnf` (relativ zum Skript-Verzeichnis). Die Datei wird als Bash-Skript eingebunden (*source*). Als Ausgangspunkt dient `config/config.cnf.template`.

### Wichtige Variablen

| Variable | Beschreibung | Beispiel |
|----------|-------------|---------|
| `REGEX_PATTERN` | Erweiterter regulärer Ausdruck (ERE), der auf Dateipfade angewendet wird, um die zu verarbeitenden Dateien auszuwählen. Unterstützt sowohl BRE- (`\{4\}`) als auch ERE-Quantoren (`{4}`). | `\.(jpg\|jpeg\|JPG)$` |
| `EXIF_TOOL` | Pfad zur `exiftool`-Binärdatei. Wird automatisch über `which exiftool` ermittelt. | `/usr/local/bin/exiftool` |
| `EXIFTOOL_VERSION_MAJOR` / `_MINOR` | Wird aus `exiftool -ver` geparst. Dient der Versionsüberprüfung. | `12`, `76` |

### Farbvariablen

Die Konfigurationsdatei exportiert außerdem Terminal-Farbcodes für die formatierte Ausgabe des Skripts (`red`, `green`, `yellow`, `cyan`, `black`, `clear`, `bg_red`, `bg_green`, `bg_yellow`, …). Diese sind in der Vorlage bereits vorkonfiguriert und müssen nicht angepasst werden.

### Beispiel `config.cnf`

```bash
# Farbvariablen (aus der Vorlage übernehmen)
red='\033[0;31m'; export red
# ... (weitere Farbvariablen) ...

# Nur JPEG-Dateien verarbeiten
REGEX_PATTERN='\.(jpg|jpeg|JPG|JPEG)$'
export REGEX_PATTERN

# ExifTool (wird automatisch erkannt)
EXIF_TOOL="$(which exiftool 2>/dev/null)"
export EXIF_TOOL
EXIFTOOL_VERSION=$($EXIF_TOOL -ver 2>/dev/null)
export EXIFTOOL_VERSION
EXIFTOOL_VERSION_MAJOR=$(echo "$EXIFTOOL_VERSION" | cut -d '.' -f 1)
export EXIFTOOL_VERSION_MAJOR
EXIFTOOL_VERSION_MINOR=$(echo "$EXIFTOOL_VERSION" | cut -d '.' -f 2)
export EXIFTOOL_VERSION_MINOR
```

---

## Verwendung

```
Usage: prefix_exif_date.sh -s <source_path> -t <target_path>

Optionen:
  -s, --source   Quellverzeichnis, in dem nach Dateien gesucht wird
  -t, --target   Zielverzeichnis, in das Dateien kopiert oder umbenannt werden
  -h, --help     Diese Hilfe anzeigen
```

### Verhalten

| Szenario | Ergebnis |
|----------|--------|
| `-t` nicht angegeben | `target_path` entspricht `source_path` (Umbenennungsmodus) |
| `-s` == `-t` | Dateien werden **direkt umbenannt** |
| `-s` ≠ `-t` | Originaldateien werden mit neuem Präfix ins Ziel **kopiert** |
| Zielverzeichnis existiert nicht | Skript fragt, ob es erstellt werden soll |
| Datei hat keinen `DateTimeOriginal`-Tag | Datei wird mit Hinweis **übersprungen** |
| Konflikt: Zieldatei existiert bereits | Interaktive Abfrage: **A**lle / **J**a / **N**ein / **B**eenden |

Das neue Dateinamenformat lautet:

```
YYYY-MM-DDTHH-MM-SS-<ursprünglicher_dateiname>.<erweiterung>
```

---

## Beispiele

### Dateien von einem Verzeichnis in ein anderes kopieren

```bash
./bin/prefix_exif_date.sh -s /Volumes/SD-Karte/DCIM -t ~/Bilder/Importiert
```

Dateien in `/Volumes/SD-Karte/DCIM`, die auf `REGEX_PATTERN` passen, werden mit Zeitstempel-Präfix nach `~/Bilder/Importiert` **kopiert**.

**Vorher:**
```
IMG_1234.jpg
IMG_1235.jpg
```

**Nachher (im Zielverzeichnis):**
```
2024-06-15T14-32-10-IMG_1234.jpg
2024-06-15T14-35-47-IMG_1235.jpg
```

---

### Dateien direkt umbenennen

```bash
./bin/prefix_exif_date.sh -s ~/Bilder/Urlaub
# oder explizit:
./bin/prefix_exif_date.sh -s ~/Bilder/Urlaub -t ~/Bilder/Urlaub
```

---

### Lange Optionsschreibweise

```bash
./bin/prefix_exif_date.sh --source /media/kamera --target /home/user/sortiert
```

---

## Regex-Muster Beispiele

Die Variable `REGEX_PATTERN` wird als **erweiterter regulärer Ausdruck** (ERE) ausgewertet und gegen den **vollständigen Dateipfad** der `find`-Ausgabe abgeglichen. Die Suche ist **Groß-/Kleinschreibung-sensitiv**.

Das Skript wandelt BRE-Quantoren-Syntax (`\{4\}`) automatisch in ERE (`{4}`) um, sodass beide Schreibweisen funktionieren.

---

### Nur JPEG-Dateien (Kleinbuchstaben)

```bash
REGEX_PATTERN='\.(jpg|jpeg)$'
```

Erfasst Dateien, die auf `.jpg` oder `.jpeg` enden (nur Kleinbuchstaben).

---

### JPEG-Dateien — Groß-/Kleinschreibung ignorieren

```bash
REGEX_PATTERN='\.[jJ][pP][eE]?[gG]$'
```

Erfasst `.jpg`, `.jpeg`, `.JPG`, `.JPEG`, `.Jpg`, `.Jpeg` usw.

---

### Mehrere Bildformate

```bash
REGEX_PATTERN='\.(jpg|jpeg|png|tiff|tif|heic|heif|JPG|JPEG|PNG|TIFF|TIF|HEIC|HEIF)$'
```

---

### RAW-Kameraformate

```bash
REGEX_PATTERN='\.(cr2|cr3|nef|arw|raf|dng|CR2|CR3|NEF|ARW|RAF|DNG)$'
```

---

### Dateien von Canon-Kameras (anhand des Dateinamen-Präfixes)

Canon-Kameras erzeugen typischerweise Dateien wie `IMG_1234.JPG` oder `_MG_1234.JPG`.

```bash
REGEX_PATTERN='_?IMG_[0-9]{4}\.(jpg|JPG|cr2|CR2)$'
```

---

### Dateien mit vierstelliger Sequenznummer

```bash
REGEX_PATTERN='[0-9]{4}\.(jpg|jpeg)$'
```

Alternativ in BRE-Schreibweise (wird ebenfalls akzeptiert):

```bash
REGEX_PATTERN='[0-9]\{4\}\.(jpg|jpeg)$'
```

---

### Alle Dateien verarbeiten (mit Vorsicht verwenden)

```bash
REGEX_PATTERN='.*'
```

Alle nicht-versteckten Dateien im Quellverzeichnis werden verarbeitet. Dateien ohne EXIF-Tag `DateTimeOriginal` werden automatisch übersprungen.

---

### Videodateien

```bash
REGEX_PATTERN='\.(mp4|mov|avi|MP4|MOV|AVI)$'
```

ExifTool kann EXIF/XMP-Metadaten auch aus vielen Videoformaten auslesen.

---

## Ausgabe

Das Skript gibt am Ende eine Zusammenfassung aus:

```
----------------------------------------
Total amount of processed files:        12
Copied files:                            12
Renamed files:                            0
----------------------------------------
```

Optional kann das Skript einen Verzeichnisbaum des Zielverzeichnisses mit `tree` anzeigen.

---

## Lizenz

Dieses Projekt steht unter einer Lizenz. Siehe die Datei [LICENSE](LICENSE) im Repository für Details.
