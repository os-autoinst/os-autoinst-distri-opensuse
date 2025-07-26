# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Ensure USB installation repo is enabled for the case we want to use
#   it to install additional packages.
# Maintainer: QE Core <qe-core@suse.de>
# Tags: bsc#1012258

use base "consoletest";
use testapi;
use utils;

sub run {
    select_console 'root-console';
    my $flavor = get_var("FLAVOR");
    my $repo_num;
    # In case of Full medium, test skips registration so all module repo URIs point to USB drive.
    if ($flavor eq "Full") {
        my $sle_prod = uc get_var('SLE_PRODUCT') . get_var('VERSION');
        $repo_num = script_output "zypper lr --uri | grep \"$sle_prod\" | awk \'\$0 ~ /hd:\\/(\\/\\/)?\\?device=\\/dev\\/disk\\/by-id\\/usb-/ {print \$1}\'";
    }
    else {
        $repo_num = script_output 'zypper lr --uri | awk \'$0 ~ /hd:\/(\/\/)?\?device=\/dev\/disk\/by-id\/usb-/ {print $1}\'';
    }
    if ($repo_num !~ /^\d+$/) {
        record_info("Serial polluted", "Serial output was polluted: Assuming first repo is USB", result => 'fail');
        $repo_num = 1;
    }
    zypper_call("mr -e $repo_num");

}

1;
