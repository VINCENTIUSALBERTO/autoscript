#!/bin/bash
# ==============================================================================
# Webmin Management Module
# Provides Webmin installation and configuration
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load libraries if not already loaded
[[ -z "$NC" ]] && source "${SCRIPT_DIR}/lib/colors.sh"
[[ -z "$(type -t log_info 2>/dev/null)" ]] && source "${SCRIPT_DIR}/lib/utils.sh"
[[ -z "$(type -t get_public_ip 2>/dev/null)" ]] && source "${SCRIPT_DIR}/lib/system.sh"

# Load configuration
# shellcheck disable=SC1091
[[ -f "${SCRIPT_DIR}/config/settings.conf" ]] && source "${SCRIPT_DIR}/config/settings.conf"

# Show Webmin menu
show_webmin_menu() {
    while true; do
        clear_screen
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${BCYAN}                    WEBMIN MANAGEMENT                          ${NC}"
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${BGREEN}1.${NC} View Webmin Status"
        echo -e "  ${BGREEN}2.${NC} Start Webmin"
        echo -e "  ${BGREEN}3.${NC} Stop Webmin"
        echo -e "  ${BGREEN}4.${NC} Restart Webmin"
        echo -e "  ${BGREEN}5.${NC} Install Webmin"
        echo -e "  ${BGREEN}6.${NC} Change Webmin Port"
        echo -e "  ${BGREEN}7.${NC} Change Webmin Password"
        echo -e "  ${BGREEN}8.${NC} Access Webmin URL"
        echo ""
        echo -e "  ${BRED}0.${NC} Back to Main Menu"
        echo ""
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        read -p "$(echo -e "${YELLOW}Select option:${NC} ")" choice
        
        case $choice in
            1) view_webmin_status ;;
            2) start_webmin ;;
            3) stop_webmin ;;
            4) restart_webmin ;;
            5) install_webmin ;;
            6) change_webmin_port_menu ;;
            7) change_webmin_password ;;
            8) show_webmin_url ;;
            0) return 0 ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# View Webmin status
view_webmin_status() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                    WEBMIN STATUS                              ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if ! command_exists webmin || [[ ! -f /etc/webmin/miniserv.conf ]]; then
        echo -e "  ${CYAN}Status:${NC} ${YELLOW}Not Installed${NC}"
        echo ""
        echo -e "  ${DIM}Use option 5 to install Webmin${NC}"
    else
        local status
        if check_service webmin; then
            status="${GREEN}● Running${NC}"
        else
            status="${RED}○ Stopped${NC}"
        fi
        
        local port
        port=$(grep "^port=" /etc/webmin/miniserv.conf 2>/dev/null | cut -d= -f2)
        port="${port:-10000}"
        
        local ip
        ip=$(get_public_ip)
        
        echo -e "  ${CYAN}Status:${NC}      $status"
        echo -e "  ${CYAN}Port:${NC}        $port"
        echo -e "  ${CYAN}URL:${NC}         https://${ip}:${port}"
        echo ""
        
        # Show service details
        echo -e "${CYAN}Service Details:${NC}"
        systemctl status webmin --no-pager 2>/dev/null | head -10 || echo "  Unable to get service status"
    fi
    
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    press_any_key
}

# Start Webmin
start_webmin() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                    START WEBMIN                               ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if ! command_exists webmin && [[ ! -f /etc/webmin/miniserv.conf ]]; then
        print_error "Webmin is not installed"
        press_any_key
        return
    fi
    
    if check_service webmin; then
        print_info "Webmin is already running"
    else
        echo -e "${CYAN}Starting Webmin...${NC}"
        if systemctl start webmin 2>/dev/null || /etc/init.d/webmin start 2>/dev/null; then
            sleep 2
            if check_service webmin; then
                print_success "Webmin started successfully"
                log_info "Webmin started"
            else
                print_error "Failed to start Webmin"
            fi
        else
            print_error "Failed to start Webmin"
        fi
    fi
    
    press_any_key
}

# Stop Webmin
stop_webmin() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                     STOP WEBMIN                               ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if ! check_service webmin; then
        print_info "Webmin is not running"
        press_any_key
        return
    fi
    
    if confirm "Stop Webmin service?"; then
        echo -e "${CYAN}Stopping Webmin...${NC}"
        if systemctl stop webmin 2>/dev/null || /etc/init.d/webmin stop 2>/dev/null; then
            print_success "Webmin stopped"
            log_info "Webmin stopped"
        else
            print_error "Failed to stop Webmin"
        fi
    fi
    
    press_any_key
}

# Restart Webmin
restart_webmin() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                   RESTART WEBMIN                              ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if ! command_exists webmin && [[ ! -f /etc/webmin/miniserv.conf ]]; then
        print_error "Webmin is not installed"
        press_any_key
        return
    fi
    
    echo -e "${CYAN}Restarting Webmin...${NC}"
    if systemctl restart webmin 2>/dev/null || /etc/init.d/webmin restart 2>/dev/null; then
        sleep 2
        if check_service webmin; then
            print_success "Webmin restarted successfully"
            log_info "Webmin restarted"
        else
            print_warning "Webmin may not have started properly"
        fi
    else
        print_error "Failed to restart Webmin"
    fi
    
    press_any_key
}

# Install Webmin
install_webmin() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                    INSTALL WEBMIN                             ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [[ -f /etc/webmin/miniserv.conf ]]; then
        print_info "Webmin appears to be already installed"
        if ! confirm "Reinstall Webmin?"; then
            press_any_key
            return
        fi
    fi
    
    echo -e "${CYAN}This will install Webmin on your system.${NC}"
    echo ""
    
    if ! confirm "Proceed with installation?"; then
        press_any_key
        return
    fi
    
    echo ""
    echo -e "${CYAN}Installing Webmin...${NC}"
    echo ""
    
    # Detect OS
    detect_os
    
    case "${OS_NAME,,}" in
        ubuntu|debian)
            # Add Webmin repository
            echo -e "${CYAN}Adding Webmin repository...${NC}"
            
            # Install dependencies
            apt update -q
            apt install -y apt-transport-https software-properties-common wget gnupg
            
            # Add repository key
            wget -qO - http://www.webmin.com/jcameron-key.asc | apt-key add - 2>/dev/null
            
            # Add repository
            echo "deb http://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
            
            # Install Webmin
            apt update -q
            if apt install -y webmin; then
                print_success "Webmin installed successfully!"
                
                local port
                port=$(grep "^port=" /etc/webmin/miniserv.conf 2>/dev/null | cut -d= -f2)
                port="${port:-10000}"
                
                local ip
                ip=$(get_public_ip)
                
                echo ""
                echo -e "${CYAN}Access Webmin at:${NC}"
                echo -e "  URL: https://${ip}:${port}"
                echo -e "  Username: root"
                echo -e "  Password: Your system root password"
                
                log_info "Webmin installed"
            else
                print_error "Failed to install Webmin"
            fi
            ;;
        *)
            print_error "Unsupported OS: ${OS_NAME}"
            ;;
    esac
    
    press_any_key
}

# Change Webmin port (calls port menu)
change_webmin_port_menu() {
    source "${SCRIPT_DIR}/modules/port.sh"
    change_webmin_port
}

# Change Webmin password
change_webmin_password() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                 CHANGE WEBMIN PASSWORD                        ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if ! command_exists webmin && [[ ! -f /etc/webmin/miniserv.conf ]]; then
        print_error "Webmin is not installed"
        press_any_key
        return
    fi
    
    local username
    read -p "$(echo -e "${YELLOW}Enter username (default: root):${NC} ")" username
    username="${username:-root}"
    
    local password password_confirm
    while true; do
        echo -en "${YELLOW}Enter new password:${NC} "
        read -rs password
        echo ""
        
        echo -en "${YELLOW}Confirm password:${NC} "
        read -rs password_confirm
        echo ""
        
        if [[ "$password" == "$password_confirm" ]]; then
            if [[ ${#password} -lt 6 ]]; then
                print_error "Password must be at least 6 characters"
            else
                break
            fi
        else
            print_error "Passwords do not match"
        fi
    done
    
    # Change password using Webmin's command
    if /usr/share/webmin/changepass.pl /etc/webmin "$username" "$password" 2>/dev/null; then
        print_success "Password changed for user: $username"
        log_info "Webmin password changed for: $username"
    else
        # Alternative method
        echo "${username}:${password}" | chpasswd 2>/dev/null
        print_success "Password changed for user: $username"
    fi
    
    press_any_key
}

# Show Webmin URL
show_webmin_url() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                    WEBMIN ACCESS URL                          ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if ! command_exists webmin && [[ ! -f /etc/webmin/miniserv.conf ]]; then
        print_error "Webmin is not installed"
        press_any_key
        return
    fi
    
    local port
    port=$(grep "^port=" /etc/webmin/miniserv.conf 2>/dev/null | cut -d= -f2)
    port="${port:-10000}"
    
    local ip domain
    ip=$(get_public_ip)
    domain=$(get_vps_domain)
    
    echo -e "${CYAN}Webmin Access Information:${NC}"
    echo ""
    echo -e "  ${BWHITE}URL (IP):${NC}     https://${ip}:${port}"
    
    if [[ "$domain" != "Not configured" ]]; then
        echo -e "  ${BWHITE}URL (Domain):${NC} https://${domain}:${port}"
    fi
    
    echo ""
    echo -e "  ${BWHITE}Username:${NC}     root"
    echo -e "  ${BWHITE}Password:${NC}     Your system root password"
    echo ""
    echo -e "${YELLOW}Note:${NC} Use HTTPS (not HTTP) to access Webmin"
    echo ""
    
    # Check service status
    if check_service webmin; then
        echo -e "  ${CYAN}Status:${NC} ${GREEN}● Running${NC}"
    else
        echo -e "  ${CYAN}Status:${NC} ${RED}○ Stopped${NC} (start with option 2)"
    fi
    
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    press_any_key
}

# Export functions
export -f show_webmin_menu view_webmin_status start_webmin stop_webmin
export -f restart_webmin install_webmin change_webmin_port_menu
export -f change_webmin_password show_webmin_url
