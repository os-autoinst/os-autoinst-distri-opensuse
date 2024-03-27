#!/bin/sh
mount -o remount,rw /
dmesg > /shutdown-log.txt
mount -o remount,ro /
