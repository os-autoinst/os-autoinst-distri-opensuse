# SUSE's SLES4SAP openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Perform an horizontal migration from SLES to SLES4SAP
# Maintainer: QE-SAP <qe-sap@suse.de>, Ricardo Branco <rbranco@suse.de>
# Note: This test will pass if the migration from SLES to SLES4SAP is
#       successful, but as well if the SCC_REGCODE_SLES4SAP var holds
#       the special value "invalid_key" and the migrate-sles-to-sles4sap
#       script does a roll back to SLES.

use base 'sles4sap';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils 'is_sle';
use registration qw(cleanup_registration register_product);

sub run {
    my $regcode = get_required_var('SCC_REGCODE_SLES4SAP');
    my $cmd = '/usr/sbin/Migrate_SLES_to_SLES-for-SAP.sh';

    select_serial_terminal;

    # Clean up and re-register not to affect other job which are sharing same qcow2
    if (is_sle('15+')) {
        cleanup_registration();
        register_product();
    }

    # Check the build number, can useful for debugging!
    my $build_version = script_output('cat /etc/YaST2/build', proceed_on_failure => 1);
    record_info("Build version", "Build version installed: $build_version");

    # Install migration tool
    zypper_call 'in -y migrate-sles-to-sles4sap';

    # Do the migration!
    enter_cmd "$cmd && touch /tmp/OK";
    wait_serial 'Do you want to continue\?', timeout => 5;
    enter_cmd "y";
    wait_serial 'This script can use a local RMT or SMT', timeout => 5;
    enter_cmd "c";    # Use SCC for now, TODO: add support for SMT/RMT
    wait_serial "Please enter the email address to be used to register", timeout => 5;
    send_key 'ret';
    wait_serial "Please enter your activation code", timeout => 5;
    enter_cmd $regcode;

    # test either a failing migration or a working one
    if ($regcode eq "invalid_key") {
        wait_serial("Rolling back to", timeout => 20) || die "$cmd didn't roll back with an invalid key as expected.";
        assert_script_run "! test -f /tmp/OK";
    } else {
        assert_script_run "ls /tmp/OK";
        zypper_call "in -y -t pattern sap_server";
        # We have now a SLES4SAP product, so we need to notify the test(s)
        set_var('SLE_PRODUCT', 'sles4sap');
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
