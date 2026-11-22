#!/bin/bash
# ==============================================================================
# Script Name : deploy_fleet.sh
# Description : Pushes and executes Multi-OS setup across remote Linux fleet
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY_FILE="${SCRIPT_DIR}/../inventory/hosts.txt"
TARGET_SCRIPT="${SCRIPT_DIR}/provision_node.sh"
REMOTE_USER="devops"

check_files() {
    if [ ! -f "$INVENTORY_FILE" ]; then
        echo "[ERROR] Inventory file missing: $INVENTORY_FILE" >&2
        exit 1
    fi
    if [ ! -f "$TARGET_SCRIPT" ]; then
        echo "[ERROR] Target script missing: $TARGET_SCRIPT" >&2
        exit 1
    fi
}

deploy_to_host() {
    local host="$1"
    echo "------------------------------------------------------------"
    echo "[INFO] Deploying to $host..."
    scp -q "$TARGET_SCRIPT" "${REMOTE_USER}@${host}:/tmp/provision_node.sh"
    ssh -n "${REMOTE_USER}@${host}" "chmod +x /tmp/provision_node.sh && sudo /tmp/provision_node.sh && rm -f /tmp/provision_node.sh"
    echo "[SUCCESS] Completed provisioning on $host"
}

main() {
    check_files

    local hosts=()
    mapfile -t hosts < <(grep -vE '^\s*#|^\s*$' "$INVENTORY_FILE")

    for host in "${hosts[@]}"; do
        deploy_to_host "$host"
    done

    echo "------------------------------------------------------------"
    echo "[DONE] All ${#hosts[@]} nodes provisioned successfully."
}

main
