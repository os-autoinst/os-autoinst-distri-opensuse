# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
# set -x

# Need to run this test as root user
###############################################################################
# How to run?  -  ./safeoffline.sh
###############################################################################

for f in lib/*.sh; do source $f; done
source ./safeoffline-1.sh || exit 1
source ./safeoffline-2.sh || exit 1

########################################################################################
# Start
########################################################################################

init_tests

start_section 0  "TOOL: safeoffline test"
echo "#####################################################################################################################################################"
echo "#                   NOTE                                        NOTE                                         NOTE"
echo "# Intension of this test is to cover the important aspect of safeoffline and to keep the tests simple and to the point."
echo "# For a complete set of regresive test you should also consider below Test scenario (which are good to have) as part of manual tests which is not covered in this ATC"
echo "# 1. Error injection tests"
echo "# 2. Reservation tests"
echo "# 3. SSD, 1 TB, Tapes, LVM, CMS disk, FBA, minidisks, parallel safeoffline"
echo "# 4. Dynamic Hyper PAV safeoffline"
echo "# 5. disabling high performance feature tests."
echo "# REFER TO RQM for manual steps related at 706 :LS1215 - safe offline interface for DASD devices* LS1215 - safe offline interface for DASD devices "
echo "#####################################################################################################################################################"

DEVICE=$1
DEV_HPAV=$4
DEV_HPALIAS=$5
SCSI=$6
if [ "$2" != "tbd" ]; then
    DEV_PAV=$2;
    DEV_PALIAS=$3
else
    echo "Parameter for DEV_PAV is: $DEV_PAV";
    echo "Skipping tests for DEV_PAV and DEV_PALIAS";
fi

initDeviceSetup;
verifySafeOfflineSupport;
verifySafeOfflinePAVAndAliasDevices;
# verifySafeOfflineHyperPAVAndAliasDevices;
# verifyErrorConditions;
verifySafeOfflineWithSysfs;
# verifySafeOfflineWithNonDASD;
verifySafeOfflineDataIntegrity;
verifySafeOfflineWithSysfsFailFast;

cleanup;

end_section 0
show_test_results
