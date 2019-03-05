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

verifyZFCPLunDeviceDPM() {
	local FW_FILE;
	local DEVICE SETTING;
	FW_FILE="$(mktemp)";

	echo "ZFCP+Lun Devices:"
	for DEVICE in "${ZFCP_HOST_LUN_DEVICES[@]}"; do
		printf "\t%s\n" "$DEVICE";
	done
	echo "Settings:"
	for SETTING in "${ZFCP_HOST_LUN_SETTINGS[@]}"; do
		printf "\t%s\n" "${SETTING}";
	done
	echo;

	for DEVICE in "${ZFCP_HOST_LUN_DEVICES[@]}"; do
		# Without settings
		echo "Create firmware for device '${DEVICE}'";
		firmware::init;
		firmware::addZFCPLunEntry "${DEVICE}";
		firmware::build \
			| xxd -r -p \
			> "${FW_FILE}";
		[ -s "${FW_FILE}" ];
		assert_warn $? 0 "Firmware file created ('${FW_FILE}')";
		echo "Firmware:"
		xxd "${FW_FILE}";

		zdev::removeGeneratedUDevRules "AUTO-CONF";
		assert_exec 0 chzdev --import "${FW_FILE}" --auto-conf

		zdev::verifyUDevRuleExists "AUTO-CONF" "ZFCP-LUN" "${DEVICE}";
		assert_warn $? 0 "Auto configuration for ZFCP-LUN '${DEVICE}' exists";
		echo;

		# With settings
		for SETTING in "${ZFCP_HOST_LUN_SETTINGS[@]}"; do
			echo "Create firmware for device '${DEVICE}'";
			echo "Setting: ${SETTING}";

			firmware::init;
			firmware::initDeviceSettings;
			firmware::addDeviceSetting "${SETTING%%=*}" "${SETTING#*=}";
			firmware::addZFCPLunEntry \
				"${DEVICE}" \
				"$(firmware::buildDeviceSettings)";
			firmware::build \
				| xxd -r -p \
				> "${FW_FILE}";
			[ -e "${FW_FILE}" ];
			assert_warn $? 0 "Firmware file created";
			echo "Firmware:"
			xxd "${FW_FILE}";

			zdev::removeGeneratedUDevRules "AUTO-CONF";
			assert_exec 0 chzdev --import "${FW_FILE}" --auto-conf

			zdev::verifyUDevRuleExists "AUTO-CONF" "ZFCP-LUN" "${DEVICE}" "${SETTING}";
			assert_warn $? 0 "Auto configuration for ZFCP-LUN '${DEVICE}' => '${SETTING}' exists";
			echo;
		done
	done

	[ -s "${FW_FILE}" ] && rm -f "${FW_FILE}";
	assert_warn $? 0 "Temp file '${FW_FILE}' removed";
}

verifyLSZDEVDPM() {
	local FW_FILE;
	local DEVICE_CONFIG;
	local DEVICE;
	FW_FILE="$(mktemp)";

	#Build new firmware with all devices
	firmware::init;
	for DEVICE_CONFIG in "${LSZDEV_DEVICES[@]}"; do
		IFS=';' read -r -a DEVICE <<< "${DEVICE_CONFIG}";
		case "${DEVICE[1]}" in
			DASD)      firmware::addDASDEntry "${DEVICE[2]}"; ;;
			QETH)      firmware::addQETHEntry "${DEVICE[2]}"; ;;
			ZFCP-HOST) firmware::addZFCPHostEntry "${DEVICE[2]}"; ;;
			ZFCP-LUN)  firmware::addZFCPLunEntry "${DEVICE[2]}"; ;;
		esac
	done
	firmware::build \
		| xxd -r -p \
		> "${FW_FILE}";
	[ -s "${FW_FILE}" ];
	assert_warn $? 0 "Firmware file created ('${FW_FILE}')";
	echo "Firmware:"
	xxd "${FW_FILE}";

	#Import configuration
	zdev::removeGeneratedUDevRules "AUTO-CONF";
	chzdev --import "${FW_FILE}" --auto-conf;
	assert_warn $? 0 "Import firmware configuration";
	echo;

	#Verify config exists and lszdev
	for DEVICE_CONFIG in "${LSZDEV_DEVICES[@]}"; do
		IFS=';' read -r -a DEVICE <<< "${DEVICE_CONFIG}";

		zdev::verifyUDevRuleExists "${DEVICE[0]}" "${DEVICE[1]}" "${DEVICE[2]}";
		assert_warn $? 0 "Configuration '${DEVICE[0]}' for ${DEVICE[1]} '${DEVICE[2]}' exists";

		# Verify plain lszdev persistent column should print auto
		[[ "$(lszdev | awk -v TYPE="${DEVICE[1]}" -v DEV="${DEVICE[2]}" \
			' $1 ~ tolower(TYPE) && $2 ~ DEV { print $4 }')" =~ auto* ]];
		assert_warn $? 0 "lszdev found '${DEVICE[0]}' for  the '${DEVICE[1]}' device '${DEVICE[2]}'";

		# Verify [TYPE] [DEVICE]
		[[ "$(lszdev "${DEVICE[1]}" "${DEVICE[2]}" 2>/dev/null \
			| awk ' NR > 1 { print $4 }')" =~ auto* ]];
		assert_warn $? 0 "lszdev ${DEVICE[1]} ${DEVICE[2]} found '${DEVICE[0]}' for  the '${DEVICE[1]}' device '${DEVICE[2]}'";

		# Verify [TYPE] [DEVICE] --auto-conf
		[[ "$(lszdev "${DEVICE[1]}" "${DEVICE[2]}" --auto-conf 2>/dev/null \
			| awk ' NR > 1 { print $3 }')" =~ yes* ]];
		assert_warn $? 0 "lszdev ${DEVICE[1]} ${DEVICE[2]} --auto-conf found '${DEVICE[0]}' for  the '${DEVICE[1]}' device '${DEVICE[2]}'";

		# Verify [TYPE] [DEVICE] --info --auto-conf
		[[ "$(lszdev "${DEVICE[1]}" "${DEVICE[2]}" --info --auto-conf 2>/dev/null \
			| awk ' $1 == "Auto-configured" { print $3 }')" =~ yes* ]];
		assert_warn $? 0 "lszdev ${DEVICE[1]} ${DEVICE[2]} --info --auto-conf found '${DEVICE[0]}' for  the '${DEVICE[1]}' device '${DEVICE[2]}'";
		echo;
	done

	[ -s "${FW_FILE}" ] && rm -f "${FW_FILE}";
	assert_warn $? 0 "Temp file '${FW_FILE}' removed";
}

verifyFirmwareMaxDPMDevices() {
	local FW_FILE;
	local DEVID;
	local DASD_IDS=( $(zdev::generateDeviceIds "0.0.0000-0.0.0fff") );
	local QETH_IDS=( $(zdev::generateDeviceIds "0.1.1000-0.1.1fff") );
	local ZFCP_HOST_IDS=( $(zdev::generateDeviceIds "0.2.1000-0.2.1fff") );
	FW_FILE="$(mktemp)";

	#Build new firmware with all devices
	echo "Init firmware";
	firmware::init;

	echo "Add all DASD entries to firmware";
	for DEVID in "${DASD_IDS[@]}"; do
		#echo "Add DASD '${DEVID}' to the firmware";
		firmware::addDASDEntry "${DEVID}";
	done
	echo "Add all QETH entries to firmware";
	for DEVID in "${QETH_IDS[@]}"; do
		#echo "Add QETH '${DEVID}' to the firmware";
		firmware::addQETHEntry "${DEVID}";
	done
	echo "Add all zFCP-Host entries to firmware";
	for DEVID in "${ZFCP_HOST_IDS[@]}"; do
		#echo "Add zFCP-Host '${DEVID}' to the firmware";
		firmware::addZFCPHostEntry "${DEVID}";
	done

	echo "Build the firmware file";
	firmware::build \
		| xxd -r -p \
		> "${FW_FILE}";
	[ -s "${FW_FILE}" ];
	assert_warn $? 0 "Firmware file created ('${FW_FILE}')";
	echo "Firmware:"
	xxd "${FW_FILE}";

	#Import configuration
	zdev::removeGeneratedUDevRules "AUTO-CONF";
	chzdev --import "${FW_FILE}" --auto-conf;
	assert_warn $? 0 "Import firmware configuration";
	echo;

	#Verify DASD
	for DEVID in "${DASD_IDS[@]}"; do
		zdev::verifyUDevRuleExists "AUTO-CONF" "DASD" "${DEVID}";
		assert_warn $? 0 "Configuration 'AUTO-CONF' for DASD '${DEVID}' exists";
	done
	#Verify QETH
	for DEVID in "${QETH_IDS[@]}"; do
		zdev::verifyUDevRuleExists "AUTO-CONF" "QETH" "${DEVID}";
		assert_warn $? 0 "Configuration 'AUTO-CONF' for QETH '${DEVID}' exists";
	done
	#Verify ZFCP-HOST
	for DEVID in "${ZFCP_HOST_IDS[@]}"; do
		zdev::verifyUDevRuleExists "AUTO-CONF" "ZFCP-HOST" "${DEVID}";
		assert_warn $? 0 "Configuration 'AUTO-CONF' for ZFCP-HOST '${DEVID}' exists";
	done

	[ -s "${FW_FILE}" ] && rm -f "${FW_FILE}";
	assert_warn $? 0 "Temp file '${FW_FILE}' removed";
}

#shellcheck disable=2120
verifyChzdevNoSetleOption() {
	local DEVTYPE="dasd-eckd";

	if [ -z "${DASD}" ]; then
		assert_warn 1 0 "No DASD device configured for this test";
		return 1;
	fi

	# Deactivate device if activated
	if [[ "$(lszdev "${DEVTYPE}" "${DASD}" | awk ' NR > 1 { print $3 }')" == "yes" ]]; then
		chzdev -d "${DASD}";
		assert_warn $? 0 "Device '${DASD}' has been deactivated for this test";
	fi

	# With --no-settle
	# Verify that the device is deactivated
	[[ "$(lszdev "${DEVTYPE}" "${DASD}" | awk ' NR > 1 { print $3 }')" == "no" ]];
	assert_warn $? 0 "Device '${DASD}' is not active";

	# Verify that activating the device with --no-settle will not call 'udevadm settle'
	ltrace -b -e system -- chzdev -e --no-settle "${DASD}" 2>&1 | grep "udev";
	assert_warn $? 1 "chzdev activating '${DASD}' was not executing 'udevadm settle'";

	# Verify that the device is online again
	[[ "$(lszdev "${DEVTYPE}" "${DASD}" | awk ' NR > 1 { print $3 }')" == "yes" ]];
	assert_warn $? 0 "Device '${DASD}' is active";

	# Verify that deactivating the device with --no-settle will not call 'udevadm settle'
	ltrace -b -e system -- chzdev -d --no-settle "${DASD}" 2>&1 | grep "udev";
	assert_warn $? 1 "chzdev deactivating '${DASD}' was not executing 'udevadm settle'";

	# Verify that the device is offline again
	[[ "$(lszdev "${DEVTYPE}" "${DASD}" | awk ' NR > 1 { print $3 }')" == "no" ]];
	assert_warn $? 0 "Device '${DASD}' is not active";

	# Without --no-settle
	# Verify that activating the device with --no-settle will not call 'udevadm settle'
	ltrace -b -e system -- chzdev -e "${DASD}" 2>&1 | grep "udev";
	assert_warn $? 0 "chzdev activating '${DASD}' was executing 'udevadm settle'";

	# Verify that the device is online again
	[[ "$(lszdev "${DEVTYPE}" "${DASD}" | awk ' NR > 1 { print $3 }')" == "yes" ]];
	assert_warn $? 0 "Device '${DASD}' is active";

	# Deactivate again
	chzdev -d "${DASD}";
	assert_warn $? 0 "Device '${DASD}' has been deactivated again";

	# Verify that the device is offline again
	[[ "$(lszdev "${DEVTYPE}" "${DASD}" | awk ' NR > 1 { print $3 }')" == "no" ]];
	assert_warn $? 0 "Device '${DASD}' is not active";
}

verifyDevicePreConfigurationIsSupported() {
	[ -e "/sys/firmware/sclp_sd/config/data" ];
	assert_warn $? 0 "Firmware data is available in SysFS";

	echo "Current firmware(SysFS):"
	xxd "/sys/firmware/sclp_sd/config/data";

	[ -e "/sys/firmware/sclp_sd/config/reload" ];
	assert_warn $? 0 "Firmware reload is available in SysFS";

	echo > "/sys/firmware/sclp_sd/config/reload"
	assert_warn $? 0 "Firmware reload was accepted using SysFS";
}
