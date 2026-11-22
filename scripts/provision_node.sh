#!/bin/bash
# ==============================================================================
# Script Name : provision_node.sh
# Description : Multi-OS (CentOS/RHEL & Ubuntu) Web Server Provisioning Script
# ==============================================================================

set -euo pipefail

URL='https://www.tooplate.com/zip-templates/2098_health.zip'
ART_NAME='2098_health'
TEMPDIR="/tmp/webfiles"

log_step() {
    echo "========================================"
    echo "$1"
    echo "========================================"
}

setup_centos() {
    local packages="httpd wget unzip"
    local svc="httpd"

    log_step "Detected CentOS/RHEL: Installing $packages"
    sudo yum install -y $packages > /dev/null

    sudo systemctl start "$svc"
    sudo systemctl enable "$svc"
    deploy_artifact "$svc"
}

setup_ubuntu() {
    local packages="apache2 wget unzip"
    local svc="apache2"

    log_step "Detected Ubuntu/Debian: Installing $packages"
    sudo apt-get update -y > /dev/null
    sudo apt-get install -y $packages > /dev/null

    sudo systemctl start "$svc"
    sudo systemctl enable "$svc"
    deploy_artifact "$svc"
}

deploy_artifact() {
    local svc="$1"

    log_step "Deploying Web Artifact to /var/www/html"
    mkdir -p "$TEMPDIR"
    cd "$TEMPDIR" || exit 1

    wget -q "$URL"
    unzip -qo "${ART_NAME}.zip"
    sudo cp -r "${ART_NAME}/"* /var/www/html/

    sudo systemctl restart "$svc"
    rm -rf "$TEMPDIR"
    log_step "Deployment Successful on $(hostname)"
}

main() {
    if command -v yum &>/dev/null; then
        setup_centos
    elif command -v apt-get &>/dev/null; then
        setup_ubuntu
    else
        echo "[ERROR] Unsupported Linux distribution." >&2
        exit 1
    fi
}

main
