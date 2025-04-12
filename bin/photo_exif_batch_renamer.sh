#!/bin/bash

# Color variables
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
magenta='\033[0;35m'
cyan='\033[0;36m'
black='\033[1;30m'
# Clear the color after that
clear='\033[0m'

# Color variables Background
bg_red='\033[0;41m'
bg_green='\033[0;42m'
bg_yellow='\033[0;43m'
bg_blue='\033[0;44m'
bg_magenta='\033[0;45m'
bg_cyan='\033[0;46m'

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

# check if exiftool is available and abort if not installed
if ! command -v exiftool &> /dev/null; then
    echo -e "exiftool could not be found"
    exit 1
fi

# asign arguments to variables
console=`echo -e "$0"`
source_path=$(echo -e "$1" | sed -e 's#/$##')
target_path=$(echo -e "$2" | sed -e 's#/$##')


# check source path and abort if not exists
if [ -z "$source_path" ]; then
  echo -e No Source Path given... Abort!
  exit 1
else if [ ! -d "$source_path" ]; then
    echo -e Source Path does not exist... Abort!
    exit 1
  fi
fi

# check target path and asign source path if not exists
if [ -z "$target_path" ]; then
    target_path="$source_path"
else
  if [ ! -d "$target_path" ]; then
    decission=""
    echo -e ${bg_red}Target Path does not exists...${clear}
    echo -e -n "Do you want to create ${magenta}\""$target_path"\"${clear}? ${green}[y]es${clear} / ${yellow}(n)o${clear} "
    read -r decission
    decission=${decission:-y}

    case $decission in
      [yY] ) mkdir -p "$target_path";; 
      [nN] ) echo -e "User aborted..."; exit 0;;
      * ) echo -e "Wrong input. Abort..."; exit 1;;
    esac
  fi
fi

# print out the given parameters
echo -e
echo -e ${cyan}---------------   Given Parameter   ---------------${clear}
echo -e
echo -e ${bg_yellow}${black}Source Path:${clear} ${yellow}"$source_path"${clear}
echo -e ${bg_green}${black}Target Path:${clear} ${green}"$target_path"${clear}
echo -e
echo -e '\033[0;36m'-----------------------------------------------'\033[0m'

decission=""
echo -e -n "Do you want to continue? ${green}[y]${clear} / ${yellow}(n)${clear} "
read -r decission
decission=${decission:-y}

case $decission in
  [yY] ) echo -e; echo -e ${green}Start processing files...${clear}; echo -e;;
  [nN] ) exit 0;;
  * ) exit 1
esac

loop_ctr=0
overwrite_all=false
rename_all=false
OIFS=$IFS;
IFS=$'\n'

# Set REGEX-PATTERN to be relaced
REGEX_PATTERN='.*\/RDLG[0-9]\{4\}\.[cC][rR][23]$'

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
esac

# loop through the source directory and search for raw files with the pattern RDLGxxxx.CR3
for file in $comand_find; do
  origin_basename=$(basename -- "$file")
  #echo -e Basename: "$origin_basename"

  origin_filename="${origin_basename%%.*}"
  #echo -e Filenme: "$origin_filename"

  origin_extension="${file##*.}"
  #echo -e Extension: "$origin_extension"

  date_time_prefix=$(exiftool -d "%Y-%m-%dT%H-%M-%S" -T -DateTimeOriginal $file)
  #echo -e Date Prefix: "$date_time_prefix"

  target_filename="$date_time_prefix"-"$origin_filename"."$origin_extension"
  #echo -e Target Filename: "$target_filename"

  # compare source and target path
  # in case of different directories copy the orignal file to the target with new filename.
  if [ "$source_path" != "$target_path" ]; then
    # check if target file already exists
    if [ ! -f "$target_path"/"$target_filename" ] || [ "$overwrite_all" = "true" ]; then
      copyfile
    else
      decission=""
      echo -e -n "Target File ${magenta}\""$target_filename"\"${clear} already exists at destination! \nDo you want to overwrite it? ${cyan}[a]ll${clear} / ${green}(y)es${clear} / ${yellow}(n)o${clear} / ${red}(e)xit${clear} "
      read -r decission  
      decission=${decission:-a}

      case $decission in
        [aA] )
          echo -e
          echo -e "Your selection: Replace All, do not ask again."
          echo -e
          copyfile
          overwrite_all=true ;;
        [yY] )
          copyfile
          echo -e
          ;; 
        [nN] ) echo -e "Skip file...\n"; continue;;
        [eE] ) echo -e "Exit - user aborted!"; exit 1;;
        * )
      esac
    fi
  # in case of equal directory definition (move the file to) just rename it with new filename.
  else
    if [ "$rename_all" != "true" ]; then
    {
      echo -e "${bg_red}Source and Target is the same."${clear}
      echo -e -n "Do you want to rename existing files? ${cyan}(a)ll${clear} / ${green}(y)${clear} / ${yellow}[n]${clear} "
      read -r decission
      decission=${decission:-n}

      case $decission in
        [aA] )
          rename_all=true
          rename
          ;;
        [yY] )
          echo -e
          echo -e ${green}Start processing files...${clear}
          echo -e
          rename
          ;;
        [nN] ) continue;;
        * ) exit 1
      esac
    }
    else
      rename
    fi
  fi
  loop_ctr=$((loop_ctr+1))
done
IFS=$OIFS

total_ctr=$((cp_ctr+rn_ctr))

if [ "$total_ctr" != 0 ]; then
  echo -e
  echo -e "---------------------------------------------"
  echo -e Total amount of processed files:'\t'"$total_ctr"
  echo -e -e Copied files:'\t\t\t\t'"$cp_ctr"
  echo -e -e Renamed files:'\t\t\t\t'"$rn_ctr"
  echo -e "---------------------------------------------"
  echo -e
else
  echo -e No file has beeing processed.
  echo -e
fi


if [ "$total_ctr" != 0 ]; then
  decission=""
  echo -e -n "Do you want to list all files at target? ${green}(y)es${clear} / ${yellow}[n]o${clear} " 
  read -r decission
  decission=${decission:-n}

  case $decission in
    [yY] )
      echo -e
      #find "$target_path" -type f | sort;;
      tree "$target_path";;
    [nN] )
      echo -e ; exit 0;;
    * )
      echo -e "Wrong input. Skip..."; exit 1;;
  esac
fi

exit 0