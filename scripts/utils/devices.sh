#!/bin/bash
# Central device catalogue (P1: single source of truth).
# FW.sh / zip_creation.sh / workflows must use helpers below instead of
# duplicating if-else chains.

# STOCK -> BASE firmware to port from
GET_BASE_DEVICE_CENTRAL() {
    case "$1" in
        SM-A325F|SM-A325M|SM-M325F) echo "SM-A346B" ;;
        SM-A225F|SM-A225M|SM-E225F|SM-M225F|SM-A226B) echo "SM-A245F" ;;
        *) return 1 ;;
    esac
}

# STOCK -> short codename used in zip names
DEVICE_CODENAME() {
    case "$1" in
        SM-A325F) echo "a32" ;;
        SM-A325M) echo "a32m" ;;
        SM-A225F|SM-A225M) echo "a22" ;;
        SM-A226B) echo "a22x" ;;
        SM-M325F|SM-M225F) echo "m32" ;;
        SM-E225F) echo "f22" ;;
        *) echo "unknown" ;;
    esac
}

# STOCK -> human display name for updater-script
DEVICE_DISPLAY_NAME() {
    case "$1" in
        SM-A325F|SM-A325M) echo "Galaxy A32 4G" ;;
        SM-A225F|SM-A225M) echo "Galaxy A22 4G" ;;
        SM-A226B) echo "Galaxy A22 5G" ;;
        SM-M325F) echo "Galaxy M32 4G" ;;
        SM-E225F) echo "Galaxy F22 4G" ;;
        *) echo "Unknown Device" ;;
    esac
}
