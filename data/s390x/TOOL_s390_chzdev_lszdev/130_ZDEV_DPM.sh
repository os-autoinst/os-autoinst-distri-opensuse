# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
#		This script verifies that devices can be configured using the
#		device pre-configurations on DPM LPARs.
#
################################################################################

for f in lib/*.sh; do source $f; done


#Load configuration
# shellcheck disable=SC1091
common::source 130_ZDEV_DPM_CONFIG.sh || exit 1;
common::source CONFIG.sh || exit 1;

source ./130_ZDEV_DPM_1.sh || exit 1
source ./130_ZDEV_DPM_2.sh || exit 1
#DEVELOPMENTMODE="yes";

verifyFirmwareImportErrorConditions() {
	local FW_FILE;
	FW_FILE="$(mktemp)";

	# Import device /dev/null
	echo "Verify chzdev --import can handle /dev/null";
	expect <<-EOF
	set timeout 5;
	spawn chzdev --import /dev/null --auto-conf
	expect {
		"No settings found to import" { exit 0 }
		default { exit 1 }
	}
	EOF
	assert_warn $? 0 "chzdev --import properly handles empty file";
	echo

	# Setting length is 0
	echo "7a646576000000200000005100000000000000000001000000000000000000000004003100000001000000f5000000f5010000f5021d000601016c61796572320100080004706f72746e616d6554455354" \
		| xxd -r -p \
		> "${FW_FILE}";
	echo "Verify chzdev --import can handle setting length = 0";
	echo "Firmware:";
	xxd "${FW_FILE}";
	expect <<-EOF
	set timeout 10;
	spawn chzdev --import "${FW_FILE}" --auto-conf;
	expect {
		"Setting too short" { exit 0 }
		default { exit 1 }
	}
	EOF
	assert_warn $? 0 "chzdev --import properly handles empty file";
	echo

	# No device entries
	firmware::init;
	firmware::build | xxd -r -p > "${FW_FILE}";
	echo "Verify chzdev --import with 0 Device Entries";
	echo "Firmware:";
	xxd "${FW_FILE}";
	expect <<-EOF
	set timeout 10;
	spawn chzdev --import "${FW_FILE}" --auto-conf;
	expect {
		"No settings found to import" { exit 0 }
		default { exit 1 }
	}
	EOF
	assert_warn $? 0 "chzdev --import properly handles empty file";
	echo
}

verifyInitialRamDiskCompatibility() {
	local DRACUT_PARSE_ZDEV="/usr/lib/dracut/modules.d/95zdev/parse-zdev.sh";
	local DRACUT_MODULE_SETUP="/usr/lib/dracut/modules.d/95zdev/module-setup.sh";
	local INITRAMFS_HOOK="/usr/share/initramfs-tools/hooks/zdev";
	local INITRAMFS_SCRIPTS_INIT_TOP="/usr/share/initramfs-tools/scripts/init-top/zdev";

	case "$(common::getDistributionName)" in
		ubuntu.*)
			[[ -e "${INITRAMFS_HOOK}" && -e "${INITRAMFS_SCRIPTS_INIT_TOP}" ]];
			assert_warn $? 0 "Distributor has included initramfs required hook and init-top script";
			;;
		*)
			[[ -e "${DRACUT_PARSE_ZDEV}" && -e "${DRACUT_MODULE_SETUP}" ]];
			assert_warn $? 0 "Distributor has included dracut required '95zdev' module";
			;;
	esac;
}

verifyZDevEarlyExport() {
	local DEVICE;
	local DEVICE_CONFIG;
	local TEMP_FILE;

	echo "Remove generated UDev rules";
	zdev::removeGeneratedUDevRules "PERSISTENT";
	echo;

	for DEVICE_CONFIG in "${ZDEV_EARLY_DEVICES[@]}"; do
		IFS=';' read -r -a DEVICE <<< "${DEVICE_CONFIG}";
		case "${DEVICE[0]}" in
			QETH) assert_exec 0 chzdev -f -e "${DEVICE[0]}" "$(qeth::generateQETHDeviceIDs "${DEVICE[1]}" | tr ' ' ':')" "zdev:early=1" --persistent --no-root-update; ;;
			*) assert_exec 0 chzdev -f -e "${DEVICE[0]}" "${DEVICE[1]}" "zdev:early=1" --persistent --no-root-update; ;;
		esac
		zdev::verifyUDevRuleExists "PERSISTENT" "${DEVICE[0]}" "${DEVICE[1]}" "zdev:early=1";
		assert_fail $? 0 "UDev rule for ${DEVICE[0]} device '${DEVICE[1]}' created with 'zdev:early=1'";
		echo
	done
	echo;

	echo "Export persistent devices which have attribute 'zdev:early=1'";
	TEMP_FILE="$(mktemp)";
	chzdev --export - --by-attrib=zdev:early=1 --persistent --no-root-update \
		> "${TEMP_FILE}" 2>&1;
	echo;

	if [ ! -s "${TEMP_FILE}" ]; then
		assert_warn 1 0 "Failed to export persistent devices with attribute 'zdev:early=1'";
		return 1;
	fi
	for DEVICE_CONFIG in "${ZDEV_EARLY_DEVICES[@]}"; do
		IFS=';' read -r -a DEVICE <<< "${DEVICE_CONFIG}";
		case "${DEVICE[0]}" in
			QETH) grep -q "\[persistent $(echo "${DEVICE[0]}" | tr '[:upper:]' '[:lower:]') $(qeth::generateQETHDeviceIDs "${DEVICE[1]}" | tr ' ' ':')\]" "${TEMP_FILE}"; ;;
			*) grep -q "\[persistent $(echo "${DEVICE[0]}" | tr '[:upper:]' '[:lower:]') ${DEVICE[1]}\]" "${TEMP_FILE}"; ;;
		esac
		assert_warn $? 0 "'${DEVICE[0]}' device '${DEVICE[1]}' exported";
	done
	echo;

	[ -e "${TEMP_FILE}" ] && rm -f "${TEMP_FILE}";
	assert_warn $? 0 "Remove temp file '${TEMP_FILE}'";
	echo;

	echo "Remove generated UDev rules";
	zdev::removeGeneratedUDevRules "PERSISTENT";
	echo;
}

################################################################################
# Start
################################################################################
init_tests;
section_start "130 ZDEV DPM Tests"
if grep -q 130_ZDEV_DPM omit; then
	assert_exec 0 "echo 'skipping this section'"
	section_end;
	exit 0
fi

section_start "Initial setup";
initialSetup;
section_end;

section_start "Verify that the kernel supports device pre-configuration";
verifyDevicePreConfigurationIsSupported;
section_end;

section_start "Verify DASD device pre-configuration";
verifyDASDDeviceDPM;
section_end;

section_start "Verify QETH device pre-configuration";
verifyQETHDeviceDPM;
section_end;

section_start "Verify zFCP Host device pre-configuration";
verifyZFCPHostDeviceDPM;
section_end;

section_start "Verify zFCP Lun device pre-configuration";
verifyZFCPLunDeviceDPM;
section_end;

section_start "Verify lszdev recognizes device pre-configuration";
verifyLSZDEVDPM;
section_end;

section_start "Verify firmware max. device pre-configurations";
verifyFirmwareMaxDPMDevices;
section_end;

section_start "Verify chzdev --no-settle option";
verifyChzdevNoSetleOption;
section_end;

section_start "Verify device pre-configuration works with initramfs/dracut";
verifyInitialRamDiskCompatibility
section_end;

section_start "Verify chzdev --import error conditions";
verifyFirmwareImportErrorConditions;
section_end;

section_start "Verify chzdev can export 'zdev:early=1' devices";
verifyZDevEarlyExport;
section_end;

show_test_results;
section_end;
