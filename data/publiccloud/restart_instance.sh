#!/bin/bash -e

check_ssh()
{
    nc -w1 -z $1 22
}

wait_for_power_off()
{
    local host=$1
    local tries=$2
    while check_ssh $host
    do
        tries=$(( $tries - 1  ))
        [ $tries -lt 1 ] && return 1;
        echo "waiting for power off"
        sleep 1;
    done
    return 0;
}

wait_for_power_on()
{
    local host=$1
    local tries=$2
    while ! check_ssh $host
    do
        tries=$(( $tries - 1  ))
        [ $tries -lt 1 ] && return 1;
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
CNT=120;

case $PROVIDER in
    EC2)
        aws ec2 reboot-instances  --instance-ids $INSTANCE_ID
        ;;
    AZURE)
        az vm restart -g $INSTANCE_ID -n $INSTANCE_ID --no-wait
        ;;
    *)
        echo "Unknown provider $PROVIDER given";
        exit 2;
        ;;
esac

wait_for_power_off $HOST $CNT
wait_for_power_on $HOST $CNT
echo "Instance $INSTANCE_ID restarted";

