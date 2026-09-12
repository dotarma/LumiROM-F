#!/bin/bash

source scripts/utils/bash_colors.sh
# shellcheck disable=SC1091
source scripts/utils/devices.sh

UPDATE_ZIP_SCRIPT() {
    
        local EXTRACTED_FIRM_DIR="$1"
        BUILD_PROP_PATH="$EXTRACTED_FIRM_DIR/system/system/build.prop"
        FINGERPRINT=$(grep -m 1 "ro.system.build.fingerprint=" "$BUILD_PROP_PATH" | cut -d'=' -f2)
        BUILD_DATE=$(date +'%d%m%Y')
        DEVICE="$STOCK_DEVICE"
        UPDATER_PATH="$(pwd)/makerom/META-INF/com/google/android/updater-script"
        local oneui_prop_ver=$(grep -m 1 "ro.build.version.oneui=" "$BUILD_PROP_PATH" | cut -d'=' -f2)
        local cut_version="${oneui_prop_ver:0:3}"
        ONEUI_VERSION="${cut_version/0/.}"

        DEVICE_CODENAME=$(DEVICE_CODENAME "$DEVICE")
        DISPLAY_NAME=$(DEVICE_DISPLAY_NAME "$DEVICE")

        if [ -z "$FINGERPRINT" ]; then
            echo "${YELLOW}Warning: Fingerprint not found, using generic value.${RESET}"
            FINGERPRINT="Unknown/Release-Keys"
        fi

        echo "${GREEN}Detected Fingerprint:${RESET} $FINGERPRINT"
        sed -i "s!ui_print(\"Source: .*\");!ui_print(\"Source: $FINGERPRINT\");!" "$UPDATER_PATH"
        
        NEW_CHECK="getprop(\"ro.boot.em.model\") == \"$DEVICE\" || abort(\"E3004: This package is for $DEVICE_CODENAME\");"

        echo "${GREEN}Updating device on updater-script for${RESET} $DISPLAY_NAME..."
      
        sed -i "s!^getprop(\"ro.boot.em.model\").*!$NEW_CHECK!" "$UPDATER_PATH"

        sed -i "s!ui_print(\".*for .*\");!ui_print(\"   $LUMIROM_VERSION-$BUILD_DATE $BUILD_STATUS for $DISPLAY_NAME\");!" "$UPDATER_PATH"

        echo "${GREEN}Updating One UI version to${RESET} $ONEUI_VERSION ${GREEN}on updater-script...${RESET}"

        sed -i "s!ui_print(\"One UI version: .*\");!ui_print(\"One UI version: $ONEUI_VERSION\");!" "$UPDATER_PATH"

}

FLASHABLE_ZIP_CREATION() {
    
        BUILD_DATE=$(date +'%d%m%Y')
        TIMESTAMP=$(date +'%s')
        DEVICE="$STOCK_DEVICE"
        local cut_version_stock="${STOCK_DEVICE:3:3}"
        local cut_version_target="${TARGET_DEVICE:3:3}"
        FOLDER_NAME="${BUILD_DATE}-${TIMESTAMP}-${cut_version_stock}_to_${cut_version_target}/"
        MAKEROM_DIR="$(pwd)/makerom"
        export FOLDER_NAME

        if [ -n "$GITHUB_ENV" ]; then
            echo "FOLDER_NAME=$FOLDER_NAME" >> "$GITHUB_ENV"
        fi

        DEVICE_CODENAME=$(DEVICE_CODENAME "$DEVICE")

        echo "Generating build_info.txt..."
        {
            echo "device=$DEVICE_CODENAME"
            echo "version=$LUMIROM_VERSION-$BUILD_DATE"
            echo "timestamp=$TIMESTAMP"
            echo "status=$BUILD_STATUS"
        } > "$MAKEROM_DIR/build_info.txt"
        {
            printf '{\n  "device": "%s",\n  "device_model": "%s",\n  "version": "%s",\n  "build_date": "%s",\n  "timestamp": %s,\n  "status": "%s"\n}\n' \
                "$DEVICE_CODENAME" "$DEVICE" "$LUMIROM_VERSION" "$BUILD_DATE" "$TIMESTAMP" "$BUILD_STATUS"
        } > "$MAKEROM_DIR/build_info.json"

        SPECIFIC_BOOT="$(pwd)/LumiROM/Devices/$DEVICE/boot.img"

        if [ -f "$SPECIFIC_BOOT" ]; then
            echo "${GREEN}-> Copying boot.img from${RESET} $DEVICE..."
            cp "$SPECIFIC_BOOT" "$MAKEROM_DIR/boot.img"
        else
            echo "${RED}There is no boot.img for${RESET} $DEVICE"
        fi

        echo "${GREEN}Moving compressed DAT files to ROM Folder...${RESET}"
        mv TMP/*.new.dat.br "$MAKEROM_DIR"/
        mv TMP/*.patch.dat "$MAKEROM_DIR"/
        mv TMP/*.transfer.list "$MAKEROM_DIR"/ 2>/dev/null || true

        echo "${GREEN}Creating ZIP package...${RESET}"
        ZIP_FILE="LumiROM_${LUMIROM_VERSION}-${BUILD_DATE}_${BUILD_STATUS}_${DEVICE_CODENAME}.zip"
        [ -f "$ZIP_FILE" ] && rm "$ZIP_FILE"

        cd "$MAKEROM_DIR"

        # ZIP the rom with mixed compression levels (Multithreaded 7z)
        echo "${YELLOW}Adding large/compressed files (Store)...${RESET}"
        7z a -mx=0 -mmt=4 "$ZIP_FILE" ./*.new.dat.br ./*.patch.dat 2>/dev/null || true
        
        echo "${YELLOW}Adding scripts and compressible data (Compress)...${RESET}"
        7z a -mx=6 -mmt=4 "$ZIP_FILE" ./boot.img ./META-INF ./build_info.txt ./build_info.json ./dynamic_partitions_op_list ./*.transfer.list 2>/dev/null || true
        

        mkdir -p "../ROM/${FOLDER_NAME}"
        mv "$ZIP_FILE" "../ROM/${FOLDER_NAME}"

        echo "${GREEN}ZIP package created: $ZIP_FILE${RESET}"

        cd ..
        rm -rf "$MAKEROM_DIR"
}

ZIP_IMG() {
    if [ "$#" -ne 2 ]; then
        echo "Usage: ${FUNCNAME[0]} <IMG_DIR> <OUT_ZIP>"
        return 1
    fi

    local IMG_DIR="$1"
    local OUT_ZIP="$2"

    echo "${BLUE}=== Creating ZIP from IMG files ===${RESET}"

    if ! ls "$IMG_DIR"/*.img >/dev/null 2>&1; then
        echo "${RED}Error: No .img files found in $IMG_DIR${RESET}"
        return 1
    fi

    mkdir -p "$(dirname "$OUT_ZIP")"

    if zip -0 -j "$OUT_ZIP" "$IMG_DIR"/*.img; then
        echo "${GREEN}ZIP created successfully: $OUT_ZIP${RESET}"
    else
        echo "${RED}Error: Failed to create ZIP file${RESET}"
        return 1
    fi
}

IMG_ZIP_CREATION() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <OUT_DIR>"
        return 1
    fi

    local OUT_DIR="$1"

    BUILD_DATE=$(date +'%d%m%Y')
    TIMESTAMP=$(date +'%s')
    DEVICE="$STOCK_DEVICE"
    local cut_version_stock="${STOCK_DEVICE:3:3}"
    local cut_version_target="${TARGET_DEVICE:3:3}"
    FOLDER_NAME="${BUILD_DATE}-${TIMESTAMP}-${cut_version_stock}_to_${cut_version_target}/"
    export FOLDER_NAME

    if [ -n "$GITHUB_ENV" ]; then
        echo "FOLDER_NAME=$FOLDER_NAME" >> "$GITHUB_ENV"
    fi

    DEVICE_CODENAME=$(DEVICE_CODENAME "$DEVICE")

    local ZIP_FILE="LumiROM_${LUMIROM_VERSION}-${BUILD_DATE}_${BUILD_STATUS}_${DEVICE_CODENAME}_IMG.zip"

    ZIP_IMG "$OUT_DIR" "$(pwd)/ROM/${FOLDER_NAME}${ZIP_FILE}"
}