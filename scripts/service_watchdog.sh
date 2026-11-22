#!/bin/bash
# ==============================================================================
# Script Name : service_watchdog.sh
# Description : Self-healing service monitor & Cron auto-recovery daemon
# ==============================================================================

set -euo pipefail

SERVICE_NAME="${1:-httpd}"
LOG_FILE="/var/log/watchdog.log"

log_event() {
    local level="$1"
    local msg="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $msg" | tee -a "$LOG_FILE"
}

check_and_heal() {
    local svc="$1"

    if systemctl is-active --quiet "$svc"; then
        log_event "OK" "Service '$svc' is running normally."
    else
        log_event "ALERT" "Service '$svc' is DOWN! Attempting auto-recovery..."
        if systemctl start "$svc"; then
            log_event "RECOVERED" "Service '$svc' restarted successfully."
        else
            log_event "CRITICAL" "Failed to start '$svc'! Manual intervention required."
            exit 1
        fi
    fi
}

main() {
    check_and_heal "$SERVICE_NAME"
}

main
