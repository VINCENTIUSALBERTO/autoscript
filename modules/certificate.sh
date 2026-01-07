#!/bin/bash
# ==============================================================================
# Certificate Management Module
# Provides SSL/TLS certificate renewal and management
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load libraries if not already loaded
[[ -z "$NC" ]] && source "${SCRIPT_DIR}/lib/colors.sh"
[[ -z "$(type -t log_info 2>/dev/null)" ]] && source "${SCRIPT_DIR}/lib/utils.sh"
[[ -z "$(type -t get_public_ip 2>/dev/null)" ]] && source "${SCRIPT_DIR}/lib/system.sh"

# Load configuration
# shellcheck disable=SC1091
[[ -f "${SCRIPT_DIR}/config/settings.conf" ]] && source "${SCRIPT_DIR}/config/settings.conf"

# Show certificate menu
show_certificate_menu() {
    while true; do
        clear_screen
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${BCYAN}                  CERTIFICATE MANAGEMENT                       ${NC}"
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${BGREEN}1.${NC} View Certificate Info"
        echo -e "  ${BGREEN}2.${NC} Renew V2Ray Certificate"
        echo -e "  ${BGREEN}3.${NC} Generate New Certificate"
        echo -e "  ${BGREEN}4.${NC} Import Custom Certificate"
        echo -e "  ${BGREEN}5.${NC} Setup Auto-Renewal"
        echo ""
        echo -e "  ${BRED}0.${NC} Back to Main Menu"
        echo ""
        echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        read -p "$(echo -e "${YELLOW}Select option:${NC} ")" choice
        
        case $choice in
            1) view_certificate_info ;;
            2) renew_v2ray_certificate ;;
            3) generate_new_certificate ;;
            4) import_custom_certificate ;;
            5) setup_auto_renewal ;;
            0) return 0 ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# View certificate information
view_certificate_info() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                   CERTIFICATE INFORMATION                     ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local cert_file="${V2RAY_CERT_FILE:-/etc/v2ray/v2ray.crt}"
    local key_file="${V2RAY_KEY_FILE:-/etc/v2ray/v2ray.key}"
    
    echo -e "${CYAN}Certificate File:${NC} $cert_file"
    echo -e "${CYAN}Private Key:${NC} $key_file"
    echo ""
    
    if [[ ! -f "$cert_file" ]]; then
        print_error "Certificate file not found"
        press_any_key
        return
    fi
    
    echo -e "${BWHITE}───────────────────────────────────────────────────────────────${NC}"
    echo ""
    
    # Certificate details
    echo -e "${CYAN}Subject:${NC}"
    openssl x509 -noout -subject -in "$cert_file" 2>/dev/null | sed 's/subject=/  /'
    
    echo ""
    echo -e "${CYAN}Issuer:${NC}"
    openssl x509 -noout -issuer -in "$cert_file" 2>/dev/null | sed 's/issuer=/  /'
    
    echo ""
    echo -e "${CYAN}Validity:${NC}"
    local start_date end_date
    start_date=$(openssl x509 -noout -startdate -in "$cert_file" 2>/dev/null | cut -d= -f2)
    end_date=$(openssl x509 -noout -enddate -in "$cert_file" 2>/dev/null | cut -d= -f2)
    echo -e "  Not Before: $start_date"
    echo -e "  Not After:  $end_date"
    
    # Calculate days remaining
    local end_epoch current_epoch days_left
    end_epoch=$(date -d "$end_date" +%s 2>/dev/null)
    current_epoch=$(date +%s)
    days_left=$(( (end_epoch - current_epoch) / 86400 ))
    
    echo ""
    if [[ "$days_left" -lt 0 ]]; then
        echo -e "${CYAN}Status:${NC} ${RED}EXPIRED ($((days_left * -1)) days ago)${NC}"
    elif [[ "$days_left" -lt 7 ]]; then
        echo -e "${CYAN}Status:${NC} ${RED}CRITICAL ($days_left days left)${NC}"
    elif [[ "$days_left" -lt 30 ]]; then
        echo -e "${CYAN}Status:${NC} ${YELLOW}WARNING ($days_left days left)${NC}"
    else
        echo -e "${CYAN}Status:${NC} ${GREEN}VALID ($days_left days left)${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}SANs (Subject Alternative Names):${NC}"
    openssl x509 -noout -ext subjectAltName -in "$cert_file" 2>/dev/null | grep -oP 'DNS:\K[^,]+' | while read -r san; do
        echo "  - $san"
    done
    
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    press_any_key
}

# Renew V2Ray certificate
renew_v2ray_certificate() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                 RENEW V2RAY CERTIFICATE                       ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local domain
    domain=$(get_vps_domain)
    
    if [[ "$domain" == "Not configured" ]]; then
        print_error "Domain not configured"
        press_any_key
        return
    fi
    
    echo -e "${CYAN}Domain:${NC} $domain"
    echo ""
    
    # Check current certificate
    local cert_file="${V2RAY_CERT_FILE:-/etc/v2ray/v2ray.crt}"
    if [[ -f "$cert_file" ]]; then
        local end_date days_left
        end_date=$(openssl x509 -noout -enddate -in "$cert_file" 2>/dev/null | cut -d= -f2)
        local end_epoch current_epoch
        end_epoch=$(date -d "$end_date" +%s 2>/dev/null)
        current_epoch=$(date +%s)
        days_left=$(( (end_epoch - current_epoch) / 86400 ))
        
        echo -e "${CYAN}Current certificate expires in:${NC} $days_left days"
        echo ""
    fi
    
    if ! confirm "Proceed with certificate renewal?"; then
        press_any_key
        return
    fi
    
    # Check certbot
    if ! command_exists certbot; then
        print_error "Certbot not installed"
        if confirm "Install certbot now?"; then
            apt update -q && apt install -y certbot
        else
            press_any_key
            return
        fi
    fi
    
    echo ""
    echo -e "${CYAN}Renewing certificate...${NC}"
    
    # Stop services that might use port 80
    local nginx_was_running=false
    if check_service nginx; then
        systemctl stop nginx
        nginx_was_running=true
    fi
    
    # Attempt renewal
    if certbot renew --force-renewal --standalone -d "$domain" 2>/dev/null; then
        # Copy renewed certificates
        local le_dir="/etc/letsencrypt/live/${domain}"
        local cert_dir="${V2RAY_CONFIG_DIR:-/etc/v2ray}"
        
        if [[ -f "${le_dir}/fullchain.pem" ]]; then
            cp "${le_dir}/fullchain.pem" "${cert_dir}/v2ray.crt"
            cp "${le_dir}/privkey.pem" "${cert_dir}/v2ray.key"
            chmod 644 "${cert_dir}/v2ray.crt"
            chmod 600 "${cert_dir}/v2ray.key"
            
            print_success "Certificate renewed successfully!"
            log_info "V2Ray certificate renewed for: $domain"
            
            # Restart V2Ray
            restart_service v2ray 2>/dev/null || true
        fi
    else
        print_error "Certificate renewal failed"
        print_info "Try running: certbot certonly --standalone -d $domain"
    fi
    
    # Restart nginx if it was running
    if [[ "$nginx_was_running" == "true" ]]; then
        systemctl start nginx
    fi
    
    press_any_key
}

# Generate new certificate (calls domain module)
generate_new_certificate() {
    # Source domain module and call its function
    source "${SCRIPT_DIR}/modules/domain.sh"
    generate_ssl_certificate
}

# Import custom certificate
import_custom_certificate() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                IMPORT CUSTOM CERTIFICATE                      ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local cert_dir="${V2RAY_CONFIG_DIR:-/etc/v2ray}"
    mkdir -p "$cert_dir"
    
    echo -e "${CYAN}Enter the path to your certificate file (fullchain.pem or .crt):${NC}"
    local cert_source
    read -p "Path: " cert_source
    
    if [[ ! -f "$cert_source" ]]; then
        print_error "Certificate file not found: $cert_source"
        press_any_key
        return
    fi
    
    echo ""
    echo -e "${CYAN}Enter the path to your private key file (.key or privkey.pem):${NC}"
    local key_source
    read -p "Path: " key_source
    
    if [[ ! -f "$key_source" ]]; then
        print_error "Key file not found: $key_source"
        press_any_key
        return
    fi
    
    # Validate certificate
    if ! openssl x509 -noout -in "$cert_source" 2>/dev/null; then
        print_error "Invalid certificate file"
        press_any_key
        return
    fi
    
    # Validate key
    if ! openssl rsa -noout -in "$key_source" 2>/dev/null && \
       ! openssl ec -noout -in "$key_source" 2>/dev/null; then
        print_error "Invalid private key file"
        press_any_key
        return
    fi
    
    # Check if key matches certificate
    local cert_modulus key_modulus
    cert_modulus=$(openssl x509 -noout -modulus -in "$cert_source" 2>/dev/null | md5sum | cut -d' ' -f1)
    key_modulus=$(openssl rsa -noout -modulus -in "$key_source" 2>/dev/null | md5sum | cut -d' ' -f1)
    
    if [[ "$cert_modulus" != "$key_modulus" ]] && [[ -n "$key_modulus" ]]; then
        print_warning "Certificate and key may not match"
        if ! confirm "Continue anyway?"; then
            press_any_key
            return
        fi
    fi
    
    # Backup existing
    if [[ -f "${cert_dir}/v2ray.crt" ]]; then
        cp "${cert_dir}/v2ray.crt" "${cert_dir}/v2ray.crt.bak"
    fi
    if [[ -f "${cert_dir}/v2ray.key" ]]; then
        cp "${cert_dir}/v2ray.key" "${cert_dir}/v2ray.key.bak"
    fi
    
    # Copy new certificate
    cp "$cert_source" "${cert_dir}/v2ray.crt"
    cp "$key_source" "${cert_dir}/v2ray.key"
    chmod 644 "${cert_dir}/v2ray.crt"
    chmod 600 "${cert_dir}/v2ray.key"
    
    print_success "Certificate imported successfully!"
    log_info "Custom certificate imported"
    
    # Restart V2Ray
    if confirm "Restart V2Ray to apply changes?"; then
        restart_service v2ray 2>/dev/null || true
    fi
    
    press_any_key
}

# Setup auto-renewal
setup_auto_renewal() {
    clear_screen
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                   SETUP AUTO-RENEWAL                          ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local cron_file="/etc/cron.d/certbot-renewal"
    
    # Check if already set up
    if [[ -f "$cron_file" ]]; then
        echo -e "${CYAN}Current auto-renewal cron:${NC}"
        cat "$cron_file"
        echo ""
        
        if ! confirm "Replace existing auto-renewal configuration?"; then
            press_any_key
            return
        fi
    fi
    
    local domain
    domain=$(get_vps_domain)
    
    if [[ "$domain" == "Not configured" ]]; then
        print_error "Domain not configured"
        press_any_key
        return
    fi
    
    local cert_dir="${V2RAY_CONFIG_DIR:-/etc/v2ray}"
    local le_dir="/etc/letsencrypt/live/${domain}"
    
    # Create renewal script
    local renewal_script="/usr/local/bin/renew-v2ray-cert.sh"
    cat > "$renewal_script" << 'SCRIPT'
#!/bin/bash
# V2Ray Certificate Renewal Script

DOMAIN="__DOMAIN__"
CERT_DIR="__CERT_DIR__"
LE_DIR="__LE_DIR__"
LOG_FILE="/var/log/cert-renewal.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "Starting certificate renewal for $DOMAIN"

# Stop nginx if running
systemctl is-active --quiet nginx && systemctl stop nginx

# Renew certificate
if certbot renew --standalone -d "$DOMAIN" 2>>"$LOG_FILE"; then
    # Copy new certificates
    if [[ -f "${LE_DIR}/fullchain.pem" ]]; then
        cp "${LE_DIR}/fullchain.pem" "${CERT_DIR}/v2ray.crt"
        cp "${LE_DIR}/privkey.pem" "${CERT_DIR}/v2ray.key"
        chmod 644 "${CERT_DIR}/v2ray.crt"
        chmod 600 "${CERT_DIR}/v2ray.key"
        log "Certificate renewed and copied successfully"
        
        # Restart V2Ray
        systemctl restart v2ray 2>>"$LOG_FILE"
    fi
else
    log "Certificate renewal failed"
fi

# Restart nginx if it was running
systemctl start nginx 2>/dev/null || true

log "Renewal process completed"
SCRIPT
    
    # Replace placeholders
    sed -i "s|__DOMAIN__|$domain|g" "$renewal_script"
    sed -i "s|__CERT_DIR__|$cert_dir|g" "$renewal_script"
    sed -i "s|__LE_DIR__|$le_dir|g" "$renewal_script"
    chmod +x "$renewal_script"
    
    # Create cron job (run at 3 AM on 1st and 15th of each month)
    cat > "$cron_file" << EOF
# Certbot certificate auto-renewal for V2Ray
0 3 1,15 * * root $renewal_script
EOF
    
    print_success "Auto-renewal configured successfully!"
    echo ""
    echo -e "${CYAN}Renewal script:${NC} $renewal_script"
    echo -e "${CYAN}Schedule:${NC} 3:00 AM on 1st and 15th of each month"
    
    log_info "Certificate auto-renewal configured"
    
    press_any_key
}

# Export functions
export -f show_certificate_menu view_certificate_info renew_v2ray_certificate
export -f generate_new_certificate import_custom_certificate setup_auto_renewal
