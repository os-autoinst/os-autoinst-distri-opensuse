# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: console test pre setup, performing actions required to run tests
# which are supposed to be reverted e.g. stoping and disabling packagekit and so on
# Permanent changes are now executed in system_prepare module
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "consoletest";
use testapi;
use utils;
use ipmi_backend_utils 'use_ssh_serial_console';
use strict;

sub disable_bash_mail_notification {
    assert_script_run "unset MAILCHECK >> ~/.bashrc";
    assert_script_run "unset MAILCHECK";
}

sub run {
    my $self = shift;
    # let's see how it looks at the beginning
    save_screenshot;
    check_var("BACKEND", "ipmi") ? use_ssh_serial_console : select_console 'root-console';
    disable_bash_mail_notification;
    # Stop serial-getty on serial console to avoid serial output pollution with login prompt
    # Doing early due to bsc#1103199 and bsc#1112109
    systemctl "stop serial-getty\@$testapi::serialdev", ignore_failure => 1;
    systemctl "disable serial-getty\@$testapi::serialdev";
    # Mask if is qemu backend as use serial in remote installations e.g. during reboot
    systemctl "mask serial-getty\@$testapi::serialdev" if check_var('BACKEND', 'qemu');
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

    # Installing a minimal system gives a pattern conflicting with anything not minimal
    # Let's uninstall 'the pattern' (no packages affected) in order to be able to install stuff
    script_run 'rpm -qi patterns-openSUSE-minimal_base-conflicts && zypper -n rm patterns-openSUSE-minimal_base-conflicts';
    # Install curl and tar in order to get the test data
    zypper_call 'install curl tar';
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
    disable_bash_mail_notification;
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
