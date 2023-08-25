#!/bin/bash
##
# This script searches all files in the directories specified in paths.txt
#
# Usage:
#   ./search.sh word1 word2 ...
#
# shellcheck disable=SC2016

[ "${SCRIPT_DEBUG-}" = "1" ] && set -x

# Current directory of the script.
SCRIPT_DIR="$(
  cd "$(dirname "$0")" || exit
  pwd
)"

# File containing the paths to search in.
ALFRED_SEARCH2CLIP_PATHS_FILE="${ALFRED_SEARCH2CLIP_PATHS_FILE:-$HOME/.search2clip/paths.txt}"

# File extensions to search for.
ALFRED_SEARCH2CLIP_EXTENSIONS="${ALFRED_SEARCH2CLIP_EXTENSIONS:-txt,md}"

# Minimum word length to search for.
ALFRED_SEARCH2CLIP_MIN_WORD_LENGTH="${ALFRED_SEARCH2CLIP_MIN_WORD_LENGTH:-2}"

#-------------------------------------------------------------------------------

# Check if a query is provided
if [[ -z $1 ]]; then
  echo "ERROR: Please provide a search query."
  exit 1
fi

ALFRED_SEARCH2CLIP_PATHS_FILE="${ALFRED_SEARCH2CLIP_PATHS_FILE/#\~/$HOME}"

if [[ ! -f $ALFRED_SEARCH2CLIP_PATHS_FILE ]]; then
  echo "ERROR: Please create a paths.txt. Provided path file is $ALFRED_SEARCH2CLIP_PATHS_FILE."
  exit 1
fi

# Split the search query into words for an AND search
IFS=' ' read -ra words <<<"$@"

# Filter out short words
filtered_words=()
for word in "${words[@]}"; do
  if [[ ${#word} -ge ${ALFRED_SEARCH2CLIP_MIN_WORD_LENGTH:-0} ]]; then
    filtered_words+=("$word")
  fi
done

# Check if any valid words are left
if [[ ${#filtered_words[@]} -eq 0 ]]; then
  echo '{"items": []}'
  exit 0
fi

words=("${filtered_words[@]}")

delim="###DELIMITER###"

all_results=""

# Parse the ALFRED_SEARCH2CLIP_EXTENSIONS variable to create an array of extensions.
IFS=',' read -ra extensions_array <<<"$(echo "$ALFRED_SEARCH2CLIP_EXTENSIONS" | tr -d ' ')"

# STAGE 1: Collect all files from all directories
declare -a collected_files_array
while IFS= read -r dir; do
  if [[ ${dir:0:1} == "#" ]]; then continue; fi

  if [[ ! $dir =~ ^/ ]]; then
    dir="${SCRIPT_DIR}/${dir}"
  fi

  if [[ -d $dir && -r $dir ]]; then
    for ext in "${extensions_array[@]}"; do
      while IFS= read -r -d $'\0' file; do
        collected_files_array+=("$file")
      done < <(find "$dir" -type f -name "*.${ext}" -print0)
    done
  else
    echo "Directory $dir does not exist or is not readable."
  fi
done <"$ALFRED_SEARCH2CLIP_PATHS_FILE"

# STAGE 2: Search for contents within collected files
temp_results_file="/tmp/results_$$.txt"
touch "$temp_results_file"

for file in "${collected_files_array[@]}"; do
  while IFS= read -r line; do
    all_words_found=true
    for word in "${words[@]}"; do
      if ! echo "$line" | grep -qiE "\b${word}"; then
        all_words_found=false
        break
      fi
    done

    if [ "$all_words_found" = true ]; then
      echo "$file$delim$line" >>"${temp_results_file}"
    fi
  done <"$file"
done

all_results+=$(cat $temp_results_file | head -n 10)
rm -f "${temp_results_file}"

# STAGE 3: Output json

escape_json() {
  local input="$1"
  input="${input//\\/\\\\}"
  input="${input//\"/\\\"}"
  input="${input//\//\\/}"

  # Convert actual newlines and carriage returns to their escaped equivalents.
  printf '%s' "$input" | awk '{ gsub(/\n/, "\\n"); gsub(/\r/, "\\r"); print }'
}

json_items=""
IFS=$'\n'
for line in $all_results; do
  title=$(echo "$line" | awk -F"$delim" '{print $2}')
  subtitle=$(echo "$line" | awk -F"$delim" '{print $1}')
  uid=$(echo -n "$subtitle$delim$title" | sha256sum | cut -f1 -d' ' | cut -c 1-32)

  # Escape the values
  title_escaped=$(escape_json "$title")
  subtitle_escaped="$subtitle"
  uid_escaped=$(escape_json "$uid")

  # Append to the JSON items string
  json_items+="$(printf '{"uid": "%s", "title": "%s", "subtitle": "%s", "arg": "%s", "type": "default", "valid": true},' "$uid_escaped" "$title_escaped" "$subtitle_escaped" "$title_escaped")"
done

# Print the final JSON output
printf '{"items": [%s]}' "${json_items%,}"
