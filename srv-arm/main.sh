#!/usr/bin/env bash

# Placeholder config: fill these in.
SERVER_USER="CHANGE_ME"
SERVER_HOST="CHANGE_ME"
SERVER_CSV_PATH="/path/to/file.csv"
SERVER_LOG_ROOT="/path/to/logs"
SSH_KEY="/path/to/key"

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
rsync_ssh="ssh"
if [ -n "$SSH_KEY" ]; then
    scp_cmd+=(-i "$SSH_KEY")
    ssh_cmd+=(-i "$SSH_KEY")
    rsync_ssh="ssh -i $SSH_KEY"
fi

color_blue "fetching csv from $SERVER_HOST"
"${scp_cmd[@]}" "$SERVER_USER@$SERVER_HOST:$SERVER_CSV_PATH" "$tmp_csv"

run_ts=$(date '+%Y-%m-%d_%H-%M-%S')
remote_log_dir="$SERVER_LOG_ROOT/$LOCAL_IP"
remote_log_file="${LOCAL_IP}_${run_ts}.log"

color_blue "processing csv for local ip $LOCAL_IP"
while IFS=, read -r ip src dst; do
    ip=$(trim "$ip")
    src=$(trim "$src")
    dst=$(trim "$dst")

    [ -z "$ip" ] && continue
    [ "${ip#\#}" != "$ip" ] && continue

    if [ "$ip" != "$LOCAL_IP" ]; then
        continue
    fi

    if [ -z "$src" ] || [ -z "$dst" ]; then
        printf 'skip: bad row ip=%s src=%s dst=%s\n' "$ip" "$src" "$dst" >> "$tmp_log"
        continue
    fi

    printf 'rsync %s -> %s\n' "$src" "$dst" >> "$tmp_log"
    rsync -avz -e "$rsync_ssh" "$SERVER_USER@$SERVER_HOST:$src" "$dst" >> "$tmp_log" 2>&1
    status=$?
    if [ $status -eq 0 ]; then
        printf 'ok: %s\n' "$src" >> "$tmp_log"
    else
        printf 'fail: %s (status=%s)\n' "$src" "$status" >> "$tmp_log"
    fi
done < "$tmp_csv"

color_blue "sending log to server"
"${ssh_cmd[@]}" "$SERVER_USER@$SERVER_HOST" "mkdir -p \"$remote_log_dir\""
"${scp_cmd[@]}" "$tmp_log" "$SERVER_USER@$SERVER_HOST:$remote_log_dir/$remote_log_file"

rm -f "$tmp_csv" "$tmp_log"
color_green "done"
