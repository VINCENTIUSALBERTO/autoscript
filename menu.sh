#!/bin/bash
# ==============================================================================
# VPS Autoscript Management System
# Main Menu Entry Point
# 
# Version: 1.0.0
# Author: VPS Autoscript
# License: MIT
#
# Description:
#   Production-ready VPS management script with modular architecture.
#   Supports Ubuntu and Debian systems with V2Ray VMess/VLESS management,
#   backup/restore, Telegram integration, and system monitoring.
#
# Architecture:
#   menu.sh          - Main entry point and menu system
#   lib/colors.sh    - Color definitions for terminal output
#   lib/utils.sh     - Common utility functions (logging, validation, input)
#   lib/system.sh    - System detection and information functions
#   config/          - Configuration files
#   modules/         - Feature modules (vmess, vless, backup, etc.)
#
# Usage:
#   sudo ./menu.sh
#   sudo bash menu.sh
#
# ==============================================================================

set -e

# Script directory resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR

# Load libraries
source "${SCRIPT_DIR}/lib/colors.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/system.sh"

# Load configuration
# shellcheck disable=SC1091
[[ -f "${SCRIPT_DIR}/config/settings.conf" ]] && source "${SCRIPT_DIR}/config/settings.conf"

# Load modules
source "${SCRIPT_DIR}/modules/vmess.sh"
source "${SCRIPT_DIR}/modules/vless.sh"
source "${SCRIPT_DIR}/modules/telegram.sh"
source "${SCRIPT_DIR}/modules/backup.sh"
source "${SCRIPT_DIR}/modules/domain.sh"
source "${SCRIPT_DIR}/modules/port.sh"
source "${SCRIPT_DIR}/modules/dns.sh"
source "${SCRIPT_DIR}/modules/certificate.sh"
source "${SCRIPT_DIR}/modules/webmin.sh"
source "${SCRIPT_DIR}/modules/services.sh"

# Initialize script
init_script() {
    # Check root privileges
    check_root
    
    # Check OS compatibility
    if ! is_supported_os; then
        detect_os
        print_error "Unsupported OS: ${OS_NAME}"
        print_info "This script supports Ubuntu and Debian only."
        exit 1
    fi
    
    # Ensure directories exist
    mkdir -p "${ACCOUNTS_DIR}/vmess" 2>/dev/null || true
    mkdir -p "${ACCOUNTS_DIR}/vless" 2>/dev/null || true
    mkdir -p "${BACKUP_DIR:-/root/backup}" 2>/dev/null || true
    
    # Ensure log directory exists
    ensure_log_dir
    
    log_info "VPS Autoscript started"
}

# Show main menu
show_main_menu() {
    while true; do
        clear
        
        # Display header with VPS info
        display_vps_header
        
        echo ""
        echo -e "${BCYAN}                         MAIN MENU                             ${NC}"
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${BWHITE}V2RAY MANAGEMENT${NC}"
        echo -e "  ${BGREEN}1.${NC}  V2Ray VMess Menu"
        echo -e "  ${BGREEN}2.${NC}  V2Ray VLESS Menu"
        echo ""
        echo -e "  ${BWHITE}SYSTEM MANAGEMENT${NC}"
        echo -e "  ${BGREEN}3.${NC}  Telegram Owner"
        echo -e "  ${BGREEN}4.${NC}  Backup System"
        echo -e "  ${BGREEN}5.${NC}  Add / Change Domain"
        echo -e "  ${BGREEN}6.${NC}  Change Port Service"
        echo -e "  ${BGREEN}7.${NC}  Change DNS Server"
        echo -e "  ${BGREEN}8.${NC}  Renew V2Ray Certificate"
        echo -e "  ${BGREEN}9.${NC}  Webmin Menu"
        echo ""
        echo -e "  ${BWHITE}MONITORING & TOOLS${NC}"
        echo -e "  ${BGREEN}10.${NC} Check RAM Usage"
        echo -e "  ${BGREEN}11.${NC} Reboot VPS"
        echo -e "  ${BGREEN}12.${NC} Speedtest VPS"
        echo -e "  ${BGREEN}13.${NC} Display System Information"
        echo -e "  ${BGREEN}14.${NC} Info Script"
        echo -e "  ${BGREEN}15.${NC} Check Service Error"
        echo ""
        echo -e "  ${BRED}0.${NC}  Exit Menu"
        echo ""
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        read -p "$(echo -e "${YELLOW}Select option:${NC} ")" choice
        
        case $choice in
            1) show_vmess_menu ;;
            2) show_vless_menu ;;
            3) show_telegram_menu ;;
            4) show_backup_menu ;;
            5) show_domain_menu ;;
            6) show_port_menu ;;
            7) show_dns_menu ;;
            8) show_certificate_menu ;;
            9) show_webmin_menu ;;
            10) menu_ram_usage ;;
            11) menu_reboot_vps ;;
            12) menu_speedtest ;;
            13) menu_system_info ;;
            14) menu_script_info ;;
            15) show_services_menu ;;
            0) exit_menu ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# Menu: RAM Usage
menu_ram_usage() {
    clear_screen
    display_ram_usage
    press_any_key
}

# Menu: Reboot VPS
menu_reboot_vps() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BRED}                       REBOOT VPS                              ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}⚠️  WARNING: This will reboot your VPS immediately!${NC}"
    echo ""
    echo -e "${CYAN}Current uptime:${NC} $(get_uptime)"
    echo ""
    
    if confirm "Are you SURE you want to reboot the VPS?"; then
        echo ""
        print_info "Rebooting VPS in 5 seconds..."
        log_info "VPS reboot initiated by user"
        
        for i in 5 4 3 2 1; do
            echo -en "\r${YELLOW}Rebooting in $i...${NC}  "
            sleep 1
        done
        
        echo ""
        reboot
    else
        print_info "Reboot cancelled"
        press_any_key
    fi
}

# Menu: Speedtest
menu_speedtest() {
    run_speedtest
}

# Menu: System Information
menu_system_info() {
    clear_screen
    display_system_info
    press_any_key
}

# Menu: Script Info
menu_script_info() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                      SCRIPT INFORMATION                       ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${CYAN}Name:${NC}        VPS Autoscript Management System"
    echo -e "  ${CYAN}Version:${NC}     ${SCRIPT_VERSION:-1.0.0}"
    echo -e "  ${CYAN}Author:${NC}      ${SCRIPT_AUTHOR:-VPS Autoscript}"
    echo ""
    echo -e "${BWHITE}───────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "  ${CYAN}Script Directory:${NC}   $SCRIPT_DIR"
    echo -e "  ${CYAN}Config Directory:${NC}   ${SCRIPT_DIR}/config"
    echo -e "  ${CYAN}Modules Directory:${NC}  ${SCRIPT_DIR}/modules"
    echo -e "  ${CYAN}Log File:${NC}           ${LOG_FILE:-/var/log/autoscript.log}"
    echo ""
    echo -e "${BWHITE}───────────────────────────────────────────────────────────────${NC}"
    echo -e "${BCYAN}                         FEATURES                              ${NC}"
    echo -e "${BWHITE}───────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "  ${GREEN}✓${NC} V2Ray VMess Account Management"
    echo -e "  ${GREEN}✓${NC} V2Ray VLESS Account Management"
    echo -e "  ${GREEN}✓${NC} Telegram Integration & Notifications"
    echo -e "  ${GREEN}✓${NC} Backup & Restore System"
    echo -e "  ${GREEN}✓${NC} Domain Management & SSL Certificates"
    echo -e "  ${GREEN}✓${NC} Port Configuration"
    echo -e "  ${GREEN}✓${NC} DNS Server Management"
    echo -e "  ${GREEN}✓${NC} Webmin Integration"
    echo -e "  ${GREEN}✓${NC} System Monitoring & Diagnostics"
    echo -e "  ${GREEN}✓${NC} Service Error Checking"
    echo ""
    echo -e "${BWHITE}───────────────────────────────────────────────────────────────${NC}"
    echo -e "${BCYAN}                    SUPPORTED SYSTEMS                          ${NC}"
    echo -e "${BWHITE}───────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "  ${GREEN}✓${NC} Ubuntu 18.04, 20.04, 22.04, 24.04"
    echo -e "  ${GREEN}✓${NC} Debian 10, 11, 12"
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    press_any_key
}

# Exit menu
exit_menu() {
    clear
    echo ""
    echo -e "${BCYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BCYAN}║${NC}                                                                ${BCYAN}║${NC}"
    echo -e "${BCYAN}║${NC}        ${BWHITE}Thank you for using VPS Autoscript!${NC}                    ${BCYAN}║${NC}"
    echo -e "${BCYAN}║${NC}                                                                ${BCYAN}║${NC}"
    echo -e "${BCYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_info "VPS Autoscript session ended"
    exit 0
}

# Signal handlers
trap 'log_info "Script interrupted"; exit 1' INT TERM

# Main execution
main() {
    init_script
    show_main_menu
}

# Run main function
main "$@"
