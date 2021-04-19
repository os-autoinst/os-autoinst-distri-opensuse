#!/bin/bash
# add_before.sh REGEX ADDBEFORE
# Reads from stdin line by line and prints the given parameter 'ADDBEFORE' before the line matching REGEX
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

if [[ $# -lt 2 ]]; then
	echo "Usage: $0 REGEX ADDBEFORE"
	echo "Prints the input stream and adds the line ADDBEFORE before the line matching REGEX"
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