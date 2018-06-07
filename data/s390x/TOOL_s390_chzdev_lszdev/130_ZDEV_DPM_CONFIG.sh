# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash

################################################################################
# DASD Config
################################################################################
DASD_DEVICES=(
	"0.0.0000" "0.0.ffff" \
	"0.1.0000" "0.1.ffff" \
	"0.2.0000" "0.2.ffff" \
	"0.3.0000" "0.3.ffff" );

DASD_SETTINGS=( \
	"online=0" \
	"online=1" \
	"cmb_enable=0" \
	"cmb_enable=1" \
	"failfast=0" \
	"failfast=1" \
	"readonly=0" \
	"readonly=1" \
	"erplog=0" \
	"erplog=1" \
	"expires=1" \
	"expires=40000000" \
	"retries=0" \
	"retries=1" \
	"timeout=0" \
	"timeout=1" \
	"reservation_policy=ignore" \
	"reservation_policy=fail" \
	"last_known_reservation_state=0" \
	"last_known_reservation_state=1" \
	#"safe_offline=0" \
	#"safe_offline=1" \
	"zdev:early=0" \
	"zdev:early=1" \
	);
isVM && DASD_SETTINGS+=( "use_diag=0" "use_diag=1" );

DASD_ECKD_SETTINGS=( \
	"raw_track_access=0" \
	"raw_track_access=1" \
	"eer_enabled=0" \
	"eer_enabled=1" \
	);

################################################################################
# QETH Config
################################################################################
QETH_DEVICES=(
	"0.0.0000" "0.0.fffd" \
	"0.1.0000" "0.1.fffd" \
	"0.2.0000" "0.2.fffd" \
	"0.3.0000" "0.3.fffd" );

QETH_SETTINGS=( \
	"online=0" \
	"online=1" \
	"layer2=0" \
	"layer2=1" \
	"portname=TEST" \
	"portname=" \
	"priority_queueing=no_prio_queueing" \
	"priority_queueing=prio_queueing_vlan" \
	"priority_queueing=prio_queueing_skb" \
	"priority_queueing=prio_queueing_prec" \
	"buffer_count=8" \
	"buffer_count=128" \
	"portno=0" \
	"portno=1" \
	"hsuid=0" \
	"hsuid=1" \
	#"recover=0" \
	#"recover=1" \
	"isolation=none" \
	"isolation=drop" \
	"isolation=forward" \
	"performance_stats=0" \
	"performance_stats=1" \
	"hw_trap=disarm" \
	"hw_trap=arm" \
	"hw_trap=trap" \
	"route4=no_router" \
	"route4=multicast_router" \
	"route4=primary_router" \
	"route4=secondary_router" \
	"route4=primary_connector" \
	"route4=secondary_connector" \
	"route6=no_router" \
	"route6=multicast_router" \
	"route6=primary_router" \
	"route6=secondary_router" \
	"route6=primary_connector" \
	"route6=secondary_connector" \
	"fake_broadcast=0" \
	"fake_broadcast=1" \
	#"ipa_takeover/enable=0" \
	#"ipa_takeover/enable=1" \
	#"ipa_takeover/add4=0" \
	#"ipa_takeover/add4=1" \
	#"ipa_takeover/add6=0" \
	#"ipa_takeover/add6=1" \
	#"ipa_takeover/del4=0" \
	#"ipa_takeover/del4=1" \
	#"ipa_takeover/del6=0" \
	#"ipa_takeover/del6=1" \
	#"ipa_takeover/invert4=0" \
	#"ipa_takeover/invert4=1" \
	#"ipa_takeover/invert6=0" \
	#"ipa_takeover/invert6=1" \
	#"rxip/add4=0" \
	#"rxip/add4=1" \
	#"rxip/add6=0" \
	#"rxip/add6=1" \
	#"rxip/del4=0" \
	#"rxip/del4=1" \
	#"rxip/del6=0" \
	#"rxip/del6=1" \
	"sniffer=0" \
	"sniffer=1" \
	#"vipa/add4=0" \
	#"vipa/add4=1" \
	#"vipa/add6=0" \
	#"vipa/add6=1" \
	#"vipa/del4=0" \
	#"vipa/del4=1" \
	#"vipa/del6=0" \
	#"vipa/del6=1" \
	#"bridge_role=0" \
	#"bridge_role=1" \
	#"bridge_hostnotify=0" \
	#"bridge_hostnotify=1" \
	#"bridge_reflect_promisc=0" \
	#"bridge_reflect_promisc=1" \
	#"vnicc/flooding=0" \
	#"vnicc/flooding=1" \
	#"vnicc/mcast_flooding=0" \
	#"vnicc/mcast_flooding=1" \
	#"vnicc/learning=0" \
	#"vnicc/learning=1" \
	#"vnicc/learning_timeout=0" \
	#"vnicc/learning_timeout=1" \
	#"vnicc/takeover_setvmac=0" \
	#"vnicc/takeover_setvmac=1" \
	#"vnicc/takeover_learning=0" \
	#"vnicc/takeover_learning=1" \
	#"vnicc/bridge_invisible=0" \
	#"vnicc/bridge_invisible=1" \
	#"vnicc/rx_bcast=0" \
	#"vnicc/rx_bcast=1" \
	"zdev:early=0" \
	"zdev:early=1" \
	);

################################################################################
# zFCP Host only Config
################################################################################
ZFCP_HOST_DEVICES=(
	"0.0.0000" "0.0.ffff" \
	"0.1.0000" "0.1.ffff" \
	"0.2.0000" "0.2.ffff" \
	"0.3.0000" "0.3.ffff" );

ZFCP_HOST_SETTINGS=( \
	"online=0" \
	"online=1" \
	"cmb_enable=0" \
	"cmb_enable=1" \
	#"failed=0" \
	#"failed=1" \
	#"port_remove=0" \
	#"port_remove=1" \
	#"port_rescan=0" \
	#"port_rescan=1" \
	"zdev:early=0" \
	"zdev:early=1" \
	);
ZFCP_LUN_SETTINGS=( \
	#"failed=0" \
	#"failed=1" \
	"scsi_dev/queue_depth=0" \
	"scsi_dev/queue_depth=1" \
	"scsi_dev/queue_ramp_up_period=0" \
	"scsi_dev/queue_ramp_up_period=1" \
	"scsi_dev/rescan=0" \
	"scsi_dev/rescan=1" \
	"scsi_dev/timeout=0" \
	"scsi_dev/timeout=1" \
	"scsi_dev/state=0" \
	"scsi_dev/state=1" \
	"scsi_dev/delete=0" \
	"scsi_dev/delete=1" \
	"zdev:early=0" \
	"zdev:early=1" \
	);

################################################################################
# zFCP Host and Lun Config
################################################################################
ZFCP_HOST_LUN_DEVICES=(
	"0.0.0000:0x0000000000000000:0x0000000000000000" \
	"0.0.0000:0x0000000000000000:0x0000000000000000" \
	"0.0.0000:0x0000000000000000:0x0000000000000000" \
	"0.0.0000:0x0000000000000000:0x0000000000000000" \
	"0.0.0000:0x0000000000000000:0x0000000000000000" \
	"0.0.0000:0x0000000000000000:0x0000000000000000" \
	"0.0.0000:0x0000000000000000:0x0000000000000000" \
	"0.0.0000:0x0000000000000000:0x0000000000000000" );
ZFCP_HOST_LUN_SETTINGS=( \
	#"failed=0" \
	#"failed=1" \
	"scsi_dev/queue_depth=1" \
	"scsi_dev/queue_depth=300" \
	"scsi_dev/queue_ramp_up_period=1" \
	"scsi_dev/queue_ramp_up_period=200" \
	# "scsi_dev/rescan=1" \
	"scsi_dev/timeout=1" \
	"scsi_dev/timeout=500" \
	#"scsi_dev/state=running" \
	#"scsi_dev/state=offline" \
	"scsi_dev/delete=1" \
	);

################################################################################
# Devices for lszdev tests
################################################################################
LSZDEV_DEVICES=(
	"AUTO-CONF;DASD;0.0.0000"
	"AUTO-CONF;DASD;0.0.1234"
	"AUTO-CONF;DASD;0.1.1234"
	"AUTO-CONF;DASD;0.0.fffd"
	"AUTO-CONF;DASD;0.2.fffd"
	"AUTO-CONF;QETH;0.0.0000"
	"AUTO-CONF;QETH;0.0.fffd"
	"AUTO-CONF;QETH;0.3.0000"
	"AUTO-CONF;QETH;0.2.fffd"
	"AUTO-CONF;ZFCP-HOST;0.0.0000"
	"AUTO-CONF;ZFCP-HOST;0.0.1800"
	"AUTO-CONF;ZFCP-HOST;0.0.ffff"
	"AUTO-CONF;ZFCP-HOST;0.1.0000"
	"AUTO-CONF;ZFCP-HOST;0.1.1800"
	"AUTO-CONF;ZFCP-HOST;0.2.1800"
	"AUTO-CONF;ZFCP-HOST;0.3.ffff"
	);

################################################################################
# Device configurations for zdev:early test
################################################################################
ZDEV_EARLY_DEVICES=(
	"DASD-ECKD;0.0.0000"
	"DASD-ECKD;0.0.1234"
	"DASD-ECKD;0.1.1234"
	"DASD-ECKD;0.0.fffd"
	"DASD-ECKD;0.2.fffd"
	"QETH;0.0.0000"
	"QETH;0.0.fffd"
	"QETH;0.3.0000"
	"QETH;0.2.fffd"
	"ZFCP-HOST;0.0.0000"
	"ZFCP-HOST;0.0.1800"
	"ZFCP-HOST;0.0.ffff"
	"ZFCP-HOST;0.1.0000"
	"ZFCP-HOST;0.1.1800"
	"ZFCP-HOST;0.2.1800"
	"ZFCP-HOST;0.3.ffff"
	);
