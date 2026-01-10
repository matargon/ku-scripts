#!/usr/bin/env bash

#
# Helpers
#
color_blue() { printf '\033[0;34m%s\033[0m\n' "$1"; }
color_green() { printf '\033[0;32m%s\033[0m\n' "$1"; }
color_red() { printf '\033[0;31m%s\033[0m\n' "$1"; }
log_line() {
    printf '%s\n' "$1" | tee -a "$log_file" >/dev/null
}
log_line_blue() {
    color_blue "$1"
    printf '%s\n' "$1" >> "$log_file"
}

load_local_ips() {
    while IFS= read -r ip; do
        [ -n "$ip" ] && local_ips+=("$ip")
    done < <(ifconfig | awk '/inet /{print $2}')
}

is_local_ip() {
    local srv="$1"
    local ip
    for ip in "${local_ips[@]}"; do
        if [ "$srv" = "$ip" ]; then
            return 0
        fi
    done
    return 1
}

run_server() {
    local srv="$1"
    local tmp_log
    local status
    local start_ts
    local end_ts
    local duration
    local start_time_str
    local end_time_str

    if is_local_ip "$srv"; then
        color_green "script skipped (local) $srv"
        successes+=("$srv")
        end_time_str=$(date '+%Y-%m-%d %H:%M:%S')
        log_line_blue "===== $srv skipped (local) at $end_time_str ====="
        return 0
    fi

    start_ts=$(date +%s)
    start_time_str=$(date '+%Y-%m-%d %H:%M:%S')
    tmp_log="$(mktemp)"
    log_line_blue "===== $srv start $start_time_str ====="
    ./run_on_server.sh "$srv" 2>&1 | tee "$tmp_log" | tee -a "$log_file"
    status=${PIPESTATUS[0]}
    end_ts=$(date +%s)
    duration=$((end_ts - start_ts))
    end_time_str=$(date '+%Y-%m-%d %H:%M:%S')
    if [ $status -eq 0 ]; then
        color_green "script success $srv"
        successes+=("$srv")
    else
        color_red "script failed $srv"
        cat "$tmp_log"
        failures+=("$srv")
        printf '%s\n' "$srv" >> "$failed_ips_file"
    fi
    rm -f "$tmp_log"
    log_line_blue "===== $srv end $end_time_str status=$status duration=${duration}s ====="
    printf 'finished at: %s\n' "$end_time_str"
    printf 'duration: %ss\n' "$duration"
}

print_summary() {
    printf '\n'
    printf 'Summary:\n'
    printf 'total: %s\n' "$total_targets"
    printf 'success: %s/%s\n' "${#successes[@]}" "$total_targets"
    printf 'total duration: %ss\n' "$total_duration"
    if [ ${#successes[@]} -gt 0 ]; then
        printf '\033[0;32m'
        printf 'success: %s\n' "${successes[*]}"
        printf '\033[0m'
    fi
    if [ ${#failures[@]} -gt 0 ]; then
        printf '\033[0;31m'
        printf 'failed: %s\n' "${failures[*]}"
        printf '\033[0m'
    fi
}

#
# Main
#
USER=$(whoami)
successes=()
failures=()
local_ips=()
total_targets=0
total_start_ts=$(date +%s)
log_file="all_servers.log"
failed_ips_file="failed_ips.txt"

load_local_ips
: > "$log_file"
: > "$failed_ips_file"
total_targets=$(awk 'NF{c++} END{print c+0}' servers.txt)
printf 'total to run: %s\n' "$total_targets"
while IFS= read -r srv; do
    [ -n "$srv" ] && run_server "$srv"
done < servers.txt
wait
total_end_ts=$(date +%s)
total_duration=$((total_end_ts - total_start_ts))
print_summary
