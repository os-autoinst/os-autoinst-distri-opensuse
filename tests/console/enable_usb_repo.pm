# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Ensure USB installation repo is enabled for the case we want to use
#   it to install additional packages.
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: bsc#1012258

use base "consoletest";
use strict;
use warnings;
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
