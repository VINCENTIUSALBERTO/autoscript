#!/bin/bash
# ==============================================================================
# Utility Functions Library
# Provides common helper functions for logging, validation, and input handling
# ==============================================================================

# Configuration
LOG_FILE="${LOG_FILE:-/var/log/autoscript.log}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Ensure log directory exists
ensure_log_dir() {
    local log_dir
    log_dir="$(dirname "$LOG_FILE")"
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" 2>/dev/null || true
    fi
}

# Logging function with timestamp
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    ensure_log_dir
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
}

log_info() {
    log "INFO" "$1"
}

log_warn() {
    log "WARN" "$1"
}

log_error() {
    log "ERROR" "$1"
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        log "DEBUG" "$1"
    fi
}

# Print functions with colors
print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
    log_info "$1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log_info "$1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log_warn "$1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log_error "$1"
}

# Clear screen and show header
clear_screen() {
    clear
    show_header
}

# Show script header
show_header() {
    echo -e "${BCYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BCYAN}║${NC}          ${BWHITE}VPS AUTOSCRIPT MANAGEMENT SYSTEM${NC}                    ${BCYAN}║${NC}"
    echo -e "${BCYAN}║${NC}          ${DIM}Version 1.0.0 - Production Ready${NC}                     ${BCYAN}║${NC}"
    echo -e "${BCYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Show separator line
show_separator() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Input validation functions
validate_port() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]] && [[ "$port" -ge 1 ]] && [[ "$port" -le 65535 ]]; then
        return 0
    fi
    return 1
}

validate_domain() {
    local domain="$1"
    if [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]; then
        return 0
    fi
    return 1
}

validate_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local IFS='.'
        read -ra octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [[ "$octet" -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

validate_username() {
    local username="$1"
    if [[ "$username" =~ ^[a-zA-Z][a-zA-Z0-9_-]{2,31}$ ]]; then
        return 0
    fi
    return 1
}

validate_number() {
    local num="$1"
    if [[ "$num" =~ ^[0-9]+$ ]]; then
        return 0
    fi
    return 1
}

# Read input with validation
read_input() {
    local prompt="$1"
    local var_name="$2"
    local validator="$3"
    local default="$4"
    local input
    
    while true; do
        if [[ -n "$default" ]]; then
            echo -en "${YELLOW}$prompt${NC} [${GREEN}$default${NC}]: "
        else
            echo -en "${YELLOW}$prompt${NC}: "
        fi
        read -r input
        
        # Use default if empty and default provided
        if [[ -z "$input" ]] && [[ -n "$default" ]]; then
            input="$default"
        fi
        
        # Validate if validator provided
        if [[ -n "$validator" ]]; then
            if $validator "$input"; then
                eval "$var_name='$input'"
                return 0
            else
                print_error "Invalid input. Please try again."
            fi
        else
            eval "$var_name='$input'"
            return 0
        fi
    done
}

# Confirmation prompt
confirm() {
    local prompt="${1:-Are you sure?}"
    local response
    
    echo -en "${YELLOW}$prompt${NC} [y/N]: "
    read -r response
    
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Press any key to continue
press_any_key() {
    echo ""
    echo -en "${DIM}Press any key to continue...${NC}"
    read -n 1 -s -r
    echo ""
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Check command availability
command_exists() {
    command -v "$1" &> /dev/null
}

# Safe wget with timeout
safe_wget() {
    local url="$1"
    local output="$2"
    local timeout="${3:-30}"
    
    wget --timeout="$timeout" --tries=3 -q -O "$output" "$url"
    return $?
}

# Safe curl with timeout
safe_curl() {
    local url="$1"
    local timeout="${2:-30}"
    
    curl --connect-timeout "$timeout" --max-time "$((timeout * 2))" -sf "$url"
    return $?
}

# Check service status
check_service() {
    local service="$1"
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Start service
start_service() {
    local service="$1"
    if systemctl start "$service" 2>/dev/null; then
        print_success "Service $service started"
        log_info "Service $service started"
        return 0
    else
        print_error "Failed to start service $service"
        log_error "Failed to start service $service"
        return 1
    fi
}

# Stop service
stop_service() {
    local service="$1"
    if systemctl stop "$service" 2>/dev/null; then
        print_success "Service $service stopped"
        log_info "Service $service stopped"
        return 0
    else
        print_error "Failed to stop service $service"
        log_error "Failed to stop service $service"
        return 1
    fi
}

# Restart service
restart_service() {
    local service="$1"
    if systemctl restart "$service" 2>/dev/null; then
        print_success "Service $service restarted"
        log_info "Service $service restarted"
        return 0
    else
        print_error "Failed to restart service $service"
        log_error "Failed to restart service $service"
        return 1
    fi
}

# Get file age in days
get_file_age_days() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local file_time
        local current_time
        file_time=$(stat -c %Y "$file" 2>/dev/null)
        current_time=$(date +%s)
        echo $(( (current_time - file_time) / 86400 ))
    else
        echo "-1"
    fi
}

# Create backup of file
backup_file() {
    local file="$1"
    local backup_dir="${2:-/root/backup}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    
    mkdir -p "$backup_dir"
    
    if [[ -f "$file" ]]; then
        cp "$file" "${backup_dir}/$(basename "$file").${timestamp}.bak"
        return 0
    fi
    return 1
}

# Generate random string
generate_random_string() {
    local length="${1:-32}"
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}

# Generate UUID
generate_uuid() {
    cat /proc/sys/kernel/random/uuid 2>/dev/null || \
        uuidgen 2>/dev/null || \
        od -x /dev/urandom | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}'
}

# Format bytes to human readable
format_bytes() {
    local bytes="$1"
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while [[ "$bytes" -ge 1024 ]] && [[ "$unit" -lt 4 ]]; do
        bytes=$((bytes / 1024))
        ((unit++))
    done
    
    echo "${bytes} ${units[$unit]}"
}

# Calculate days until date
days_until() {
    local target_date="$1"
    local target_epoch
    local current_epoch
    
    target_epoch=$(date -d "$target_date" +%s 2>/dev/null)
    current_epoch=$(date +%s)
    
    if [[ -n "$target_epoch" ]]; then
        echo $(( (target_epoch - current_epoch) / 86400 ))
    else
        echo "N/A"
    fi
}

# Export functions
export -f log log_info log_warn log_error log_debug
export -f print_info print_success print_warning print_error
export -f clear_screen show_header show_separator
export -f validate_port validate_domain validate_ip validate_username validate_number
export -f read_input confirm press_any_key check_root command_exists
export -f safe_wget safe_curl check_service start_service stop_service restart_service
export -f get_file_age_days backup_file generate_random_string generate_uuid
export -f format_bytes days_until ensure_log_dir
