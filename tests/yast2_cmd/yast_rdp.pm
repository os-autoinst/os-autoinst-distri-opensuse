# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: this test checks that YaST2's RDP module is behaving
#          correctly in cmdline mode  and verifying that RDP service
#          has been successfully set.
# Maintainer: Jun Wang <jgwang@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';

    # prepare the setup for test, this test just supports sle15+.
    zypper_call("in yast2-rdp xrdp", exitcode => [0, 102, 103]);
    systemctl("stop xrdp.service",    ignore_failure => 1);
    systemctl("disable xrdp.service", ignore_failure => 1);

    # start xrdp service
    assert_script_run("yast rdp allow set=yes", fail_message => "yast rdp failed when starting xrdp service");

    # check if xrdp service starts.
    my $start  = systemctl('is-active xrdp.service',  ignore_failure => 1);
    my $enable = systemctl('is-enabled xrdp.service', ignore_failure => 1);
    if ($start or $enable) {
        die "yast rdp failed to start xrdp service";
    }

    # check yast rdp list
    validate_script_output 'yast rdp list 2>&1', sub { m/service is enabled/ };

    # stop xrdp service
    assert_script_run("yast rdp allow set=no", fail_message => "yast rdp failed when stopping xrdp service");

    # check if xrdp service stops.
    $start  = systemctl('is-active xrdp.service',  ignore_failure => 1);
    $enable = systemctl('is-enabled xrdp.service', ignore_failure => 1);
    if ($start != 3 or $enable != 1) {
        die "yast rdp failed to stop xrdp service";
    }

    # check yast rdp list
    validate_script_output 'yast rdp list 2>&1', sub { m/service is disabled/ };
}

1;
