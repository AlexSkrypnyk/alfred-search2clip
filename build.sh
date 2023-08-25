#!/bin/bash
##
# Build Alfred workflow using provided info.plist file and embedding script file.
#

set -e
set -u

NAME="${1?Provide the name of the workflow.}"

# The path to the info.plist file. Defaults to info.plist in the current directory.
PLIST_FILE="${2:-info.plist}"

# The directory to store the build files. Defaults to .build in the current directory.
BUILD_DIR="${BUILD_DIR:-.build}"

#------------------------------------------------------------------------------

# Ensure the plist file exists
if [ ! -f "$PLIST_FILE" ]; then
  echo "ERROR: $PLIST_FILE does not exist!"
  exit 1
fi

base_dir=$(dirname "$PLIST_FILE")

# Delete and recreate .build directory
rm -rf "$BUILD_DIR" >/dev/null && mkdir "$BUILD_DIR"

cp "$PLIST_FILE" "${BUILD_DIR}/"

# Find all referenced script files and copy them into .build directory.
while IFS= read -r line; do
  # Extract the value between <string> tags
  value=$(echo "$line" | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p')
  if [[ -n $value && -f "$base_dir/$value" ]]; then
    script_file="$base_dir/$value"
    echo "Copying found script file $script_file into build directory ${BUILD_DIR}."
    cp "$script_file" "${BUILD_DIR}/"
  fi
done < <(grep -A 1 "<key>scriptfile<\/key>" "${PLIST_FILE}")

zip -j -r "${BUILD_DIR}/${NAME}.alfredworkflow" "${BUILD_DIR}"

echo "Processing completed. Check ${BUILD_DIR} directory."
