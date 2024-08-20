#!/bin/bash

# LOGX - DreamHost Log Analysis Tool
# https://github.com/LaughterOnWater/logx
#
# Author: LaughterOnWater (https://github.com/LaughterOnWater)
# License: MIT
# Version: 1.0.1

VERSION="1.0.1"

# Default configuration
HOME_DIR="${HOME_DIR:-$HOME}"
LOGS_DIR="${LOGS_DIR:-$HOME_DIR/logs}"
TOP_N="${TOP_N:-10}"
TOP_IPS_N="${TOP_IPS_N:-10}"
selected_domain="${selected_domain:-}"

# Source configuration file if it exists
CONFIG_FILE="./logx.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Ensure all variables have values (use defaults if not set in config)
HOME_DIR="${HOME_DIR:-$HOME}"
LOGS_DIR="${LOGS_DIR:-$HOME_DIR/logs}"
TOP_N="${TOP_N:-10}"
TOP_IPS_N="${TOP_IPS_N:-10}"
selected_domain="${selected_domain:-}"

# Echo the variables and directories for debugging
# echo "HOME_DIR: $HOME_DIR"
# echo "LOGS_DIR: $LOGS_DIR"
# echo "HOME: $HOME"
# echo "TOP_N: $TOP_N"
# echo "TOP_IPS_N: $TOP_IPS_N"
# echo "selected_domain: $selected_domain"

# Global variables
ACCESS_LOG=""
ERROR_LOG=""

# Function to display version information
show_version() {
    echo "LOGX version $VERSION"
    echo "Copyright (c) $(date +%Y) LaughterOnWater"
    echo "License: MIT"
    echo "https://github.com/LaughterOnWater/logx"
}

# Function to list available domains and prompt for selection
select_domain() {
    if [ -n "$selected_domain" ]; then
        echo "Using pre-selected domain: $selected_domain"
    else
        local domains=()
        local i=1

        echo "Available domains:"
        for domain in "$LOGS_DIR"/*; do
            if [ -d "$domain" ]; then
                domain_name=$(basename "$domain")
                domains+=("$domain_name")
                echo "$i) $domain_name"
                ((i++))
            fi
        done

        if [ ${#domains[@]} -eq 0 ]; then
            echo "No domains found in $LOGS_DIR"
            exit 1
        fi

        echo
        read -p "Enter the number or name of the domain you want to analyze: " selection

        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#domains[@]}" ]; then
            selected_domain="${domains[$selection-1]}"
        elif [[ " ${domains[@]} " =~ " ${selection} " ]]; then
            selected_domain="$selection"
        else
            echo "Invalid selection. Please run the script again and choose a valid option."
            exit 1
        fi

        echo "Selected domain: $selected_domain"
        echo
    fi

    ACCESS_LOG="$LOGS_DIR/$selected_domain/https/access.log"
    ERROR_LOG="$LOGS_DIR/$selected_domain/https/error.log"
}

# Function to check if a file exists
check_file() {
    if [ ! -f "$1" ]; then
        echo "Error: Log file not found at $1" >&2
        exit 1
    fi
}

# Function to print section header
print_header() {
    echo -e "\n$1"
    echo "$(printf '=%.0s' {1..${#1}})"
}

# Function to get top N items
get_top_n() {
    sort | uniq -c | sort -rn | head -n "$TOP_N" | awk '{$1=$1};1'
}

# Function to parse access log timestamp
parse_access_log_time() {
    awk '
    BEGIN {
        months["Jan"]="01"; months["Feb"]="02"; months["Mar"]="03";
        months["Apr"]="04"; months["May"]="05"; months["Jun"]="06";
        months["Jul"]="07"; months["Aug"]="08"; months["Sep"]="09";
        months["Oct"]="10"; months["Nov"]="11"; months["Dec"]="12";
    }
    {
        split($4, datetime, ":")
        gsub(/\[/, "", datetime[1])
        split(datetime[1], date, "/")
        print date[3] "-" months[date[2]] "-" date[1] " " datetime[2] ":" datetime[3] ":" datetime[4]
    }
    ' "$1"
}

# Function to parse error log timestamp
parse_error_log_time() {
    awk '{
        gsub(/[\[\]]/, "")
        split($4, time, ".")
        printf "%s %s %s %s\n", $5, $2, $3, time[1]
    }' "$1"
}

# Function to get time range of log file
get_time_range() {
    local log_file="$1"
    local log_type="$2"
    local parse_function

    if [ "$log_type" = "access" ]; then
        parse_function="parse_access_log_time"
    else
        parse_function="parse_error_log_time"
    fi

    local start_time=$($parse_function "$log_file" | head -n 1)
    local end_time=$($parse_function "$log_file" | tail -n 1)
    
    echo "Log covers from $start_time to $end_time"
}

# Function to get top IPs from access log
get_top_ips_access() {
    local log_file="$1"
    local top_n="$2"

    echo "Top $top_n IP addresses by request count:"
    awk '{print $1}' "$log_file" | sort | uniq -c | sort -rn | head -n "$top_n" | 
    awk '{
        printf "%s (%d requests, %.2f%% of total)\n", $2, $1, ($1/total)*100
    }' total=$(wc -l < "$log_file")

    echo -e "\nDetailed analysis of top 5 IPs:"
    for ip in $(awk '{print $1}' "$log_file" | sort | uniq -c | sort -rn | head -n 5 | awk '{print $2}'); do
        echo -e "\nIP: $ip"
        echo "Total requests: $(grep -c "$ip" "$log_file")"
        echo "Most requested URLs:"
        grep "$ip" "$log_file" | awk '{print $7}' | sort | uniq -c | sort -rn | head -n 3
        echo "User agents:"
        grep "$ip" "$log_file" | awk -F'"' '{print $6}' | sort | uniq -c | sort -rn | head -n 2
    done
}

# Function to get top IPs from error log
get_top_ips_error() {
    local log_file="$1"
    local top_n="$2"

    echo "Top $top_n IP addresses by error count:"
    awk -F'[][]' '/remote/ {print $6}' "$log_file" | awk -F: '{print $1}' | sort | uniq -c | sort -rn | head -n "$top_n" |
    awk '{
        printf "%s (%d errors, %.2f%% of total)\n", $2, $1, ($1/total)*100
    }' total=$(grep -c 'remote' "$log_file")

    echo -e "\nDetailed analysis of top 5 IPs:"
    for ip in $(awk -F'[][]' '/remote/ {print $6}' "$log_file" | awk -F: '{print $1}' | sort | uniq -c | sort -rn | head -n 5 | awk '{print $2}'); do
        echo -e "\nIP: $ip"
        echo "Total errors: $(grep -c "$ip" "$log_file")"
        echo "Most common error types:"
        grep "$ip" "$log_file" | awk -F'[][]' '{print $2}' | sort | uniq -c | sort -rn | head -n 3
        echo "Most common error messages:"
        grep "$ip" "$log_file" | awk -F'stderr: ' '{print $2}' | sort | uniq -c | sort -rn | head -n 3
    done
}

# Function to check for potential security threats
check_security_threats() {
    local log_file="$1"
    local threshold="$2"

    echo "Potential security threats (IPs with high error rates):"
    awk -F'[][]' '/remote/ {print $6}' "$log_file" | awk -F: '{print $1}' | sort | uniq -c | sort -rn | 
    awk -v threshold="$threshold" '$1 > threshold {printf "%s (%d errors)\n", $2, $1}'

    echo -e "\nPotential vulnerability scans:"
    grep -iE "sql injection|xss|csrf|directory traversal" "$log_file" | 
    awk -F'[][]' '/remote/ {print $6}' | awk -F: '{print $1}' | sort | uniq -c | sort -rn | head -n 5
}

# Function to analyze error patterns
analyze_error_patterns() {
    local log_file="$1"
    local top_n="$2"

    echo "Top $top_n most frequent error messages:"
    awk -F'stderr: ' '/stderr:/ {print $2}' "$log_file" | sort | uniq -c | sort -rn | head -n "$top_n"

    echo -e "\nTop $top_n most frequent error locations:"
    awk -F'stderr: ' '/stderr:/ {print $2}' "$log_file" | awk -F' in ' '{print $2}' | awk -F' on line ' '{print $1}' | sort | uniq -c | sort -rn | head -n "$top_n"

    echo -e "\nMost common error types:"
    awk -F'[][]' '{print $2}' "$log_file" | sort | uniq -c | sort -rn | head -n "$top_n"
}

# Function to analyze access log
analyze_access_log() {
    select_domain
    check_file "$ACCESS_LOG"
    print_header "Analyzing Access Log for $selected_domain"
    get_time_range "$ACCESS_LOG" "access"
    echo
    
    echo "Top $TOP_N most frequently accessed URLs:"
    awk '{print $7}' "$ACCESS_LOG" | get_top_n

    echo -e "\nTotal requests: $(wc -l < "$ACCESS_LOG")"
    echo "Unique IP addresses: $(awk '{print $1}' "$ACCESS_LOG" | sort -u | wc -l)"

    echo -e "\nMost common user agents:"
    awk -F'"' '{print $6}' "$ACCESS_LOG" | get_top_n | head -n 5

    echo -e "\nAnalyzing IP addresses:"
    get_top_ips_access "$ACCESS_LOG" "$TOP_N"
}

# Function to analyze error log
analyze_error_log() {
    select_domain
    check_file "$ERROR_LOG"
    print_header "Analyzing Error Log for $selected_domain"
    get_time_range "$ERROR_LOG" "error"
    echo

    echo "Top $TOP_N most frequent error types:"
    awk -F'[][]' '{print $2}' "$ERROR_LOG" | sort | uniq -c | sort -rn | head -n "$TOP_N"

    echo -e "\nTotal error entries: $(wc -l < "$ERROR_LOG")"

    echo -e "\nAnalyzing IP addresses:"
    get_top_ips_error "$ERROR_LOG" "$TOP_N"

    echo -e "\nAnalyzing error patterns:"
    analyze_error_patterns "$ERROR_LOG" "$TOP_N"

    echo -e "\nChecking for potential security threats:"
    check_security_threats "$ERROR_LOG" 100  # Adjust the threshold as needed
}

# Function to analyze disk usage
disk_usage() {
    print_header "Analyzing Disk Usage"
    
    if [ ! -d "$HOME_DIR" ]; then
        echo "Error: Directory $HOME_DIR not found" >&2
        exit 1
    fi

    echo "Top 20 largest directories:"
    du -h "$HOME_DIR" 2>/dev/null | sort -rh | head -n 20

    echo -e "\nTop 20 largest files:"
    find "$HOME_DIR" -type f -exec du -h {} + 2>/dev/null | sort -rh | head -n 20

    echo -e "\nDisk usage by file type:"
    find "$HOME_DIR" -type f 2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -n 20
}

# Function to check resource usage
resource_usage() {
    print_header "Current Resource Usage"
    
    echo "CPU usage:"
    top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}'
    
    echo -e "\nMemory usage:"
    free -m | awk 'NR==2{printf "%.2f%%\n", $3*100/$2}'
    
    echo -e "\nDisk usage:"
    df -h | awk '$NF=="/"{printf "%s\n", $5}'
    
    echo -e "\nPHP processes:"
    ps aux | grep php | wc -l
}

# Function to print usage information
print_usage() {
#    echo "Usage: $0 [OPTION]" # aliased in bash file 2024.08.20
    echo "Usage: logx [OPTION]"
    echo "Analyze access and error logs, disk usage, and resource usage for a web server."
    echo
    echo "Options:"
    echo "  -a, --access    Analyze the access log"
    echo "  -e, --error     Analyze the error log"
    echo "  -d, --disk      Analyze disk usage"
    echo "  -r, --resources Check current resource usage"
    echo "  -h, --help      Display this help message"
    echo "  -v, --version   Display logx version"
    echo
    echo "Examples:"
#    echo "  $0 -a           Analyze access log" # aliased in bash file 2024.08.20
    echo "  logx -a           Analyze access log"
    echo "  logx --error      Analyze error log"
    echo "  logx --disk       Analyze disk usage"
    echo "  logx --resources  Check resource usage"
    echo
    echo "If no option is provided, this help message will be displayed."
}

# Main execution
main() {
    case "$1" in
        -a|--access)
            analyze_access_log
            ;;
        -e|--error)
            analyze_error_log
            ;;
        -d|--disk)
            disk_usage
            ;;
        -r|--resources)
            resource_usage
            ;;
        -h|--help|"")
            print_usage
            ;;
		-v|--version)
            show_version
            exit 0
            ;;
        *)
            echo "Error: Invalid option '$1'" >&2
            echo "Try '$0 --help' for more information." >&2
            exit 1
            ;;
    esac
}

main "$@"
