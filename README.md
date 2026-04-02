# prefix_exif_date

Language: 🇬🇧 English | [🇩🇪 Deutsch](README.de.md)

A Bash script that reads the `DateTimeOriginal` EXIF tag from image (and other media) files and prefixes their filenames with the extracted date and time. It can either **rename files in-place** or **copy them to a separate target directory** with the new name.

---

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Examples](#examples)
  - [Regex Pattern Examples](#regex-pattern-examples)
- [Output](#output)

---

## Features

- Extracts `DateTimeOriginal` from EXIF metadata using [ExifTool](https://exiftool.org/)
- Prefixes filenames with a sortable `YYYY-MM-DDTHH-MM-SS` timestamp
- **Copy mode**: source and target are different directories — original files are preserved
- **Rename mode**: source and target are the same — files are renamed in-place
- Configurable file filter via a regex pattern
- Interactive prompts for overwrite conflicts and batch decisions (*overwrite all*, *rename all*)
- Skips files without a `DateTimeOriginal` EXIF tag
- Supports macOS and Linux
- Requires ExifTool ≥ 12.00

---

## Requirements

| Dependency | Minimum version | Notes |
|------------|----------------|-------|
| `bash`     | 4.x            |       |
| `exiftool` | 12.00          | [ExifTool by Phil Harvey](https://exiftool.org/) |
| `find`, `grep`, `sed` | — | Standard POSIX utilities |

Install ExifTool on macOS with Homebrew:

```bash
brew install exiftool
```

Install ExifTool on Debian/Ubuntu:

```bash
sudo apt install libimage-exiftool-perl
```

---

## Installation

1. Clone or download this repository.
2. Copy the configuration template and fill in your settings:

   ```bash
   cp config/config.cnf.template config/config.cnf
   ```

3. Edit `config/config.cnf` and set at least the `REGEX_PATTERN` variable (see [Configuration](#configuration)).
4. Make the script executable:

   ```bash
   chmod +x bin/prefix_exif_date.sh
   ```

---

## Configuration

The script reads `config/config.cnf` (relative to the script location). The file is sourced as a Bash script. Use `config/config.cnf.template` as your starting point.

### Key Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `REGEX_PATTERN` | Extended regex applied to file paths to select which files are processed. Supports both BRE (`\{4\}`) and ERE (`{4}`) quantifier syntax. | `\.(jpg\|jpeg\|JPG)$` |
| `EXIF_TOOL` | Path to the `exiftool` binary. Auto-detected via `which exiftool`. | `/usr/local/bin/exiftool` |
| `EXIFTOOL_VERSION_MAJOR` / `_MINOR` | Parsed from `exiftool -ver`. Used for the version guard. | `12`, `76` |

### Color Variables

The config file also exports terminal color codes used for the script's output formatting (`red`, `green`, `yellow`, `cyan`, `black`, `clear`, `bg_red`, `bg_green`, `bg_yellow`, …). These are already pre-configured in the template and do not need to be changed.

### Example `config.cnf`

```bash
# Color variables (copy as-is from template)
red='\033[0;31m'; export red
# ... (remaining color vars) ...

# Match only JPEG files
REGEX_PATTERN='\.(jpg|jpeg|JPG|JPEG)$'
export REGEX_PATTERN

# ExifTool (auto-detected)
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

## Usage

```
Usage: prefix_exif_date.sh -s <source_path> -t <target_path>

Options:
  -s, --source   Source directory to search for files
  -t, --target   Target directory to copy or rename files into
  -h, --help     Show this help message
```

### Behaviors

| Scenario | Result |
|----------|--------|
| `-t` not specified | `target_path` defaults to `source_path` (rename mode) |
| `-s` == `-t` | Files are **renamed in-place** |
| `-s` ≠ `-t` | Original files are **copied** to target with the new prefixed name |
| Target directory does not exist | Script prompts whether to create it |
| File has no `DateTimeOriginal` tag | File is **skipped** with a warning |
| Conflict: target file already exists | Interactive prompt: **A**ll / **Y**es / **N**o / **E**xit |

The new filename format is:

```
YYYY-MM-DDTHH-MM-SS-<original_filename>.<extension>
```

---

## Examples

### Copy files from one directory to another

```bash
./bin/prefix_exif_date.sh -s /Volumes/SD-Card/DCIM -t ~/Pictures/Imported
```

Files in `/Volumes/SD-Card/DCIM` that match `REGEX_PATTERN` will be **copied** to `~/Pictures/Imported` with a timestamp prefix.

**Before:**
```
IMG_1234.jpg
IMG_1235.jpg
```

**After (in target):**
```
2024-06-15T14-32-10-IMG_1234.jpg
2024-06-15T14-35-47-IMG_1235.jpg
```

---

### Rename files in-place

```bash
./bin/prefix_exif_date.sh -s ~/Pictures/Vacation
# or explicitly:
./bin/prefix_exif_date.sh -s ~/Pictures/Vacation -t ~/Pictures/Vacation
```

---

### Long option syntax

```bash
./bin/prefix_exif_date.sh --source /media/camera --target /home/user/sorted
```

---

## Regex Pattern Examples

The `REGEX_PATTERN` variable is evaluated as an **extended regular expression** (ERE) and matched against the **full file path** output of `find`. It is case-sensitive.

The script automatically converts BRE quantifier syntax (`\{4\}`) to ERE (`{4}`), so both notations work.

---

### Match common JPEG files

```bash
REGEX_PATTERN='\.(jpg|jpeg)$'
```

Matches files ending in `.jpg` or `.jpeg` (lowercase only).

---

### Match JPEG files — case-insensitive style

```bash
REGEX_PATTERN='\.[jJ][pP][eE]?[gG]$'
```

Matches `.jpg`, `.jpeg`, `.JPG`, `.JPEG`, `.Jpg`, `.Jpeg`, etc.

---

### Match multiple image formats

```bash
REGEX_PATTERN='\.(jpg|jpeg|png|tiff|tif|heic|heif|JPG|JPEG|PNG|TIFF|TIF|HEIC|HEIF)$'
```

---

### Match RAW camera formats

```bash
REGEX_PATTERN='\.(cr2|cr3|nef|arw|raf|dng|CR2|CR3|NEF|ARW|RAF|DNG)$'
```

---

### Match files from Canon cameras (by filename prefix)

Canon cameras typically produce files like `IMG_1234.JPG` or `_MG_1234.JPG`.

```bash
REGEX_PATTERN='_?IMG_[0-9]{4}\.(jpg|JPG|cr2|CR2)$'
```

---

### Match files with a 4-digit sequence number

```bash
REGEX_PATTERN='[0-9]{4}\.(jpg|jpeg)$'
```

Or using the BRE syntax that is also accepted:

```bash
REGEX_PATTERN='[0-9]\{4\}\.(jpg|jpeg)$'
```

---

### Match any file (use with caution)

```bash
REGEX_PATTERN='.*'
```

All non-hidden files in the source directory will be processed. Files without EXIF `DateTimeOriginal` data will be skipped automatically.

---

### Match video files

```bash
REGEX_PATTERN='\.(mp4|mov|avi|MP4|MOV|AVI)$'
```

ExifTool can read EXIF/XMP metadata from many video formats as well.

---

## Output

The script prints a summary at the end:

```
----------------------------------------
Total amount of processed files:        12
Copied files:                            12
Renamed files:                            0
----------------------------------------
```

Optionally, it can display a directory tree of the target path using `tree`.

---

## License

This project is licensed. See the [LICENSE](LICENSE) file in the repository for details.
