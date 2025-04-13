#!/bin/bash
# shellcheck disable=SC2034
# shellcheck disable=SC2154
# shellcheck disable=SC2086

usage() {
    cat <<EOF
    Usage: $0 -s <source_path> -t <target_path>
    "Options:"
        -s, --source   Source path to search for files
        -t, --target   Target path to copy or rename files

        -h, --help     Show this help message
EOF
}

# read the config file if exists
CONF="$(dirname "$0")/../config/config.cnf"
CONF_PHYSICAL=$(readlink -f "$CONF")

if [ -f "$CONF_PHYSICAL" ]; then
    # shellcheck disable=SC1090
    source "$CONF_PHYSICAL"

# Print Environment Variables
    echo
    echo -e "${cyan}---------------     Environment     ---------------${clear}"
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
    echo -e "${cyan}---------------       Config        ---------------${clear}"
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
    echo -e "${red}ExifTool is not installed. Please install it first.${clear}"
    exit 1
fi
# Check if exiftool version is 12.00 or higher
if [ "$EXIFTOOL_VERSION_MAJOR" -lt 12 ]; then
    echo -e "${red}ExifTool version 12.00 or higher is required. Please update it.${clear}"
    exit 1
fi

cp_ctr=0
rn_ctr=0

function copyfile () {
    echo -e Copy File: ${bg_yellow}${black}"$file"${clear} --\> ${bg_green}${black}"$target_path"/"$target_filename"${clear}
    cp -p "$file" "$target_path"/"$target_filename"
    cp_ctr=$((cp_ctr+1))
}

function rename () {
    echo -e Rename File: ${bg_yellow}${black}"$file"${clear} --\> ${bg_green}${black}"$target_path"/"$target_filename"${clear}
    mv "$file" "$target_path"/"$target_filename"
    rn_ctr=$((rn_ctr+1))
}

# Parse the command line arguments
filename=$(basename "$0")
PARSED_OPTIONS=$(getopt -n "$filename" -o s:t:h --long source:,target:,help -- "$@")
retcode=$?
if [ $retcode != 0 ]; then
    usage
fi

# Extract the options and their arguments into variables
eval set -- "$PARSED_OPTIONS"

# Handle the options and arguments
while true; do
    case "$1" in
        -s|--source)
            source_path="$2"
            shift 2
            ;;
        -t|--target)
            target_path="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Invalid option: $1"
            usage
            exit 1
            ;;
    esac
done

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
        
        echo -e ${bg_red}Target Path does not exists...${clear}
        echo -e -n "Do you want to create ${magenta}\"""$target_path""\"${clear}? ${green}[y]es${clear} / ${yellow}(n)o${clear} "
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

echo -e "${cyan}---------------   Given Parameter   ---------------${clear}"
echo

echo -e ${bg_yellow}${black}Source Path:${clear} ${yellow}"$source_path"${clear}

echo -e ${bg_green}${black}Target Path:${clear} ${green}"$target_path"${clear}
echo
echo -e ${cyan}-----------------------------------------------${cyan}

decission=""
echo -e -n "Do you want to continue? ${green}[y]${clear} / ${yellow}(n)${clear} "
read -r decission
decission=${decission:-y}

case $decission in
    [yY] )
        echo
        echo -e "${green}Start processing files...${clear}\n"
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

# Detect OS Type and assign specific command to variable.
case $OSTYPE in
    'darwin'*) 
        echo -e ${green}"OS detected: macOS\n"${clear}
        comand_find=$(find "$source_path" -maxdepth 1 -type f \( ! -regex '.*/\..*' \) -regex $REGEX_PATTERN | sort)
        ;;
    'linux'*)
        echo -e ${green}"OS detected: linux\n"${clear}
        comand_find=$(find "$source_path" -type f -regextype "egrep" -regex $REGEX_PATTERN | sort)
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
        echo -e "No DateTimeOriginal found in file: ${bg_red}${black}$file${clear}"
        echo -e "Skip file...\n"
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
        echo -e -n "Target File ${magenta}\"""$target_filename""\"${clear} already exists at destination! \nDo you want to overwrite it? ${cyan}[a]ll${clear} / ${green}(y)es${clear} / ${yellow}(n)o${clear} / ${red}(e)xit${clear} "
        read -r decission  
        decission=${decission:-a}

        case $decission in
            [aA] )
                echo
                echo -e "Your selection: Replace All, do not ask again.\n"
                copyfile
                overwrite_all=true
                ;;
            [yY] )
                copyfile
                echo
                ;; 
            [nN] )
                echo -e "Skip file...\n"
                continue
                ;;
            [eE] )
                echo -e "Exit - user aborted!\n"
                exit 1
                ;;
            * )
        esac
    fi
    # in case of equal directory definition (move the file to) just rename it with new filename.
    else
        if [ "$rename_all" != "true" ]; then
            echo -e "${bg_red}Source and Target is the same.${clear}"
            echo -e -n "Do you want to rename existing files? ${cyan}(a)ll${clear} / ${green}(y)${clear} / ${yellow}[n]${clear} "
            read -r decission
            decission=${decission:-n}

            case $decission in
              [aA] )
                rename_all=true
                rename
                ;;
              [yY] )
                echo
                echo -e "${green}Start processing files...${clear}\n"
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
    echo -e "No file has beeing processed.\n"
fi


if [ "$total_ctr" != 0 ]; then
    decission=""
    echo -e -n "Do you want to list all files at target? ${green}(y)es${clear} / ${yellow}[n]o${clear} " 
    read -r decission
    decission=${decission:-n}

    case $decission in
        [yY] )
            echo
            #find "$target_path" -type f | sort;;
            tree "$target_path"
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