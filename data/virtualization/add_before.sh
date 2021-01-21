#!/bin/bash

if [[ $# -lt 2 ]]; then
	echo "Usage: $0 REGEX ADDBEFORE"
	echo "Prints the input stream and adds the line ADDBEFORE before the line that matches REGEX"
	exit 1
fi

regex="$1"
addbefore="$2"

matched=0
while read line; do
	if [[ "$line" =~ $regex ]]; then
		echo "$addbefore"
		matched=1
	fi
	echo "$line"
done

if [[ $matched == 0 ]]; then exit 1; fi