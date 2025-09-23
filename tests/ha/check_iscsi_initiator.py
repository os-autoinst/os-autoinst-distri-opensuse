# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify iSCSI Initiator Name is not the same on different installations
# Maintainer: qe-sap@suse.com

from testapi import *
from mmapi import get_current_job_id

perl.require("serial_terminal")
perl.require("power_action_utils")

def run(self):
    """
    NAME: ha/check_iscsi_initiator.py

    MAINTAINER: QE-SAP <qe-sap@suse.de>

    DESCRIPTION: verify iSCSI Initiator Name is not the same after different
                 installations.

                 This module needs to be scheduled at least 2 times in the
                 same test. On the first time it will store the iSCSI Initiator
                 Name from the SUT in a runtime setting, and on the second it
                 will compare the iSCSI Initiator Name from the SUT against the
                 stored in the setting. It will fail if both Initiator Names are
                 the same.

                 It is expected that this module is scheduled after different
                 installations. If scheduled twice after the same installation,
                 it will fail.

                 iSCSI Initiator Name is assumed to be stored in
                 /etc/iscsi/initiatorname.iscsi. If the file does not exist, assume
                 no Initiator Name is configured by default and exit successfully.

    OPENQA SETTINGS:

    * INST_AUTO: setting providing agama with an unattended JSONnet file.

    * ISCSI_INITIATOR_{jobid}: runtime setting where the initiator from the first
                               installation is stored.
    """
    perl.serial_terminal.select_serial_terminal()
    iscsi_initiator_file = "/etc/iscsi/initiatorname.iscsi"

    # Verify if a default iSCSI initiator is set on the SUT
    if (not script_run(f"test -f {iscsi_initiator_file}")):
        record_info("No iSCSI Initiator", f"SUT has no {iscsi_initiator_file}")
        # If the iSCSI initiator is not set, there is nothing to verify
        # Finish successfully
        return 1

    # Retrieve initiator from SUT. Only one initiator name is expected per file,
    # fail if more than one is found
    sut_initiator = script_output(f'echo "@$(grep ^InitiatorName {iscsi_initiator_file})@"')
    if (sut_initiator.count("InitiatorName=") > 1):
        record_info(iscsi_initiator_file, script_output(f"cat {iscsi_initiator_file}"))
        exit(f"More than one InitiatorName defined in {iscsi_initiator_file}")
    sut_initiator = sut_initiator.split("@")[1].split("InitiatorName=")[-1]

    # Retrieve initiator from previous installation, if it exists
    jobid = get_current_job_id()
    iscsi_chk_setting_name = f"ISCSI_INITIATOR_{jobid}"
    saved_initiator = get_var(iscsi_chk_setting_name, "")

    if (not saved_initiator):
        # Running for the first time
        set_var(iscsi_chk_setting_name, sut_initiator)

        # After the first time this module is scheduled, next modules should
        # reinstall the SUT to confirm the iSCSI Initiator from both installations
        # are different. How reinstallation is performed, depends on the
        # backend. Below is code for qemu and svirt/s390x where this was tested
        if (check_var("BACKEND", "qemu")):
            # On qemu, reboot the SUT to re-install. As next module expects the
            # SUT to be in a grub menu, assert the grub screen here first,
            # and move the highlighted option down and up to disable the
            # timeout
            perl.power_action_utils.power_action("reboot", "textmode", 1)
            assert_screen("grub-menu-first-entry-highlighted")
            send_key("down")
            send_key("up")
        elif (check_var("BACKEND", "svirt") and check_var("ARCH", "s390x")):
            # On s390x over svirt, poweroff the SUT. Next modules will handle
            # the power on and installation
            perl.power_action_utils.power_action("poweroff", "textmode", 1)
        else:
            # For the time being, test is not expected to be scheduled in other backends
            exit("Test module expected to work only on qemu and svirt backends")

        # INST_AUTO Hack: INST_AUTO gets overwritten by yam/agama/boot_agama
        # prepending to it the value of autoinst_url + '/files/'. The lines
        # below remove this from the INST_AUTO setting so yam/agama/boot_agama
        # can work twice in the same test suite/schedule
        inst_auto = get_var("INST_AUTO", "")
        set_var("INST_AUTO", inst_auto.replace(autoinst_url("/files/"), ""))
    else:
        if (sut_initiator == saved_initiator):
            exit(f"Initiator name was the same in 2 installations: [{sut_initiator}]")
        record_info("iSCSI Initiator", f"From first install:\t[{saved_initiator}].\nFrom latest install:\t[{sut_initiator}]")

def test_flags(self):
    return {'fatal': 1, 'milestone': 1}

