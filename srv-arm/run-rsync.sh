#!/usr/bin/env bash

# Placeholder config: fill these in.
SERVER_USER="ku"
SERVER_HOST="srv.kod-u.ru"
SERVER_CSV_PATH="/var/arm-u/ku-sync/laptop-sync.csv"
SERVER_LOG_ROOT="/var/arm-u/ku-sync/"
# SSH_KEY="/path/to/key"
RSYNC_FLAGS="-va --progress --delete --update --dry-run"

color_blue() { printf '\033[0;34m%s\033[0m\n' "$1"; }
color_green() { printf '\033[0;32m%s\033[0m\n' "$1"; }
color_red() { printf '\033[0;31m%s\033[0m\n' "$1"; }

trim() {
    local s="$1"
    s=${s#"${s%%[![:space:]]*}"}
    s=${s%"${s##*[![:space:]]}"}
    printf '%s' "$s"
}

LOCAL_IP=$(ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -n1)
if [ -z "$LOCAL_IP" ]; then
    color_red "could not detect local IP"
    exit 1
fi

tmp_csv="$(mktemp)"
tmp_log="$(mktemp)"

scp_cmd=(scp)
ssh_cmd=(ssh)
# rsync_ssh="ssh"
# if [ -n "$SSH_KEY" ]; then
    # scp_cmd+=(-i "$SSH_KEY")
    # ssh_cmd+=(-i "$SSH_KEY")
    # rsync_ssh="ssh -i $SSH_KEY"
# fi

color_blue "fetching csv from $SERVER_HOST"
"${scp_cmd[@]}" "$SERVER_USER@$SERVER_HOST:$SERVER_CSV_PATH" "$tmp_csv"

run_ts=$(date '+%Y-%m-%d_%H-%M-%S')
remote_log_dir="$SERVER_LOG_ROOT/logs"
remote_log_file=""
had_run=0
had_fail=0

color_blue "processing csv for local ip $LOCAL_IP"
printf 'run start: %s ip=%s\n' "$run_ts" "$LOCAL_IP" >> "$tmp_log"
while IFS=, read -r ip src dst; do
    ip=$(trim "$ip")
    src=$(trim "$src")
    dst=$(trim "$dst")

    printf 'row: ip=%s src=%s dst=%s\n' "$ip" "$src" "$dst" >> "$tmp_log"
    [ -z "$ip" ] && continue
    [ "${ip#\#}" != "$ip" ] && continue

    if [ "$ip" != "$LOCAL_IP" ]; then
        printf 'skip: ip mismatch (local=%s)\n' "$LOCAL_IP" >> "$tmp_log"
        continue
    fi

    if [ -z "$src" ] || [ -z "$dst" ]; then
        printf 'skip: bad row ip=%s src=%s dst=%s\n' "$ip" "$src" "$dst" >> "$tmp_log"
        continue
    fi

    printf 'rsync %s -> %s\n' "$src" "$dst" >> "$tmp_log"
    had_run=1
    rsync $RSYNC_FLAGS "$SERVER_USER@$SERVER_HOST:$src" "$dst"
    status=$?
    if [ $status -eq 0 ]; then
        printf 'ok: %s\n' "$src" >> "$tmp_log"
    else
        had_fail=1
        printf 'fail: %s (status=%s)\n' "$src" "$status" >> "$tmp_log"
    fi
done < "$tmp_csv"

if [ $had_run -eq 0 ]; then
    run_status="skipped"
elif [ $had_fail -eq 0 ]; then
    run_status="success"
else
    run_status="failed"
fi
printf 'run status: %s\n' "$run_status" >> "$tmp_log"
remote_log_file="${LOCAL_IP}_${run_ts}_${run_status}.log"

color_blue "sending log to server"
"${ssh_cmd[@]}" "$SERVER_USER@$SERVER_HOST" "mkdir -p \"$remote_log_dir\""
"${scp_cmd[@]}" "$tmp_log" "$SERVER_USER@$SERVER_HOST:$remote_log_dir/$remote_log_file"

rm -f "$tmp_csv" "$tmp_log"
color_green "done"
