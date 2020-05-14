# SUSE's SLES4SAP openQA tests
#
# Copyright (C) 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Perform an horizontal migration from SLES to SLES4SAP
# Maintainer: Ricardo Branco <rbranco@suse.de>

use base 'sles4sap';
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';
use registration qw(cleanup_registration register_product);

sub run {
    my ($self)  = @_;
    my $regcode = get_required_var('SCC_REGCODE_SLES4SAP');
    my $cmd     = '/usr/sbin/Migrate_SLES_to_SLES-for-SAP.sh';

    $self->select_serial_terminal;

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
    type_string "$cmd && touch /tmp/OK\n";
    wait_serial 'Do you want to continue\?', timeout => 5;
    type_string "y\n";
    wait_serial 'This script can use a local RMT or SMT', timeout => 5;
    type_string "c\n";    # Use SCC for now, TODO: add support for SMT/RMT
    wait_serial "Please enter the email address to be used to register", timeout => 5;
    type_string "\n";
    wait_serial "Please enter your activation code", timeout => 5;
    type_string "${regcode}\n";
    assert_script_run "ls /tmp/OK";
    zypper_call "in -y -t pattern sap_server";

    # We have now a SLES4SAP product, so we need to notify the test(s)
    set_var('SLE_PRODUCT', 'sles4sap');
}

sub test_flags {
    return {fatal => 1};
}

1;
