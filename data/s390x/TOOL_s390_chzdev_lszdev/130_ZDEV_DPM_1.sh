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

initialSetup() {
	local PACKAGE;

	# vim-common:     includes xxd which is required to translate hex to binary.
	# s390utils-base: obvious
	local PACKAGES=( "vim-common" \
	                 "s390utils-base");
	if ! command -v 'upm' &>/dev/null; then
		/upm/upm.sh --create-symlink;
		assert_fail $? 0 "Setup upm symlink";
	else
		echo "UPM already setup";
	fi

	echo "Install required packages";
	for PACKAGE in "${PACKAGES[@]}"; do
		#Install one after the other because some
		#package managers are too stupid to return
		#a value !=0 if installation failed for one package
		#which was not found...
		upm install "${PACKAGE}";
		assert_fail $? 0 "UPM UPM installed ${PACKAGE}";
	done
}

verifyDASDDeviceDPM() {
	local FW_FILE;
	local DEVICE SETTING;
	FW_FILE="$(mktemp)";

	echo "DASD Devices:"
	for DEVICE in "${DASD_DEVICES[@]}"; do
		printf "\t%s\n" "$DEVICE";
	done
	echo "Settings:"
	for SETTING in "${DASD_SETTINGS[@]}"; do
		printf "\t%s\n" "${SETTING}";
	done
	echo;

	for DEVICE in "${DASD_DEVICES[@]}"; do
		# Without settings
		echo "Create firmware for device '${DEVICE}'";
		firmware::init;
		firmware::addDASDEntry "${DEVICE}" "" "0";
		firmware::build \
			| xxd -r -p \
			> "${FW_FILE}";
		[ -s "${FW_FILE}" ];
		assert_warn $? 0 "Firmware file created ('${FW_FILE}')";
		echo "Firmware:"
		xxd "${FW_FILE}";

		zdev::removeGeneratedUDevRules "AUTO-CONF";
		assert_exec 0 chzdev --import "${FW_FILE}" --auto-conf

		zdev::verifyUDevRuleExists "AUTO-CONF" "DASD" "${DEVICE}";
		assert_warn $? 0 "Auto configuration for DASD '${DEVICE}' exists";
		echo;

		# With settings
		for SETTING in "${DASD_SETTINGS[@]}"; do
			echo "Create firmware for device '${DEVICE}'";
			echo "Setting: ${SETTING}";
			firmware::init;
			firmware::initDeviceSettings;
			firmware::addDeviceSetting "${SETTING%%=*}" "${SETTING#*=}";
			firmware::addDASDEntry \
				"${DEVICE}" \
				"$(firmware::buildDeviceSettings)" \
				"0";
			firmware::build \
				| xxd -r -p \
				> "${FW_FILE}";
			[ -s "${FW_FILE}" ];
			assert_warn $? 0 "Firmware file created ('${FW_FILE}')";
			echo "Firmware:"
			xxd "${FW_FILE}";

			zdev::removeGeneratedUDevRules "AUTO-CONF";
			assert_exec 0 chzdev --import "${FW_FILE}" --auto-conf

			zdev::verifyUDevRuleExists "AUTO-CONF" "DASD" "${DEVICE}" "${SETTING}";
			assert_warn $? 0 "Auto configuration for DASD '${DEVICE}' => '${SETTING}' exists";
			echo;
		done
	done

	[ -s "${FW_FILE}" ] && rm -f "${FW_FILE}";
	assert_warn $? 0 "Temp file '${FW_FILE}' removed";
}

verifyQETHDeviceDPM() {
	local FW_FILE;
	local DEVICE SETTING;
	FW_FILE="$(mktemp)";

	echo "QETH Devices:"
	for DEVICE in "${QETH_DEVICES[@]}"; do
		printf "\t%s\n" "$DEVICE";
	done
	echo "Settings:"
	for SETTING in "${QETH_SETTINGS[@]}"; do
		printf "\t%s\n" "${SETTING}";
	done
	echo;

	for DEVICE in "${QETH_DEVICES[@]}"; do
		# Without settings
		echo "Create firmware for device '${DEVICE}'";
		firmware::init;
		firmware::addQETHEntry "${DEVICE}" "" "0";
		firmware::build \
			| xxd -r -p \
			> "${FW_FILE}";
		[ -s "${FW_FILE}" ];
		assert_warn $? 0 "Firmware file created ('${FW_FILE}')";
		echo "Firmware:"
		xxd "${FW_FILE}";

		zdev::removeGeneratedUDevRules "AUTO-CONF";
		assert_exec 0 chzdev --import "${FW_FILE}" --auto-conf

		zdev::verifyUDevRuleExists "AUTO-CONF" "QETH" "${DEVICE}";
		assert_warn $? 0 "Auto configuration for QETH '${DEVICE}' exists";
		echo;

		# With settings
		for SETTING in "${QETH_SETTINGS[@]}"; do
			echo "Create firmware for device '${DEVICE}'";
			echo "Setting: ${SETTING}";

			firmware::init;
			firmware::initDeviceSettings;
			firmware::addDeviceSetting "${SETTING%%=*}" "${SETTING#*=}";
			firmware::addQETHEntry \
				"${DEVICE}" \
				"$(firmware::buildDeviceSettings)";
			firmware::build \
				| xxd -r -p \
				> "${FW_FILE}";
			[ -s "${FW_FILE}" ];
			assert_warn $? 0 "Firmware file created ('${FW_FILE}')";
			echo "Firmware:"
			xxd "${FW_FILE}";

			zdev::removeGeneratedUDevRules "AUTO-CONF";
			assert_exec 0 chzdev --import "${FW_FILE}" --auto-conf

			zdev::verifyUDevRuleExists "AUTO-CONF" "QETH" "${DEVICE}" "${SETTING}";
			assert_warn $? 0 "Auto configuration for QETH '${DEVICE}' => '${SETTING}' exists";
			echo;
		done
	done

	[ -s "${FW_FILE}" ] && rm -f "${FW_FILE}";
	assert_warn $? 0 "Temp file '${FW_FILE}' removed";
}

verifyZFCPHostDeviceDPM() {
	local FW_FILE;
	local DEVICE SETTING;
	FW_FILE="$(mktemp)";

	echo "ZFCP Devices:"
	for DEVICE in "${ZFCP_HOST_DEVICES[@]}"; do
		printf "\t%s\n" "$DEVICE";
	done
	echo "Settings:"
	for SETTING in "${ZFCP_HOST_SETTINGS[@]}"; do
		printf "\t%s\n" "${SETTING}";
	done
	echo;

	for DEVICE in "${ZFCP_HOST_DEVICES[@]}"; do
		# Without settings
		echo "Create firmware for device '${DEVICE}'";
		firmware::init;
		firmware::addZFCPHostEntry "${DEVICE}" "" "0";
		firmware::build \
			| xxd -r -p \
			> "${FW_FILE}";
		[ -s "${FW_FILE}" ];
		assert_warn $? 0 "Firmware file created ('${FW_FILE}')";
		echo "Firmware:"
		xxd "${FW_FILE}";

		zdev::removeGeneratedUDevRules "AUTO-CONF";
		assert_exec 0 chzdev --import "${FW_FILE}" --auto-conf

		zdev::verifyUDevRuleExists "AUTO-CONF" "ZFCP-HOST" "${DEVICE}";
		assert_warn $? 0 "Auto configuration for ZFCP-HOST '${DEVICE}' exists";
		echo;

		# With settings
		for SETTING in "${ZFCP_HOST_SETTINGS[@]}"; do
			echo "Create firmware for device '${DEVICE}'";
			echo "Setting: ${SETTING}";

			firmware::init;
			firmware::initDeviceSettings;
			firmware::addDeviceSetting "${SETTING%%=*}" "${SETTING#*=}";
			firmware::addZFCPHostEntry \
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

			zdev::verifyUDevRuleExists "AUTO-CONF" "ZFCP-HOST" "${DEVICE}" "${SETTING}";
			assert_warn $? 0 "Auto configuration for ZFCP-HOST '${DEVICE}' => '${SETTING}' exists";
			echo;
		done
	done

	[ -s "${FW_FILE}" ] && rm -f "${FW_FILE}";
	assert_warn $? 0 "Temp file '${FW_FILE}' removed";
}
