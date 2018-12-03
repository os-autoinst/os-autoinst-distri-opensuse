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
use testapi;
use utils;

sub run {
    select_console 'root-console';
    my $repo_num = script_output 'zypper lr --uri | grep "hd:///?device=/dev/disk/by-id/usb-" | awk \'{print $1}\'';
    if ($repo_num !~ /^\d+$/) {
        record_info("Serial polluted", "Serial output was polluted: Assuming first repo is USB", result => 'fail');
        $repo_num = 1;
    }
    zypper_call("mr -e $repo_num");
}

1;
