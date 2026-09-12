#!/bin/bash

set -euo pipefail

DESTINY="${1:?Usage: $0 <huggingface|gofile>}"

GOFILE_UPLOAD() {
    FILE="$1"

    if [[ -z "$FILE" || ! -f "$FILE" ]]; then
        echo "ERROR: File hasn't been found."
        exit 1
    fi

    local servers_json SERVER LINK
    servers_json=$(curl -fsSL --retry 3 --retry-delay 2 https://api.gofile.io/servers) || {
        echo "ERROR: Failed to query GoFile servers."
        exit 1
    }
    SERVER=$(echo "$servers_json" | jq -r '.data.servers[0].name')

    if [[ -z "$SERVER" || "$SERVER" == "null" ]]; then
        echo "ERROR: No GoFile server available."
        exit 1
    fi
    LINK=$(curl -fsSL --retry 3 -F "file=@$FILE" "https://${SERVER}.gofile.io/uploadFile" | jq -r '.data.downloadPage') || {
        echo "ERROR: GoFile upload failed."
        exit 1
    }

    if [[ -z "$LINK" || "$LINK" == "null" ]]; then
        echo "ERROR: GoFile returned no download link."
        exit 1
    fi
    echo -e "\nDownload link for the uploaded file:"
    echo "$LINK"
    echo
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        echo "GoFile: [$LINK]($LINK)" >> "$GITHUB_STEP_SUMMARY"
    fi
}

if [[ -z "${FOLDER_NAME:-}" ]]; then
    echo "ERROR: FOLDER_NAME is not set (did zip_creation run?)."
    exit 1
fi
ZIP_PATH=$(find ./ROM/"$FOLDER_NAME" -type f -name "*.zip" | head -n 1)

if [[ -z "${ZIP_PATH:-}" || ! -f "$ZIP_PATH" ]]; then
    echo "ERROR: No ROM zip found under ./ROM/$FOLDER_NAME"
    exit 1
fi
echo "SHA256: $(sha256sum "$ZIP_PATH")"

case "$DESTINY" in
    huggingface)
        echo "Uploading ROM to Hugging Face"
        REMOTE_PATH="ROMs/$LUMIROM_VERSION/$STOCK_DEVICE/$(basename "$ZIP_PATH")"
        python3 "$(dirname "$0")/upload_hf.py" "$ZIP_PATH" "$REMOTE_PATH"
        ;;

    gofile)
        echo "Uploading ROM to GoFile"
        GOFILE_UPLOAD "$ZIP_PATH"
        ;;

    *)
        echo "Error: Pick 'huggingface' or 'gofile'."
        exit 1
        ;;
esac