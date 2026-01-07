#!/bin/bash
# ==============================================================================
# System Detection and Information Functions
# Provides OS detection, system info retrieval, and hardware information
# ==============================================================================

# Detect OS type and version
detect_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        OS_NAME="$ID"
        OS_VERSION="$VERSION_ID"
        OS_PRETTY_NAME="$PRETTY_NAME"
    elif [[ -f /etc/lsb-release ]]; then
        # shellcheck disable=SC1091
        source /etc/lsb-release
        OS_NAME="$DISTRIB_ID"
        OS_VERSION="$DISTRIB_RELEASE"
        OS_PRETTY_NAME="$DISTRIB_DESCRIPTION"
    else
        OS_NAME="unknown"
        OS_VERSION="unknown"
        OS_PRETTY_NAME="Unknown OS"
    fi
    
    export OS_NAME OS_VERSION OS_PRETTY_NAME
}

# Check if OS is supported
is_supported_os() {
    detect_os
    case "${OS_NAME,,}" in
        ubuntu|debian)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Get public IP address
get_public_ip() {
    local ip=""
    local services=(
        "ifconfig.me"
        "ipinfo.io/ip"
        "icanhazip.com"
        "api.ipify.org"
    )
    
    for service in "${services[@]}"; do
        ip=$(curl -sf --max-time 5 "$service" 2>/dev/null)
        if [[ -n "$ip" ]] && validate_ip "$ip" 2>/dev/null; then
            echo "$ip"
            return 0
        fi
    done
    
    # Fallback to hostname
    hostname -I 2>/dev/null | awk '{print $1}'
}

# Get kernel version
get_kernel_version() {
    uname -r
}

# Get system uptime
get_uptime() {
    uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}'
}

# Get load average
get_load_average() {
    awk '{print $1", "$2", "$3}' /proc/loadavg
}

# Get total RAM
get_total_ram() {
    awk '/MemTotal/ {printf "%.0f", $2/1024}' /proc/meminfo
}

# Get used RAM
get_used_ram() {
    awk '/MemTotal/ {total=$2} /MemAvailable/ {available=$2} END {printf "%.0f", (total-available)/1024}' /proc/meminfo
}

# Get free RAM
get_free_ram() {
    awk '/MemAvailable/ {printf "%.0f", $2/1024}' /proc/meminfo
}

# Get RAM usage percentage
get_ram_usage_percent() {
    awk '/MemTotal/ {total=$2} /MemAvailable/ {available=$2} END {printf "%.1f", ((total-available)/total)*100}' /proc/meminfo
}

# Get CPU model
get_cpu_model() {
    grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//'
}

# Get CPU cores
get_cpu_cores() {
    nproc 2>/dev/null || grep -c "processor" /proc/cpuinfo
}

# Get disk usage
get_disk_usage() {
    df -h / | awk 'NR==2 {print $3"/"$2" ("$5" used)"}'
}

# Get disk free space
get_disk_free() {
    df -h / | awk 'NR==2 {print $4}'
}

# Get hostname
get_hostname() {
    hostname 2>/dev/null || cat /etc/hostname
}

# Get VPS domain from config
get_vps_domain() {
    local config_file="${SCRIPT_DIR}/config/settings.conf"
    if [[ -f "$config_file" ]]; then
        grep "^VPS_DOMAIN=" "$config_file" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'"
    else
        echo "Not configured"
    fi
}

# Get certificate expiry date for V2Ray
get_cert_expiry() {
    local cert_file="${V2RAY_CERT_FILE:-/etc/v2ray/v2ray.crt}"
    
    if [[ -f "$cert_file" ]]; then
        local expiry
        expiry=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | cut -d= -f2)
        if [[ -n "$expiry" ]]; then
            # Convert to standard format and calculate days remaining
            local expiry_epoch
            local current_epoch
            expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null)
            current_epoch=$(date +%s)
            local days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
            echo "$expiry ($days_left days left)"
        else
            echo "Unable to read certificate"
        fi
    else
        echo "Certificate not found"
    fi
}

# Display system information
display_system_info() {
    detect_os
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                     SYSTEM INFORMATION                        ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}  Hostname    :${NC} $(get_hostname)"
    echo -e "${CYAN}  IP Address  :${NC} $(get_public_ip)"
    echo -e "${CYAN}  Domain      :${NC} $(get_vps_domain)"
    echo -e "${CYAN}  OS          :${NC} $OS_PRETTY_NAME"
    echo -e "${CYAN}  Kernel      :${NC} $(get_kernel_version)"
    echo -e "${CYAN}  Uptime      :${NC} $(get_uptime)"
    echo -e "${CYAN}  Load Avg    :${NC} $(get_load_average)"
    echo ""
    echo -e "${BWHITE}───────────────────────────────────────────────────────────────${NC}"
    echo -e "${BCYAN}                     HARDWARE INFORMATION                      ${NC}"
    echo -e "${BWHITE}───────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${CYAN}  CPU Model   :${NC} $(get_cpu_model)"
    echo -e "${CYAN}  CPU Cores   :${NC} $(get_cpu_cores)"
    echo -e "${CYAN}  RAM Total   :${NC} $(get_total_ram) MB"
    echo -e "${CYAN}  RAM Used    :${NC} $(get_used_ram) MB ($(get_ram_usage_percent)%)"
    echo -e "${CYAN}  RAM Free    :${NC} $(get_free_ram) MB"
    echo -e "${CYAN}  Disk Usage  :${NC} $(get_disk_usage)"
    echo ""
    echo -e "${BWHITE}───────────────────────────────────────────────────────────────${NC}"
    echo -e "${BCYAN}                     V2RAY CERTIFICATE                         ${NC}"
    echo -e "${BWHITE}───────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${CYAN}  Cert Expiry :${NC} $(get_cert_expiry)"
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
}

# Display VPS summary header
display_vps_header() {
    local ip domain os kernel cert_expiry
    ip=$(get_public_ip)
    domain=$(get_vps_domain)
    detect_os
    kernel=$(get_kernel_version)
    cert_expiry=$(get_cert_expiry)
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e " ${CYAN}IP:${NC} $ip ${CYAN}│ Domain:${NC} $domain"
    echo -e " ${CYAN}OS:${NC} $OS_PRETTY_NAME ${CYAN}│ Kernel:${NC} $kernel"
    echo -e " ${CYAN}Cert Expiry:${NC} $cert_expiry"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
}

# Check and display RAM usage
display_ram_usage() {
    local total used free percent
    total=$(get_total_ram)
    used=$(get_used_ram)
    free=$(get_free_ram)
    percent=$(get_ram_usage_percent)
    
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BCYAN}                       RAM USAGE MONITOR                        ${NC}"
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${CYAN}Total RAM:${NC}     $total MB"
    echo -e "  ${CYAN}Used RAM:${NC}      $used MB"
    echo -e "  ${CYAN}Free RAM:${NC}      $free MB"
    echo -e "  ${CYAN}Usage:${NC}         $percent%"
    echo ""
    
    # Visual bar
    local bar_width=50
    local filled_width=$(echo "$percent $bar_width" | awk '{printf "%.0f", ($1/100)*$2}')
    local empty_width=$((bar_width - filled_width))
    
    echo -n "  ["
    local color
    # Use awk for floating point comparison instead of bc
    local percent_int
    percent_int=$(echo "$percent" | awk '{printf "%.0f", $1}')
    if [[ "$percent_int" -gt 90 ]]; then
        color="${RED}"
    elif [[ "$percent_int" -gt 70 ]]; then
        color="${YELLOW}"
    else
        color="${GREEN}"
    fi
    
    echo -en "${color}"
    for ((i=0; i<filled_width; i++)); do echo -n "█"; done
    echo -en "${NC}"
    for ((i=0; i<empty_width; i++)); do echo -n "░"; done
    echo "] ${percent}%"
    echo ""
    echo -e "${BWHITE}═══════════════════════════════════════════════════════════════${NC}"
    
    # Top memory consumers
    echo ""
    echo -e "${BCYAN}Top 5 Memory Consumers:${NC}"
    echo -e "${DIM}─────────────────────────────────────────────────────────────────${NC}"
    ps aux --sort=-%mem | head -6 | tail -5 | awk '{printf "  %-20s %5s%%\n", $11, $4}'
    echo ""
}

# Export functions
export -f detect_os is_supported_os get_public_ip get_kernel_version get_uptime
export -f get_load_average get_total_ram get_used_ram get_free_ram get_ram_usage_percent
export -f get_cpu_model get_cpu_cores get_disk_usage get_disk_free get_hostname
export -f get_vps_domain get_cert_expiry display_system_info display_vps_header display_ram_usage
