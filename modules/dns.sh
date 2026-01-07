#!/bin/bash
# ==============================================================================
# DNS Management Module
# Provides DNS server configuration
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load libraries if not already loaded
[[ -z "$NC" ]] && source "${SCRIPT_DIR}/lib/colors.sh"
[[ -z "$(type -t log_info 2>/dev/null)" ]] && source "${SCRIPT_DIR}/lib/utils.sh"

# Load configuration
# shellcheck disable=SC1091
[[ -f "${SCRIPT_DIR}/config/settings.conf" ]] && source "${SCRIPT_DIR}/config/settings.conf"

# DNS presets
declare -A DNS_PRESETS
DNS_PRESETS["Google"]="8.8.8.8 8.8.4.4"
DNS_PRESETS["Cloudflare"]="1.1.1.1 1.0.0.1"
DNS_PRESETS["OpenDNS"]="208.67.222.222 208.67.220.220"
DNS_PRESETS["Quad9"]="9.9.9.9 149.112.112.112"
DNS_PRESETS["AdGuard"]="94.140.14.14 94.140.15.15"

# Show DNS menu
show_dns_menu() {
    while true; do
        clear_screen
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${BCYAN}                   DNS SERVER MANAGEMENT                       ${NC}"
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${BGREEN}1.${NC} View Current DNS"
        echo -e "  ${BGREEN}2.${NC} Change DNS (Presets)"
        echo -e "  ${BGREEN}3.${NC} Change DNS (Custom)"
        echo -e "  ${BGREEN}4.${NC} Test DNS Resolution"
        echo -e "  ${BGREEN}5.${NC} Flush DNS Cache"
        echo ""
        echo -e "  ${BRED}0.${NC} Back to Main Menu"
        echo ""
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        read -p "$(echo -e "${YELLOW}Select option:${NC} ")" choice
        
        case $choice in
            1) view_current_dns ;;
            2) change_dns_preset ;;
            3) change_dns_custom ;;
            4) test_dns_resolution ;;
            5) flush_dns_cache ;;
            0) return 0 ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# View current DNS
view_current_dns() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                    CURRENT DNS SETTINGS                       ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${CYAN}System DNS (resolv.conf):${NC}"
    if [[ -f /etc/resolv.conf ]]; then
        grep "^nameserver" /etc/resolv.conf | while read -r line; do
            echo "  $line"
        done
    else
        echo "  ${DIM}File not found${NC}"
    fi
    
    echo ""
    
    # Check systemd-resolved if available
    if command_exists resolvectl; then
        echo -e "${CYAN}Systemd Resolved DNS:${NC}"
        resolvectl status 2>/dev/null | grep -A2 "DNS Servers" | head -3
    fi
    
    echo ""
    
    echo -e "${CYAN}Configured DNS (settings.conf):${NC}"
    echo -e "  Primary:   ${PRIMARY_DNS:-Not set}"
    echo -e "  Secondary: ${SECONDARY_DNS:-Not set}"
    
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    press_any_key
}

# Change DNS using presets
change_dns_preset() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                  CHANGE DNS (PRESETS)                         ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local i=1
    local -a preset_names
    
    for name in "${!DNS_PRESETS[@]}"; do
        local servers="${DNS_PRESETS[$name]}"
        preset_names+=("$name")
        echo -e "  ${BGREEN}${i}.${NC} $name ($servers)"
        ((i++))
    done
    
    echo ""
    echo -e "  ${BRED}0.${NC} Cancel"
    echo ""
    
    local choice
    read -p "$(echo -e "${YELLOW}Select DNS preset:${NC} ")" choice
    
    if [[ "$choice" == "0" ]]; then
        return
    fi
    
    if ! validate_number "$choice" || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "${#preset_names[@]}" ]]; then
        print_error "Invalid selection"
        press_any_key
        return
    fi
    
    local selected_name="${preset_names[$((choice-1))]}"
    local selected_servers="${DNS_PRESETS[$selected_name]}"
    
    read -ra dns_array <<< "$selected_servers"
    local primary="${dns_array[0]}"
    local secondary="${dns_array[1]}"
    
    apply_dns_settings "$primary" "$secondary"
    
    print_success "DNS changed to $selected_name"
    echo -e "  Primary:   $primary"
    echo -e "  Secondary: $secondary"
    
    log_info "DNS changed to $selected_name: $primary, $secondary"
    
    press_any_key
}

# Change DNS with custom values
change_dns_custom() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                  CHANGE DNS (CUSTOM)                          ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${CYAN}Current DNS:${NC}"
    echo -e "  Primary:   ${PRIMARY_DNS:-Not set}"
    echo -e "  Secondary: ${SECONDARY_DNS:-Not set}"
    echo ""
    
    local primary secondary
    
    while true; do
        read -p "$(echo -e "${YELLOW}Enter primary DNS:${NC} ")" primary
        if validate_ip "$primary"; then
            break
        else
            print_error "Invalid IP address"
        fi
    done
    
    while true; do
        read -p "$(echo -e "${YELLOW}Enter secondary DNS:${NC} ")" secondary
        if validate_ip "$secondary"; then
            break
        else
            print_error "Invalid IP address"
        fi
    done
    
    apply_dns_settings "$primary" "$secondary"
    
    print_success "DNS settings updated"
    echo -e "  Primary:   $primary"
    echo -e "  Secondary: $secondary"
    
    log_info "DNS changed to custom: $primary, $secondary"
    
    press_any_key
}

# Apply DNS settings
apply_dns_settings() {
    local primary="$1"
    local secondary="$2"
    
    # Update settings.conf
    local config_file="${SCRIPT_DIR}/config/settings.conf"
    sed -i "s|^PRIMARY_DNS=.*|PRIMARY_DNS=\"$primary\"|" "$config_file"
    sed -i "s|^SECONDARY_DNS=.*|SECONDARY_DNS=\"$secondary\"|" "$config_file"
    
    # Update global variables
    PRIMARY_DNS="$primary"
    SECONDARY_DNS="$secondary"
    
    # Check if using systemd-resolved
    if command_exists resolvectl && systemctl is-active --quiet systemd-resolved; then
        # Update resolved.conf
        local resolved_conf="/etc/systemd/resolved.conf"
        if [[ -f "$resolved_conf" ]]; then
            # Backup
            cp "$resolved_conf" "${resolved_conf}.bak"
            
            # Update DNS settings
            sed -i "s/^#*DNS=.*/DNS=$primary $secondary/" "$resolved_conf"
            
            # Restart resolved
            systemctl restart systemd-resolved 2>/dev/null
        fi
    fi
    
    # Update resolv.conf directly if not managed by systemd
    if [[ ! -L /etc/resolv.conf ]] || [[ ! -f /run/systemd/resolve/stub-resolv.conf ]]; then
        # Backup
        cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null
        
        # Write new DNS settings
        cat > /etc/resolv.conf << EOF
# DNS configured by VPS Autoscript
nameserver $primary
nameserver $secondary
EOF
    fi
}

# Test DNS resolution
test_dns_resolution() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                   TEST DNS RESOLUTION                         ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local test_domains=("google.com" "cloudflare.com" "github.com")
    
    echo -e "${CYAN}Testing DNS resolution...${NC}"
    echo ""
    
    for domain in "${test_domains[@]}"; do
        local result
        local start_time end_time duration
        
        start_time=$(date +%s%N)
        result=$(dig +short "$domain" 2>/dev/null | head -1)
        end_time=$(date +%s%N)
        
        duration=$(( (end_time - start_time) / 1000000 ))
        
        if [[ -n "$result" ]]; then
            echo -e "  ${GREEN}✓${NC} $domain → $result (${duration}ms)"
        else
            echo -e "  ${RED}✗${NC} $domain → Failed"
        fi
    done
    
    echo ""
    
    # Test with specific DNS servers
    echo -e "${CYAN}Testing with configured DNS servers:${NC}"
    echo ""
    
    if [[ -n "$PRIMARY_DNS" ]]; then
        local result
        result=$(dig @"$PRIMARY_DNS" +short google.com 2>/dev/null | head -1)
        if [[ -n "$result" ]]; then
            echo -e "  ${GREEN}✓${NC} Primary DNS ($PRIMARY_DNS) → Working"
        else
            echo -e "  ${RED}✗${NC} Primary DNS ($PRIMARY_DNS) → Failed"
        fi
    fi
    
    if [[ -n "$SECONDARY_DNS" ]]; then
        local result
        result=$(dig @"$SECONDARY_DNS" +short google.com 2>/dev/null | head -1)
        if [[ -n "$result" ]]; then
            echo -e "  ${GREEN}✓${NC} Secondary DNS ($SECONDARY_DNS) → Working"
        else
            echo -e "  ${RED}✗${NC} Secondary DNS ($SECONDARY_DNS) → Failed"
        fi
    fi
    
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    press_any_key
}

# Flush DNS cache
flush_dns_cache() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                    FLUSH DNS CACHE                            ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${CYAN}Flushing DNS cache...${NC}"
    echo ""
    
    local flushed=false
    
    # Systemd resolved
    if command_exists resolvectl && systemctl is-active --quiet systemd-resolved; then
        if resolvectl flush-caches 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Systemd-resolved cache flushed"
            flushed=true
        fi
    fi
    
    # Nscd
    if command_exists nscd && systemctl is-active --quiet nscd; then
        if nscd -i hosts 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Nscd cache flushed"
            flushed=true
        fi
    fi
    
    # Dnsmasq
    if command_exists dnsmasq && systemctl is-active --quiet dnsmasq; then
        if systemctl restart dnsmasq 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Dnsmasq cache flushed (service restarted)"
            flushed=true
        fi
    fi
    
    if [[ "$flushed" == "true" ]]; then
        print_success "DNS cache flushed successfully"
        log_info "DNS cache flushed"
    else
        print_info "No DNS cache services found to flush"
    fi
    
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    press_any_key
}

# Export functions
export -f show_dns_menu view_current_dns change_dns_preset
export -f change_dns_custom apply_dns_settings test_dns_resolution flush_dns_cache
