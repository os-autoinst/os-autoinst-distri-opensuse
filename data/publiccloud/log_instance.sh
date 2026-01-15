#!/bin/bash
# Continously read the serial console from a given publiccloud instance
# Usage: ./log_instance.sh (start|stop) (EC2|AZURE|GCE) <instance_id> <host> [zone]

COMMAND=$1
PROVIDER=$2
INSTANCE_ID=$3
HOST=$4
ZONE=$5
OUTPUT_DIR=/tmp/log_instance/"$INSTANCE_ID"
LOCK=${OUTPUT_DIR}/.lock
CNT_FILE=${OUTPUT_DIR}/.cnt
PID_FILE=${OUTPUT_DIR}/pid
EC2_DMESG_PID_FILE=${OUTPUT_DIR}/pid.ec2_dmesg
SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KMP_MERGE="$SCRIPT_DIR/kmp_merge"

ec2_is_running()
{
    [ -f "$PID_FILE" ] || return 1
    kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

ec2_dmesg_is_running() {
    [ -f "$EC2_DMESG_PID_FILE" ] || return 1
    kill -0 "$(cat "$EC2_DMESG_PID_FILE")" 2>/dev/null
}

ec2_start_dmesg() {
    inc_unique_counter

    # shellcheck disable=2086
    nohup ssh $SSH_OPTS "ec2-user@${HOST}" -- sudo dmesg -c -w \
        > "${OUTPUT_DIR}/${CNT}_dmesg.log" 2>&1 &

    echo $! > "$EC2_DMESG_PID_FILE"
}

ec2_stop_dmesg() {
    if ! ec2_dmesg_is_running; then
        rm -f "$EC2_DMESG_PID_FILE"
        return 0
    fi

    kill "$(cat "$EC2_DMESG_PID_FILE")" 2>/dev/null || true
    rm -f "$EC2_DMESG_PID_FILE"
}

trim_crlf_edges() {
    local f="$1"

    # trim leading CR/LF
    while [ -s "$f" ]; do
        first_hex=$(head -c 1 "$f" | od -An -tx1 | tr -d ' \n')
        case "$first_hex" in
            0a|0d)
                tail -c +2 "$f" > "$f.tmp" && mv "$f.tmp" "$f"
                ;;
            *)
                break
                ;;
        esac
    done

    # trim trailing CR/LF
    while [ -s "$f" ]; do
        last_hex=$(tail -c 1 "$f" | od -An -tx1 | tr -d ' \n')
        case "$last_hex" in
            0a|0d)
                truncate -s -1 "$f"
                ;;
            *)
                break
                ;;
        esac
    done
}

ec2_read_serial() {
    local cur="${OUTPUT_DIR}/ec2.cur"
    local out="${OUTPUT_DIR}/serial.out"
    local last_snapshot="${OUTPUT_DIR}/serial.last_snapshot"

    aws ec2 get-console-output \
        --instance-id "$INSTANCE_ID" \
        --latest \
        --query Output \
        --output text \
        > "$cur" 2>>"${OUTPUT_DIR}/stderr" || return 0

    local unix_timestamp formatted_timestamp
    unix_timestamp=$(date +%s)

    # UTC ISO-8601 with Z suffix
    formatted_timestamp=$(date -u -d "@$unix_timestamp" +"%Y-%m-%dT%H:%M:%SZ")

    trim_crlf_edges "$cur"

    if [ -f "$last_snapshot" ]; then
        if cmp -s "$cur" "$last_snapshot"; then
            rm -f "$cur"
            return 0
        fi
    fi

    cp "$cur" "$last_snapshot"

    if ! [ -f "$out" ]; then
        mv "$cur" "$out"
        return 0
    fi

    local inject
    inject=$'\n<<< CUTOFF '"$formatted_timestamp"$' >>>s\n'

    "$KMP_MERGE" "$out" "$cur" "$inject" > "${out}.tmp" && mv "${out}.tmp" "$out" && rm -f "$cur"
}

ec2_start_log()
{
    ec2_dmesg_is_running || ec2_start_dmesg

    ec2_is_running && exit 2
    ( while true; do ec2_read_serial; sleep 30; done; ) &
    echo $! > "$PID_FILE"
}

ec2_stop_log()
{
    ec2_is_running || true
    if ec2_is_running; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
    rm -f "${OUTPUT_DIR}/ec2.cur"
    rm -f "${OUTPUT_DIR}/serial.last_snapshot"
    rm -f "${CNT_FILE}"
    ec2_stop_dmesg
}

gce_read_serial()
{
    ( flock -w 10 -e 9 || exit 1;

        rstart=0
        tmpfile="${OUTPUT_DIR}/tmp.txt"
        ofile="${OUTPUT_DIR}/serial_port_1.log"
        errfile="${OUTPUT_DIR}/stderr"
        max_loop=42

        while [ $max_loop -gt 1 ] ; do
            max_loop=$((max_loop -1))
            [ -f "$errfile" ] &&
                rstart=$( grep -oP -- '--start=\d+' "$errfile" | grep -oP '\d+' || echo 0)

            gcloud compute instances get-serial-port-output "$INSTANCE_ID" --port 1 \
                --zone "$ZONE" --start="$rstart" > "$tmpfile" 2> "$errfile"
            grep 'WARNING:' "$errfile" >> "$ofile" || true
            newstart=$(grep -oP -- '--start=\d+' "$errfile" | grep -oP '\d+')
            if [ "$rstart" -eq "$newstart" ]; then
                rm "$tmpfile"
                break
            else
                cat "$tmpfile" >> "$ofile"
                rm "$tmpfile"
            fi
        done
    ) 9> "${LOCK}"
}

gce_is_running()
{
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(< "$PID_FILE");
        if kill -0 "$pid" > /dev/null 2>&1 ; then
            return 0;
        fi
    fi
    return 1
}

gce_start_log()
{
    gce_is_running && exit 2;
    ( while true; do gce_read_serial; sleep 30; done; ) &
    echo $! > "$PID_FILE"
}

gce_stop_log()
{
    # Use flock to wait max 60s that gce_read_serial() is ready. And kill during
    # the 30s sleep afterwards. If flock fail, just kill the bg process.
    (flock -w 60 -e 9 || exit 1
        gce_is_running && kill -9 "$(< "$PID_FILE" )"
        rm "$PID_FILE"
    ) 9> "${LOCK}"
}

azure_start_log()
{

    inc_unique_counter
    set +e
    az vm boot-diagnostics get-boot-log --ids "$INSTANCE_ID" > "${OUTPUT_DIR}/$CNT""_boot_log_start.txt" 2>&1
    set -e
    # shellcheck disable=2086
    nohup ssh $SSH_OPTS "azureuser@${HOST}" -- sudo dmesg -c -w > "${OUTPUT_DIR}/${CNT}_dmesg.log" 2>&1 &
    echo $! > "$PID_FILE"

    true;
}

azure_stop_log()
{
    read_unique_counter
    set +e
    # give some time for azure to write something
    sleep 30
    az vm boot-diagnostics get-boot-log --ids "$INSTANCE_ID" > "${OUTPUT_DIR}/$CNT""_boot_log_stop.txt" 2>&1
    set -e
    if [ -f "$PID_FILE" ]; then
      kill -9 "$(< "$PID_FILE")" || echo "Process already stopped"
      rm "$PID_FILE"
    fi
}

openstack_start_log()
{
    read_unique_counter
    set +e
    openstack server start "$INSTANCE_ID" > "${OUTPUT_DIR}/$CNT""_boot_log_start.txt" 2>&1
    set -e
}

openstack_stop_log()
{
    read_unique_counter
    set +e
    openstack server stop "$INSTANCE_ID" > "${OUTPUT_DIR}/$CNT""_boot_log_start.txt" 2>&1
    set -e
}

read_unique_counter()
{
    CNT=$(printf "%03d" "$(cat "$CNT_FILE" 2> /dev/null)")
}

inc_unique_counter()
{
    if [ -f "$CNT_FILE" ]; then
        CNT=$(( $(cat "$CNT_FILE") + 1 ))
        echo $CNT > "$CNT_FILE"
        CNT=$(printf "%03d" "$CNT")
    else
        CNT="000"
        echo 0 > "$CNT_FILE"
    fi
}

error() {
    local parent_lineno=$1
    local code=${2:-1}
    echo "Error on line ${parent_lineno}"
    exit "${code}"
}

trap 'error ${LINENO}' ERR
set -e

if [ $# -lt 4 ]; then
    echo  "$0 (start|stop) (EC2|AZURE|GCE) <instance_id> <host> [zone]"
    exit 2;
fi
mkdir -p "$OUTPUT_DIR"

case $PROVIDER in
    EC2)
        ec2_"${COMMAND}"_log
        ;;
    AZURE|Azure)
        azure_"${COMMAND}"_log
        ;;
    GCE)
        gce_"${COMMAND}"_log
        ;;
    OPENSTACK)
        openstack_"${COMMAND}"_log
        ;;
    *)
        echo "Unknown provider $PROVIDER given";
        exit 2;
        ;;
esac
