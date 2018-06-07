# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
# Description:  writes a new configuration File for all Devices needed in test.
#

# Load testlib
for f in lib/*.sh; do source $f; done

start_section 0 "09 Overwrite config with given Parameters"

#only if all parameters are given, the config will be overwritten
if [[ $# -eq 20 ]];then
	cat <<-EOF > CONFIG.sh
	#!/bin/bash
	DASD="$1"
	DASD_CHPID="$2"

	DASD_ECKD="$3"
	DASD_ECKD_CHPID="$4"

	DASD_FBA="$5"
	DASD_FBA_CHPID="$6"

	ZFCP_H="$7"
	ZFCP_H_CHPID="$8"

	ZFCP_L="$9"
	ZFCP_L_CHPID="${10}"
	ZFCP_L_H="${9%%:*}"

	ZFCP_HOST="${11}"
	ZFCP_HOST_CHPID="${12}"

	ZFCP_LUN="${13}"
	ZFCP_LUN_CHPID="${14}"
	ZFCP_LUN_H="${13%%:*}"

	QETH="${15}"
	QETH_CHPID="${16}"
	ENCCW="${15%%:*}"

	CTC="${17}"
	CTC_IN="${17%%:*}"
	CTC_CHPID="${18}"

	LCS="${19}"
	LCS_IN="${19%%:*}"
	LCS_CHPID="${20}"

	GCCW="000e"
	EOF

	assert_warn 0 0 "New configuration file written"
else
	assert_warn 0 0 "Configuration remains untouched"
fi

end_section 0
exit 0
