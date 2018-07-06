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
    ensure_serialdev_permissions;
    script_run 'echo "set -o pipefail" >> /etc/bash.bashrc.local';
    script_run '. /etc/bash.bashrc.local';
    # Export the existing status of running tasks and system load for future reference (fail would export it again)
    script_run "ps axf > /tmp/psaxf.log";
    script_run "cat /proc/loadavg > /tmp/loadavg_consoletest_setup.txt";

    # Just after the setup: let's see the network configuration
    script_run "ip addr show";
    save_screenshot;

    # Stop serial-getty on serial console to avoid serial output pollution with login prompt
    # Mask and stop only if SERIALDEV is defined or is qemu backend
    my $serial_console = get_var('SERIALDEV') || (check_var('BACKEND', 'qemu') ? 'ttyS0' : undef);
    if ($serial_console) {
        systemctl "mask serial-getty\@$serial_console";
        systemctl "stop serial-getty\@$serial_console";
    }

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

    # BSC#997263 - VMware screen resolution defaults to 800x600
    if (check_var('VIRSH_VMM_FAMILY', 'vmware')) {
        assert_script_run("sed -ie '/GFXMODE=/s/=.*/=1024x768x32/' /etc/default/grub");
        assert_script_run("sed -ie '/GFXPAYLOAD_LINUX=/s/=.*/=1024x768x32/' /etc/default/grub");
        assert_script_run("grub2-mkconfig -o /boot/grub2/grub.cfg");
    }

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
