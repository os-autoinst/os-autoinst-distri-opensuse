# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test packagehub repo on sle micro
#
# 1. Check if PackageHub extention is availble in sle micro
# 2. Activate PackageHub extention
# 3. Install a package from PackageHub repo
#
# Maintainer: qac <qa-c@suse.de>

package check_phub;
use base 'consoletest';
use strict;
use warnings;
use testapi;
use transactional qw(trup_call check_reboot_changes);

sub run {
    select_console 'root-console';
    my $out = script_output("transactional-update --quiet register --list-extensions|grep PackageHub", proceed_on_failure => 1);
    if ($out ne "") {    #check if PackageHub extension is available
        if ($out =~ /Activate with: transactional-update /p) {    #Check if it is activated
            trup_call("${^POSTMATCH}");
            check_reboot_changes;
        }
        trup_call("pkg install sshpass");
        check_reboot_changes;
        assert_script_run("rpm -q sshpass");
    }
    else {
        record_info('INFO', "PackageHub Unavaible");
    }
}

1;
