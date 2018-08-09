# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: console test pre setup, stoping and disabling packagekit, install curl and tar to get logs and so on
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "consoletest";
use testapi;
use utils;
use strict;

sub run {
    my $self = shift;
    # let's see how it looks at the beginning
    save_screenshot;

    select_console 'root-console';

    # init
    check_console_font;

    script_run 'echo "set -o pipefail" >> /etc/bash.bashrc.local';
    script_run '. /etc/bash.bashrc.local';
    # Export the existing status of running tasks and system load for future reference (fail would export it again)
    script_run "ps axf > /tmp/psaxf.log";
    script_run "cat /proc/loadavg > /tmp/loadavg_consoletest_setup.txt";

    # Just after the setup: let's see the network configuration
    script_run "ip addr show";
    save_screenshot;

    # Stop packagekit
    systemctl 'mask packagekit.service';
    systemctl 'stop packagekit.service';
    # upload_logs requires curl, but we wanted the initial state of the system
    upload_logs "/tmp/psaxf.log";
    upload_logs "/tmp/loadavg_consoletest_setup.txt";

    # https://fate.suse.com/320347 https://bugzilla.suse.com/show_bug.cgi?id=988157
    if (check_var('NETWORK_INIT_PARAM', 'ifcfg=eth0=dhcp')) {
        # grep all also compressed files e.g. y2log-1.gz
        assert_script_run 'less /var/log/YaST2/y2log*|grep "Automatic DHCP configuration not started - an interface is already configured"';
    }

    save_screenshot;
    $self->clear_and_verify_console;

    select_console 'user-console';

    assert_script_run "curl -L -v -f " . autoinst_url('/data') . " > test.data";
    assert_script_run " cpio -id < test.data";
    script_run "ls -al data";

    save_screenshot;
}

sub post_fail_hook {
    my $self = shift;

    $self->export_logs();
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
