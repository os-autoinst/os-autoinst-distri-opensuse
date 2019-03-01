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
    my $cmd     = "/usr/sbin/Migrate_SLES_to_SLES_for_SAP.sh";

    select_console 'root-console';
    zypper_call "in -y migrate-sles-to-sles4sap";
    if (is_sle("15+")) {
        # Clean up and re-register not to affect other job which are sharing same qcow2
        cleanup_registration();
        register_product();
    } else {
        $cmd = "/usr/sbin/Migrate_SLES_to_SLES-for-SAP-12.sh";
    }
    type_string "$cmd && touch /tmp/OK\n";
    wait_serial 'Do you want to continue\?', timeout => 5;
    type_string "y\n";
    wait_serial 'Do you want to use a local [RS]MT server\?', timeout => 5;
    type_string "n\n";
    wait_serial "Please enter the email address to be used to register", timeout => 5;
    type_string "\n";
    wait_serial "Please enter your activation code", timeout => 5;
    type_string "${regcode}\n";
    assert_script_run "ls /tmp/OK";
    zypper_call "in -y -t pattern sap_server";
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'root-console';
    assert_script_run "save_y2logs /tmp/y2logs.tar.xz";
    upload_logs "/tmp/y2logs.tar.xz";
    $self->SUPER::post_fail_hook;
}

1;
