#!/bin/bash -x
# monitor_serial.sh
# Monitor virt-install process and get the serial output

GUEST_NAME=$1
LOG_DIR=$2

if [ -z "$GUEST_NAME" ] || [ -z "$LOG_DIR" ]; then
    echo "Usage: $0 <guest_name> <log_dir>"
    exit 1
fi

LOG_FILE="${LOG_DIR}/${GUEST_NAME}-serial.log"

mkdir -p "$LOG_DIR"
echo "[INFO] Monitor virt-install process and get the serial output"
echo "[INFO] Output will be saved to: $LOG_FILE"
echo "[$(date)] Starting serial monitor for Guest: $GUEST_NAME" >> "${LOG_FILE}"

(
    # Reconnect after guest shutting off
    while virsh dominfo "${GUEST_NAME}" >/dev/null 2>&1; do
        expect -c "
            set timeout 30
            spawn virsh console ${GUEST_NAME} --safe

            expect {
                timeout {
                    send \"\r\"
                    exp_continue
                }
                eof {
                    exit
                }
            }
        " >> "${LOG_FILE}" 2>&1
	sleep 2
    done
    echo "[$(date)] Domain ${GUEST_NAME} no longer exists. Stopping serial monitor." >> "${LOG_FILE}"
)&

disown
