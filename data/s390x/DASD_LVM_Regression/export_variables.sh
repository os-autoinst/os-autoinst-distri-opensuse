# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
BASE_RANGE=$1
ALIAS_RANGE=$2

_split_range(){

	SPLIT=""
        LSB=`echo $1 | awk -F "-" '{ printf $1 }' | tr '[:lower:]' '[:upper:]'`
        RSB=`echo $1 | awk -F "-" '{ printf $2 }' | tr '[:lower:]' '[:upper:]'`
	dec1=`echo  "ibase=16; $LSB" | bc`
	dec2=`echo  "ibase=16; $RSB" | bc`
	for (( i=$dec1 ; i<=$dec2; i++ ))
	do
		tmp=`echo "obase=16; $i" | bc`
		SPLIT="$SPLIT $tmp"
	done
}

_split_range $BASE_RANGE
export CONFIG_BASE_PAV=$SPLIT

_split_range $ALIAS_RANGE
export CONFIG_ALIAS_PAV=$SPLIT
