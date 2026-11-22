#!/bin/bash
# ==============================================================================
# Script Name : fleet_health_audit.sh
# Description : Audits CPU Load, Free RAM, Disk Usage & Active NICs across fleet
# Author      : Kithsara 
# ==============================================================================

set -euo pipefail

# Resolve script directory so paths work from any execution location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY_FILE="${SCRIPT_DIR}/../inventory/hosts.txt"
REPORT_FILE="${SCRIPT_DIR}/../fleet_health_report.log"
REMOTE_USER="devops"

# Thresholds for Health Alerts
MIN_FREE_RAM_MB=200
MAX_DISK_USAGE_PCT=80

log_message() {
    local message="$1"
    echo "$message" | tee -a "$REPORT_FILE"
}

check_prerequisites() {
    if [ ! -f "$INVENTORY_FILE" ]; then
        echo "[ERROR] Inventory file not found at: $INVENTORY_FILE" >&2
        exit 1
    fi
}

audit_node() {
    local host="$1"

    # Verify SSH reachability before running metrics collection
    if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "${REMOTE_USER}@${host}" "true" &>/dev/null; then
        log_message "[UNREACHABLE] Host: $host - Unable to connect via SSH."
        log_message "------------------------------------------------------------"
        return
    fi

    # Collect system metrics via SSH & Command Substitution
    local os_name
    os_name=$(ssh -n "${REMOTE_USER}@${host}" "grep '^PRETTY_NAME=' /etc/os-release | cut -d'\"' -f2")

    local load_avg
    load_avg=$(ssh -n "${REMOTE_USER}@${host}" "uptime | awk -F'load average:' '{print \$2}' | awk -F',' '{print \$1}' | xargs")

    local free_ram
    free_ram=$(ssh -n "${REMOTE_USER}@${host}" "free -m | awk '/^Mem:/ {print \$4}'")

    local disk_pct
    disk_pct=$(ssh -n "${REMOTE_USER}@${host}" "df -h / | awk 'NR==2 {print \$5}' | tr -d '%'")

    local active_nics
    active_nics=$(ssh -n "${REMOTE_USER}@${host}" "ip addr show | grep -v LOOPBACK | grep -ic mtu")

    # Determine Health Status using if / elif / else thresholds
    local health_status="HEALTHY"
    if [ "$disk_pct" -ge "$MAX_DISK_USAGE_PCT" ]; then
        health_status="CRITICAL (High Disk Usage: ${disk_pct}%)"
    elif [ "$free_ram" -le "$MIN_FREE_RAM_MB" ]; then
        health_status="WARNING (Low Free RAM: ${free_ram}MB)"
    fi

    # Print formatted audit entry
    log_message "Host        : $host ($os_name)"
    log_message "Status      : [$health_status]"
    log_message "CPU Load    : $load_avg (1-min avg)"
    log_message "Free RAM    : ${free_ram} MB"
    log_message "Root Disk   : ${disk_pct}% used"
    log_message "Active NICs : $active_nics"
    log_message "------------------------------------------------------------"
}

main() {
    check_prerequisites

    # Initialize fresh report with timestamp
    : > "$REPORT_FILE"
    log_message "============================================================"
    log_message " FLEET HEALTH & COMPLIANCE AUDIT REPORT"
    log_message " Timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    log_message "============================================================"

    # Load hosts into a Bash Array (ignoring comments and empty lines)
    local hosts=()
    mapfile -t hosts < <(grep -vE '^\s*#|^\s*$' "$INVENTORY_FILE")

    for host in "${hosts[@]}"; do
        audit_node "$host"
    done

    log_message "Audit completed. Report saved to: $REPORT_FILE"
}

main
