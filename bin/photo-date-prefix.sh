#!/bin/bash
# shellcheck disable=SC2034
# shellcheck disable=SC2154
# shellcheck disable=SC2086

usage() {
    cat <<EOF
    Usage: $0 -s <source_path> -t <target_path> [-c <config_file>]
    "Options:"
        -s, --source   Source path to search for files
        -t, --target   Target path to copy or rename files
        -c, --config   Path to config file (default: ../config/config.cnf)
        -h, --help     Show this help message
EOF
}

CONFIG_FILE=""
# Robust pre-parse for -c/--config without shifting global $@
PRE_ARGS=("$@")
idx=0
while [ $idx -lt ${#PRE_ARGS[@]} ]; do
    arg="${PRE_ARGS[$idx]}"
    case "$arg" in
        -c|--config)
            idx=$((idx+1))
            CONFIG_FILE="${PRE_ARGS[$idx]}"
            ;;
    esac
    idx=$((idx+1))
done

# Set default config file if not provided
if [ -z "$CONFIG_FILE" ]; then
    CONFIG_FILE="$(dirname "$0")/../config/config.cnf"
fi
CONF_PHYSICAL=$(readlink -f "$CONFIG_FILE")

if [ -f "$CONF_PHYSICAL" ]; then
    # shellcheck disable=SC1090
    source "$CONF_PHYSICAL"

# Print Environment Variables
    echo
    echo "---------------     Environment     ---------------"
    # print directory of the script
    script_dir=$(cd "$(dirname "$0")" && pwd)
    # print out the script directory
    printf "%s\t %s\n" "Script dir:" "$script_dir"

    # print basename of the script
    script_name=$(basename "$0")
    # print out the script name
    printf "%s\t %s\n" "Script name:" "$script_name"

    # print out the current working directory
    printf "%s\t %s\n" "Current dir:" "$(pwd)"

    # print out the current shell
    printf "%s\t\t %s\n" "Shell:" "$SHELL"
    echo

    # Configuration Variables
    echo "---------------       Config        ---------------"
    echo
    # print out the config file
    printf "%s\t %s\n" "Config file:" "$CONF_PHYSICAL"

    # print the exiftool path
    #echo "ExifTool: $EXIF_TOOL"
    printf "%s\t %s\n" "Exif Path:" "$EXIF_TOOL_PATH"

    # print the exiftool version
    printf "%s\t %s\n" "Exif Version:" "${EXIFTOOL_VERSION_MAJOR}.${EXIFTOOL_VERSION_MINOR}"

    # print the regex pattern
    printf "%s\t %s\n" "Regex Pattern:" "$REGEX_PATTERN"
    echo
else
    # abort if config file not exists
    echo "Config file not found... Abort!"
    exit 1
fi


# Check if exiftool is installed
if [ -z "$EXIF_TOOL" ]; then
    echo "ExifTool is not installed. Please install it first."
    exit 1
fi
# Check if exiftool version is 12.00 or higher
if [ "$EXIFTOOL_VERSION_MAJOR" -lt 12 ]; then
    echo "ExifTool version 12.00 or higher is required. Please update it."
    exit 1
fi

cp_ctr=0
rn_ctr=0
old_names=()
new_names=()

function copyfile () {
    echo "Copy File: $file --> $target_path/$target_filename"
    cp -p "$file" "$target_path"/"$target_filename"
    cp_ctr=$((cp_ctr+1))
    old_names+=("$origin_basename")
    new_names+=("$target_filename")
}

function rename () {
    echo "Rename File: $file --> $target_path/$target_filename"
    mv "$file" "$target_path"/"$target_filename"
    rn_ctr=$((rn_ctr+1))
    old_names+=("$origin_basename")
    new_names+=("$target_filename")
}


###############################################
# Support both short and long options portably #
###############################################


# Convert long options to short options (including config)
args=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --source)
            args+=("-s")
            shift
            args+=("$1")
            ;;
        --target)
            args+=("-t")
            shift
            args+=("$1")
            ;;
        --config)
            args+=("-c")
            shift
            args+=("$1")
            ;;
        --help)
            args+=("-h")
            ;;
        -c)
            args+=("-c")
            shift
            args+=("$1")
            ;;
        *)
            args+=("$1")
            ;;
    esac
    shift
done


# Parse the command line arguments using getopts
source_path=""
target_path=""
while getopts "s:t:c:h" opt "${args[@]}"; do
    case $opt in
        s)
            source_path="$OPTARG"
            ;;
        t)
            target_path="$OPTARG"
            ;;
        c)
            CONFIG_FILE="$OPTARG"
            ;;
        h)
            usage
            exit 0
            ;;
        ?)
            usage
            exit 1
            ;;
    esac
done

# Re-evaluate CONF_PHYSICAL if -c/--config was provided after initial parse
CONF_PHYSICAL=$(readlink -f "$CONFIG_FILE")
if [ -f "$CONF_PHYSICAL" ]; then
    # shellcheck disable=SC1090
    source "$CONF_PHYSICAL"
else
    echo "Config file not found... Abort!"
    exit 1
fi

# check source path and abort if not exists
if [ -z "$source_path" ]; then
    echo -e "No Source Path given... Abort!\n"
    usage
    exit 1
elif [ ! -d "$source_path" ]; then
    printf "%s\t %s\n" "Source Path:" "$source_path"
    echo -e "Source Path does not exist... Abort!\n"
    exit 1
fi

# check target path and asign source path if not exists
if [ -z "$target_path" ]; then
    target_path="$source_path"
else
    if [ ! -d "$target_path" ]; then
        decission=""

        echo "Target Path does not exist..."
        echo -n "Do you want to create \"$target_path\"? [y]es / (n)o "
        read -r decission
        decission=${decission:-y}

        case $decission in
            [yY] )
                mkdir -p "$target_path"
                ;;
            [nN] )
                echo "User aborted..."
                exit 0
                ;;
            * )
                echo "Wrong input. Abort..."
                exit 1
                ;;
        esac
    fi
fi

# print out the given parameters
echo

echo "---------------   Given Parameter   ---------------"
echo

echo "Source Path: $source_path"

echo "Target Path: $target_path"
echo
echo "-----------------------------------------------"

decission=""
echo -n "Do you want to continue? [y] / (n) "
read -r decission
decission=${decission:-y}

case $decission in
    [yY] )
        echo
        echo "Start processing files..."
        echo
        ;;
    [nN] )
        exit 0
        ;;
    * )
        exit 1
        ;;
esac

loop_ctr=0
overwrite_all=false
rename_all=false
OIFS=$IFS;
IFS=$'\n'

# Convert BRE quantifiers (\{4\}) to ERE ({4}) so existing config patterns keep working.
regex_pattern_ere=$(printf '%s' "$REGEX_PATTERN" | sed -E 's/\\\{([0-9]+)\\\}/{\1}/g')
#echo "regex_pattern_ere: '$regex_pattern_ere'"

# Detect OS Type and assign specific command to variable.
case $OSTYPE in
    'darwin'*)
        echo "OS detected: macOS"
        echo
        comand_find=$(find "$source_path" -maxdepth 1 -type f \( ! -name '.*' \) | grep -E "$regex_pattern_ere" | sort)
        ;;
    'linux'*)
        echo "OS detected: linux"
        echo
        comand_find=$(find "$source_path" -maxdepth 1 -type f \( ! -name '.*' \) | grep -E "$regex_pattern_ere" | sort)
        ;;
    *)
        echo -e Abort... No OS detected.
        exit 1
        ;;
esac

# loop through the source directory and search for files
for file in $comand_find; do
    origin_basename=$(basename -- "$file")
    #echo -e Basename: "$origin_basename"

    origin_filename="${origin_basename%%.*}"
    #echo -e Filenme: "$origin_filename"

    origin_extension="${file##*.}"
    #echo -e Extension: "$origin_extension"

    date_time_prefix=$("$EXIF_TOOL" -d "%Y-%m-%dT%H-%M-%S" -T -DateTimeOriginal "$file")
    #echo -e Date Prefix: "$date_time_prefix"

    # check if date_time_prefix is empty
    if [ -z "$date_time_prefix" ]; then
        echo "No DateTimeOriginal found in file: $file"
        echo "Skip file..."
        echo
        continue
    else
        target_filename="$date_time_prefix"-"$origin_filename"."$origin_extension"
        #echo -e Target Filename: "$target_filename"
    fi

    # compare source and target path
    # in case of different directories copy the orignal file to the target with new filename.
    if [ "$source_path" != "$target_path" ]; then
        # check if target file already exists
        if [ ! -f "$target_path"/"$target_filename" ] || [ "$overwrite_all" = "true" ]; then
        copyfile
    else
        decission=""
        echo -n "Target File \"$target_filename\" already exists at destination! Do you want to overwrite it? [a]ll / (y)es / (n)o / (e)xit "
        read -r decission
        decission=${decission:-a}

        case $decission in
            [aA] )
                echo
                echo "Your selection: Replace All, do not ask again."
                echo
                copyfile
                overwrite_all=true
                ;;
            [yY] )
                copyfile
                echo
                ;;
            [nN] )
                echo "Skip file..."
                echo
                continue
                ;;
            [eE] )
                echo "Exit - user aborted!"
                exit 1
                ;;
            * )
        esac
    fi
    # in case of equal directory definition (move the file to) just rename it with new filename.
    else
        if [ "$rename_all" != "true" ]; then
            echo "Source and Target is the same."
            echo -n "Do you want to rename existing files? (a)ll / (y) / [n] "
            read -r decission
            decission=${decission:-n}

            case $decission in
              [aA] )
                rename_all=true
                rename
                ;;
              [yY] )
                echo
                                echo "Start processing files..."
                                echo
                rename
                ;;
              [nN] ) continue;;
              * )
                exit 1
                ;;
            esac
        else
            rename
        fi
    fi
    loop_ctr=$((loop_ctr+1))
done
IFS=$OIFS

total_ctr=$((cp_ctr+rn_ctr))

if [ "$total_ctr" != 0 ]; then
    echo
    printf "%-40s\n" "---------------------------------------------------"
    printf "%-40s %10d\n" "Total amount of processed files:" "$total_ctr"
    printf "%-40s %10d\n" "Copied files:" "$cp_ctr"
    printf "%-40s %10d\n" "Renamed files:" "$rn_ctr"
    printf "%-40s\n" "---------------------------------------------------"
    echo
else
    echo "No file has been processed."
fi


if [ "$total_ctr" != 0 ]; then
    decission=""
    echo -n "Do you want to show old/new filename comparison? (y)es / [n]o "
    read -r decission
    decission=${decission:-n}

    case $decission in
        [yY] )
            echo
            printf "%-50s | %-50s\n" "Old filename" "New filename"
            printf "%-50s-+-%-50s\n" "--------------------------------------------------" "--------------------------------------------------"

            for i in "${!old_names[@]}"; do
                printf "%-50s | %-50s\n" "${old_names[$i]}" "${new_names[$i]}"
            done

            echo
            ;;
        [nN] )
            echo
            exit 0
            ;;
        * )
            echo "Wrong input. Skip..."
            exit 1
            ;;
    esac
fi

exit 0