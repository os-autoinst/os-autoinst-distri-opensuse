#!/bin/bash -e
# Bash script to forcefully reset a publiccloud VM
# Usage: ./restart_instance.sh (EC2|AZURE) <instance_id> <host>

check_ssh()
{
    nc -w1 -z "$1" 22
}

wait_for_power_off()
{
    local host=$1
    local tries=$2
    while check_ssh "$host"
    do
        tries=$((tries - 1))
        [ "$tries" -lt 1 ] && return 1;
        echo "waiting for power off"
        sleep 1;
    done
    return 0;
}

wait_for_power_on()
{
    local host=$1
    local tries=$2
    while ! check_ssh "$host"
    do
        tries=$((tries - 1))
        [ "$tries" -lt 1 ] && return 1;
        echo "waiting for power on"
        sleep 1;
    done
    return 0;
}

if [ $# -lt 3 ]; then
    echo  "$0 (EC2|AZURE) <instance_id> <host>"
    exit 2;
fi

PROVIDER=$1
INSTANCE_ID=$2
HOST=$3
ZONE=$4
CNT=120;
LOG_SCRIPT="./log_instance.sh"

test -x $LOG_SCRIPT && $LOG_SCRIPT stop "$PROVIDER" "$INSTANCE_ID" "$HOST" "$ZONE"

case $PROVIDER in
    EC2)
        aws ec2 reboot-instances  --instance-ids "$INSTANCE_ID"
        ;;
    AZURE)
        az vm restart --ids "$INSTANCE_ID" --no-wait
        ;;
    GCE)
        gcloud compute instances reset "$INSTANCE_ID" --zone "$ZONE"
        ;;
    OPENSTACK)
        openstack server reboot "$INSTANCE_ID"
        ;;
    *)
        echo "Unknown provider $PROVIDER given";
        exit 2;
        ;;
esac

wait_for_power_off "$HOST" "$CNT"
wait_for_power_on "$HOST" "$CNT"
echo "Instance $INSTANCE_ID restarted";
## Not needed, because the log_instance.sh does not depend on the running instance
## Leaving it here in case we need to revert it. If no issues arise, this can be
## removed after some time.
#test -x $LOG_SCRIPT && $LOG_SCRIPT start "$PROVIDER" "$INSTANCE_ID" "$HOST" "$ZONE"

