#!/bin/bash
# ==============================================================================
# Domain Management Module
# Provides domain configuration and SSL certificate management
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load libraries if not already loaded
[[ -z "$NC" ]] && source "${SCRIPT_DIR}/lib/colors.sh"
[[ -z "$(type -t log_info 2>/dev/null)" ]] && source "${SCRIPT_DIR}/lib/utils.sh"
[[ -z "$(type -t get_public_ip 2>/dev/null)" ]] && source "${SCRIPT_DIR}/lib/system.sh"

# Load configuration
# shellcheck disable=SC1091
[[ -f "${SCRIPT_DIR}/config/settings.conf" ]] && source "${SCRIPT_DIR}/config/settings.conf"

# Show domain menu
show_domain_menu() {
    while true; do
        clear_screen
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${BCYAN}                  DOMAIN MANAGEMENT MENU                       ${NC}"
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${BGREEN}1.${NC} View Current Domain"
        echo -e "  ${BGREEN}2.${NC} Change Domain"
        echo -e "  ${BGREEN}3.${NC} Check Domain DNS"
        echo -e "  ${BGREEN}4.${NC} Generate SSL Certificate"
        echo ""
        echo -e "  ${BRED}0.${NC} Back to Main Menu"
        echo ""
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        read -p "$(echo -e "${YELLOW}Select option:${NC} ")" choice
        
        case $choice in
            1) view_current_domain ;;
            2) change_domain ;;
            3) check_domain_dns ;;
            4) generate_ssl_certificate ;;
            0) return 0 ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# View current domain
view_current_domain() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                    CURRENT DOMAIN                             ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local domain
    domain=$(get_vps_domain)
    local ip
    ip=$(get_public_ip)
    
    echo -e "  ${CYAN}Configured Domain:${NC} $domain"
    echo -e "  ${CYAN}Server IP:${NC}         $ip"
    echo ""
    
    if [[ "$domain" != "Not configured" ]]; then
        # Check if domain resolves to this IP
        local resolved_ip
        resolved_ip=$(dig +short "$domain" 2>/dev/null | head -1)
        
        if [[ -n "$resolved_ip" ]]; then
            echo -e "  ${CYAN}Domain resolves to:${NC} $resolved_ip"
            
            if [[ "$resolved_ip" == "$ip" ]]; then
                echo -e "  ${CYAN}Status:${NC} ${GREEN}✓ Correctly pointing to this server${NC}"
            else
                echo -e "  ${CYAN}Status:${NC} ${YELLOW}⚠ Domain points to different IP${NC}"
            fi
        else
            echo -e "  ${CYAN}Status:${NC} ${RED}✗ Could not resolve domain${NC}"
        fi
        
        echo ""
        
        # Check SSL certificate
        if [[ -f "${V2RAY_CERT_FILE:-/etc/v2ray/v2ray.crt}" ]]; then
            local cert_info
            cert_info=$(get_cert_expiry)
            echo -e "  ${CYAN}SSL Certificate:${NC} $cert_info"
        else
            echo -e "  ${CYAN}SSL Certificate:${NC} ${YELLOW}Not found${NC}"
        fi
    fi
    
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    press_any_key
}

# Change domain
change_domain() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                    CHANGE DOMAIN                              ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local current_domain
    current_domain=$(get_vps_domain)
    
    if [[ "$current_domain" != "Not configured" ]]; then
        echo -e "${CYAN}Current domain:${NC} $current_domain"
        echo ""
    fi
    
    local new_domain
    while true; do
        read -p "$(echo -e "${YELLOW}Enter new domain:${NC} ")" new_domain
        
        if validate_domain "$new_domain"; then
            break
        else
            print_error "Invalid domain format"
        fi
    done
    
    # Verify DNS before updating
    echo ""
    echo -e "${CYAN}Verifying domain DNS...${NC}"
    
    local resolved_ip server_ip
    resolved_ip=$(dig +short "$new_domain" 2>/dev/null | head -1)
    server_ip=$(get_public_ip)
    
    if [[ -z "$resolved_ip" ]]; then
        print_warning "Domain DNS not found"
        if ! confirm "Continue anyway?"; then
            press_any_key
            return
        fi
    elif [[ "$resolved_ip" != "$server_ip" ]]; then
        print_warning "Domain resolves to $resolved_ip (Server IP: $server_ip)"
        if ! confirm "Continue anyway?"; then
            press_any_key
            return
        fi
    else
        print_success "Domain DNS verified"
    fi
    
    # Update configuration
    local config_file="${SCRIPT_DIR}/config/settings.conf"
    
    sed -i "s|^VPS_DOMAIN=.*|VPS_DOMAIN=\"$new_domain\"|" "$config_file"
    VPS_DOMAIN="$new_domain"
    
    print_success "Domain updated to: $new_domain"
    log_info "Domain changed to: $new_domain"
    
    # Ask about SSL certificate
    if confirm "Generate new SSL certificate for this domain?"; then
        generate_ssl_certificate
        return
    fi
    
    press_any_key
}

# Check domain DNS
check_domain_dns() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                    CHECK DOMAIN DNS                           ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local domain
    read -p "$(echo -e "${YELLOW}Enter domain to check:${NC} ")" domain
    
    if [[ -z "$domain" ]]; then
        domain=$(get_vps_domain)
        if [[ "$domain" == "Not configured" ]]; then
            print_error "No domain configured"
            press_any_key
            return
        fi
    fi
    
    echo ""
    echo -e "${CYAN}Checking DNS for:${NC} $domain"
    echo ""
    
    # A Record
    echo -e "${BWHITE}A Record:${NC}"
    local a_record
    a_record=$(dig +short A "$domain" 2>/dev/null)
    if [[ -n "$a_record" ]]; then
        echo -e "  $a_record"
    else
        echo -e "  ${DIM}No A record found${NC}"
    fi
    
    echo ""
    
    # AAAA Record (IPv6)
    echo -e "${BWHITE}AAAA Record (IPv6):${NC}"
    local aaaa_record
    aaaa_record=$(dig +short AAAA "$domain" 2>/dev/null)
    if [[ -n "$aaaa_record" ]]; then
        echo -e "  $aaaa_record"
    else
        echo -e "  ${DIM}No AAAA record found${NC}"
    fi
    
    echo ""
    
    # CNAME Record
    echo -e "${BWHITE}CNAME Record:${NC}"
    local cname_record
    cname_record=$(dig +short CNAME "$domain" 2>/dev/null)
    if [[ -n "$cname_record" ]]; then
        echo -e "  $cname_record"
    else
        echo -e "  ${DIM}No CNAME record found${NC}"
    fi
    
    echo ""
    
    # NS Records
    echo -e "${BWHITE}NS Records:${NC}"
    local ns_records
    ns_records=$(dig +short NS "$domain" 2>/dev/null)
    if [[ -n "$ns_records" ]]; then
        echo "$ns_records" | while read -r ns; do
            echo -e "  $ns"
        done
    else
        echo -e "  ${DIM}No NS records found${NC}"
    fi
    
    echo ""
    
    # MX Records
    echo -e "${BWHITE}MX Records:${NC}"
    local mx_records
    mx_records=$(dig +short MX "$domain" 2>/dev/null)
    if [[ -n "$mx_records" ]]; then
        echo "$mx_records" | while read -r mx; do
            echo -e "  $mx"
        done
    else
        echo -e "  ${DIM}No MX records found${NC}"
    fi
    
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    press_any_key
}

# Generate SSL certificate
generate_ssl_certificate() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                GENERATE SSL CERTIFICATE                       ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local domain
    domain=$(get_vps_domain)
    
    if [[ "$domain" == "Not configured" ]]; then
        print_error "Domain not configured. Please set domain first."
        press_any_key
        return
    fi
    
    echo -e "${CYAN}Domain:${NC} $domain"
    echo ""
    
    # Check if certbot is installed
    if ! command_exists certbot; then
        echo -e "${YELLOW}Installing certbot...${NC}"
        
        if command_exists apt; then
            apt update -q
            apt install -y certbot 2>/dev/null
        else
            print_error "Could not install certbot. Please install manually."
            press_any_key
            return
        fi
    fi
    
    # Stop nginx if running to free port 80
    local nginx_was_running=false
    if check_service nginx; then
        echo -e "${CYAN}Stopping nginx temporarily...${NC}"
        systemctl stop nginx
        nginx_was_running=true
    fi
    
    echo -e "${CYAN}Generating certificate...${NC}"
    echo ""
    
    local cert_dir="${V2RAY_CONFIG_DIR:-/etc/v2ray}"
    mkdir -p "$cert_dir"
    
    # Generate certificate using standalone mode
    if certbot certonly --standalone -d "$domain" --non-interactive --agree-tos --email "admin@${domain}" 2>/dev/null; then
        # Copy certificates
        local le_dir="/etc/letsencrypt/live/${domain}"
        
        if [[ -f "${le_dir}/fullchain.pem" ]] && [[ -f "${le_dir}/privkey.pem" ]]; then
            cp "${le_dir}/fullchain.pem" "${cert_dir}/v2ray.crt"
            cp "${le_dir}/privkey.pem" "${cert_dir}/v2ray.key"
            chmod 644 "${cert_dir}/v2ray.crt"
            chmod 600 "${cert_dir}/v2ray.key"
            
            print_success "SSL certificate generated successfully!"
            echo ""
            echo -e "  ${CYAN}Certificate:${NC} ${cert_dir}/v2ray.crt"
            echo -e "  ${CYAN}Private Key:${NC} ${cert_dir}/v2ray.key"
            
            log_info "SSL certificate generated for: $domain"
            
            # Restart V2Ray
            if check_service v2ray; then
                restart_service v2ray
            fi
        else
            print_error "Certificate files not found"
        fi
    else
        print_error "Failed to generate certificate"
        print_info "Make sure port 80 is accessible and domain DNS is correct"
    fi
    
    # Restart nginx if it was running
    if [[ "$nginx_was_running" == "true" ]]; then
        echo ""
        echo -e "${CYAN}Starting nginx...${NC}"
        systemctl start nginx
    fi
    
    press_any_key
}

# Export functions
export -f show_domain_menu view_current_domain change_domain
export -f check_domain_dns generate_ssl_certificate
