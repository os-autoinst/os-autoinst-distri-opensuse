#!/bin/bash

# exit when any command fails
# set -e

device=/dev/ttyUSB0
speed=115200

# Set up device
stty -F $device $speed -echo -icrnl -onlcr -icanon

# Read the device $device in the background
# tail -f $device &
cat < $device &

# Capture PID of background process so it is possible to terminate it when done
bgPid=$!

trap cleanup SIGINT SIGTERM SIGKILL

cleanup()
{
  # Terminate background read process
  kill $bgPid
  exit 1
}

# Read commands from user, send them to device $device
while read cmd
do
   echo "$cmd" 
done > $device

cleanup;
