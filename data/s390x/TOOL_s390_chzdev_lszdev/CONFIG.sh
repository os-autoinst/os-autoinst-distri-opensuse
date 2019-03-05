# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
# Script-Name: CONFIG.sh
#

DASD=xxxx
DASD_CHPID="00 00 00 00"

DASD_ECKD=xxx
DASD_ECKD_CHPID="00 00 00 00"

#only z/VM
DASD_FBA=0000
DASD_FBA_CHPID=00

ZFCP_H="0.0.0000"
ZFCP_H_CHPID=00

ZFCP_L="0.0.0000:0x0000000000000000:0x0000000000000000"
ZFCP_L_CHPID=00
ZFCP_L_H="$( cut -d ':' -f 1 <<< "$ZFCP_L" )";

ZFCP_HOST="0000"
ZFCP_HOST_CHPID=00

ZFCP_LUN="0000:0x0000000000000000:0x0000000000000000"
ZFCP_LUN_CHPID=00
ZFCP_LUN_H="$( cut -d ':' -f 1 <<< "$ZFCP_LUN" )";

QETH="0.0.0000:0.0.0000:0.0.0000"
QETH_CHPID=00
ENCCW="$( cut -d ':' -f 1 <<< "$QETH" )";
#only lpar
CTC="0.0.0000:0000"
CTC_IN="$( cut -d ':' -f 1 <<< "$CTC" )";
CTC_CHPID="00 00"

#only lpar
LCS="0000:0.0.0000"
LCS_IN="$( cut -d ':' -f 1 <<< "$LCS" )";
LCS_CHPID=00

#only z/VM
GCCW=0000
