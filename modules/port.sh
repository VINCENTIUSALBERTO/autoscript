#!/bin/bash
# ==============================================================================
# Port Management Module
# Provides service port configuration and management
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load libraries if not already loaded
[[ -z "$NC" ]] && source "${SCRIPT_DIR}/lib/colors.sh"
[[ -z "$(type -t log_info 2>/dev/null)" ]] && source "${SCRIPT_DIR}/lib/utils.sh"
[[ -z "$(type -t get_public_ip 2>/dev/null)" ]] && source "${SCRIPT_DIR}/lib/system.sh"

# Load configuration
# shellcheck disable=SC1091
[[ -f "${SCRIPT_DIR}/config/settings.conf" ]] && source "${SCRIPT_DIR}/config/settings.conf"
[[ -f "${SCRIPT_DIR}/config/ports.conf" ]] && source "${SCRIPT_DIR}/config/ports.conf"

# Show port menu
show_port_menu() {
    while true; do
        clear_screen
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${BCYAN}                  PORT MANAGEMENT MENU                         ${NC}"
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${BGREEN}1.${NC} View Current Ports"
        echo -e "  ${BGREEN}2.${NC} Change VMess Port"
        echo -e "  ${BGREEN}3.${NC} Change VLESS Port"
        echo -e "  ${BGREEN}4.${NC} Change SSH Port"
        echo -e "  ${BGREEN}5.${NC} Change Webmin Port"
        echo -e "  ${BGREEN}6.${NC} Check Port Status"
        echo ""
        echo -e "  ${BRED}0.${NC} Back to Main Menu"
        echo ""
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        read -p "$(echo -e "${YELLOW}Select option:${NC} ")" choice
        
        case $choice in
            1) view_current_ports ;;
            2) change_vmess_port ;;
            3) change_vless_port ;;
            4) change_ssh_port ;;
            5) change_webmin_port ;;
            6) check_port_status ;;
            0) return 0 ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# View current ports
view_current_ports() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                    CURRENT PORT SETTINGS                      ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    printf "  ${CYAN}%-25s %-10s %-15s${NC}\n" "SERVICE" "PORT" "STATUS"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    
    # VMess
    local vmess_port="${V2RAY_PORT_VMESS:-443}"
    local vmess_status
    if is_port_open "$vmess_port"; then
        vmess_status="${GREEN}● Open${NC}"
    else
        vmess_status="${RED}○ Closed${NC}"
    fi
    printf "  %-25s %-10s %-15b\n" "VMess TLS" "$vmess_port" "$vmess_status"
    
    # VLESS
    local vless_port="${V2RAY_PORT_VLESS:-8443}"
    local vless_status
    if is_port_open "$vless_port"; then
        vless_status="${GREEN}● Open${NC}"
    else
        vless_status="${RED}○ Closed${NC}"
    fi
    printf "  %-25s %-10s %-15b\n" "VLESS TLS" "$vless_port" "$vless_status"
    
    # SSH
    local ssh_port="${SSH_PORT:-22}"
    local ssh_status
    if is_port_open "$ssh_port"; then
        ssh_status="${GREEN}● Open${NC}"
    else
        ssh_status="${RED}○ Closed${NC}"
    fi
    printf "  %-25s %-10s %-15b\n" "SSH" "$ssh_port" "$ssh_status"
    
    # Webmin
    local webmin_port="${WEBMIN_PORT:-10000}"
    local webmin_status
    if is_port_open "$webmin_port"; then
        webmin_status="${GREEN}● Open${NC}"
    else
        webmin_status="${RED}○ Closed${NC}"
    fi
    printf "  %-25s %-10s %-15b\n" "Webmin" "$webmin_port" "$webmin_status"
    
    # Nginx HTTP
    local nginx_http="${NGINX_HTTP_PORT:-80}"
    local nginx_http_status
    if is_port_open "$nginx_http"; then
        nginx_http_status="${GREEN}● Open${NC}"
    else
        nginx_http_status="${RED}○ Closed${NC}"
    fi
    printf "  %-25s %-10s %-15b\n" "Nginx HTTP" "$nginx_http" "$nginx_http_status"
    
    # Nginx HTTPS
    local nginx_https="${NGINX_HTTPS_PORT:-443}"
    local nginx_https_status
    if is_port_open "$nginx_https"; then
        nginx_https_status="${GREEN}● Open${NC}"
    else
        nginx_https_status="${RED}○ Closed${NC}"
    fi
    printf "  %-25s %-10s %-15b\n" "Nginx HTTPS" "$nginx_https" "$nginx_https_status"
    
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    press_any_key
}

# Check if port is open
is_port_open() {
    local port="$1"
    ss -tuln 2>/dev/null | grep -q ":${port}\b" || netstat -tuln 2>/dev/null | grep -q ":${port}\b"
}

# Change VMess port
change_vmess_port() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                    CHANGE VMESS PORT                          ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local current_port="${V2RAY_PORT_VMESS:-443}"
    echo -e "${CYAN}Current VMess port:${NC} $current_port"
    echo ""
    
    local new_port
    while true; do
        read -p "$(echo -e "${YELLOW}Enter new port (1-65535):${NC} ")" new_port
        
        if validate_port "$new_port"; then
            if [[ "$new_port" == "$current_port" ]]; then
                print_info "Port unchanged"
                press_any_key
                return
            fi
            
            if is_port_open "$new_port"; then
                print_warning "Port $new_port is already in use"
                if ! confirm "Continue anyway?"; then
                    continue
                fi
            fi
            break
        else
            print_error "Invalid port number"
        fi
    done
    
    # Update configuration files
    update_port_config "V2RAY_PORT_VMESS" "$new_port"
    update_port_config "VMESS_TLS_PORT" "$new_port" "ports.conf"
    
    # Update V2Ray config if exists
    update_v2ray_port "vmess" "$new_port"
    
    print_success "VMess port changed to: $new_port"
    log_info "VMess port changed from $current_port to $new_port"
    
    # Restart V2Ray
    if confirm "Restart V2Ray to apply changes?"; then
        restart_service v2ray 2>/dev/null || print_warning "Could not restart V2Ray"
    fi
    
    press_any_key
}

# Change VLESS port
change_vless_port() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                    CHANGE VLESS PORT                          ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local current_port="${V2RAY_PORT_VLESS:-8443}"
    echo -e "${CYAN}Current VLESS port:${NC} $current_port"
    echo ""
    
    local new_port
    while true; do
        read -p "$(echo -e "${YELLOW}Enter new port (1-65535):${NC} ")" new_port
        
        if validate_port "$new_port"; then
            if [[ "$new_port" == "$current_port" ]]; then
                print_info "Port unchanged"
                press_any_key
                return
            fi
            
            if is_port_open "$new_port"; then
                print_warning "Port $new_port is already in use"
                if ! confirm "Continue anyway?"; then
                    continue
                fi
            fi
            break
        else
            print_error "Invalid port number"
        fi
    done
    
    # Update configuration files
    update_port_config "V2RAY_PORT_VLESS" "$new_port"
    update_port_config "VLESS_TLS_PORT" "$new_port" "ports.conf"
    
    # Update V2Ray config if exists
    update_v2ray_port "vless" "$new_port"
    
    print_success "VLESS port changed to: $new_port"
    log_info "VLESS port changed from $current_port to $new_port"
    
    # Restart V2Ray
    if confirm "Restart V2Ray to apply changes?"; then
        restart_service v2ray 2>/dev/null || print_warning "Could not restart V2Ray"
    fi
    
    press_any_key
}

# Change SSH port
change_ssh_port() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                    CHANGE SSH PORT                            ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  WARNING: Changing SSH port may lock you out!${NC}"
    echo -e "${YELLOW}   Make sure you can access the server via console.${NC}"
    echo ""
    
    local current_port="${SSH_PORT:-22}"
    echo -e "${CYAN}Current SSH port:${NC} $current_port"
    echo ""
    
    local new_port
    while true; do
        read -p "$(echo -e "${YELLOW}Enter new port (1-65535):${NC} ")" new_port
        
        if validate_port "$new_port"; then
            if [[ "$new_port" == "$current_port" ]]; then
                print_info "Port unchanged"
                press_any_key
                return
            fi
            break
        else
            print_error "Invalid port number"
        fi
    done
    
    if ! confirm "Are you SURE you want to change SSH port to $new_port?"; then
        print_info "Cancelled"
        press_any_key
        return
    fi
    
    # Backup sshd_config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak 2>/dev/null
    
    # Update SSH config
    sed -i "s/^#*Port .*/Port $new_port/" /etc/ssh/sshd_config 2>/dev/null
    
    # Update port config
    update_port_config "SSH_PORT" "$new_port" "ports.conf"
    
    print_success "SSH port changed to: $new_port"
    log_info "SSH port changed from $current_port to $new_port"
    
    # Restart SSH
    echo ""
    print_warning "SSH service needs to restart to apply changes"
    print_info "Your current session will continue, but new connections must use port $new_port"
    
    if confirm "Restart SSH service now?"; then
        systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
        print_success "SSH service restarted"
    fi
    
    press_any_key
}

# Change Webmin port
change_webmin_port() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                   CHANGE WEBMIN PORT                          ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local current_port="${WEBMIN_PORT:-10000}"
    echo -e "${CYAN}Current Webmin port:${NC} $current_port"
    echo ""
    
    local new_port
    while true; do
        read -p "$(echo -e "${YELLOW}Enter new port (1-65535):${NC} ")" new_port
        
        if validate_port "$new_port"; then
            if [[ "$new_port" == "$current_port" ]]; then
                print_info "Port unchanged"
                press_any_key
                return
            fi
            break
        else
            print_error "Invalid port number"
        fi
    done
    
    # Update Webmin config if exists
    local webmin_config="/etc/webmin/miniserv.conf"
    if [[ -f "$webmin_config" ]]; then
        sed -i "s/^port=.*/port=$new_port/" "$webmin_config"
        sed -i "s/^listen=.*/listen=$new_port/" "$webmin_config"
    fi
    
    # Update port config
    update_port_config "WEBMIN_PORT" "$new_port"
    update_port_config "WEBMIN_PORT" "$new_port" "ports.conf"
    
    print_success "Webmin port changed to: $new_port"
    log_info "Webmin port changed from $current_port to $new_port"
    
    # Restart Webmin
    if confirm "Restart Webmin to apply changes?"; then
        systemctl restart webmin 2>/dev/null || /etc/init.d/webmin restart 2>/dev/null
    fi
    
    press_any_key
}

# Check port status
check_port_status() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                    CHECK PORT STATUS                          ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local port
    read -p "$(echo -e "${YELLOW}Enter port to check:${NC} ")" port
    
    if ! validate_port "$port"; then
        print_error "Invalid port number"
        press_any_key
        return
    fi
    
    echo ""
    
    # Check if port is in use
    if is_port_open "$port"; then
        echo -e "${CYAN}Port $port:${NC} ${GREEN}● In Use${NC}"
        echo ""
        
        # Show what's using the port
        echo -e "${CYAN}Process using this port:${NC}"
        ss -tlnp 2>/dev/null | grep ":${port}\b" | head -5 || \
            netstat -tlnp 2>/dev/null | grep ":${port}\b" | head -5
    else
        echo -e "${CYAN}Port $port:${NC} ${YELLOW}○ Available${NC}"
    fi
    
    echo ""
    
    # Check firewall
    if command_exists ufw; then
        echo -e "${CYAN}UFW Firewall Status:${NC}"
        ufw status 2>/dev/null | grep -E "^${port}" || echo "  No specific rule for port $port"
    fi
    
    if command_exists iptables; then
        echo ""
        echo -e "${CYAN}IPTables Status:${NC}"
        iptables -L -n 2>/dev/null | grep -E "dpt:${port}\b" || echo "  No specific rule for port $port"
    fi
    
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    press_any_key
}

# Update port in config file
update_port_config() {
    local key="$1"
    local value="$2"
    local config_file="${3:-settings.conf}"
    local full_path="${SCRIPT_DIR}/config/${config_file}"
    
    if [[ -f "$full_path" ]]; then
        sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$full_path"
    fi
}

# Update V2Ray port
update_v2ray_port() {
    local protocol="$1"
    local new_port="$2"
    local v2ray_config="${V2RAY_CONFIG_DIR:-/etc/v2ray}/config.json"
    
    if [[ ! -f "$v2ray_config" ]]; then
        return 1
    fi
    
    # Backup config
    cp "$v2ray_config" "${v2ray_config}.bak"
    
    # Update port for the specified protocol
    local tmp_config="${v2ray_config}.tmp"
    jq --arg protocol "$protocol" --argjson port "$new_port" '
        .inbounds[] |= if .protocol == $protocol then .port = $port else . end
    ' "$v2ray_config" > "$tmp_config" 2>/dev/null
    
    if [[ -s "$tmp_config" ]]; then
        mv "$tmp_config" "$v2ray_config"
        return 0
    else
        rm -f "$tmp_config"
        return 1
    fi
}

# Export functions
export -f show_port_menu view_current_ports is_port_open
export -f change_vmess_port change_vless_port change_ssh_port
export -f change_webmin_port check_port_status update_port_config update_v2ray_port
