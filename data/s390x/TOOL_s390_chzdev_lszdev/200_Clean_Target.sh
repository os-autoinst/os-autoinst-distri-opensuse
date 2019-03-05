# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
# Script-Name: 200_Clean_Target.sh
#

# Load testlib
for f in lib/*.sh; do source $f; done
source "CONFIG.sh" || exit 1

# 1 Check prerequisites
start_section 0 "200 Clean Target"
	assert_exec 0 "chzdev $DASD $DASD_ECKD $DASD_FBA $ZFCP_H $ZFCP_L $ZFCP_HOST $ZFCP_LUN $CTC $LCS --remove-all"
	assert_exec 0 "chzdev $DASD $DASD_ECKD $DASD_FBA $ZFCP_H $ZFCP_L $ZFCP_HOST $ZFCP_LUN $CTC $LCS -d"
end_section 0
