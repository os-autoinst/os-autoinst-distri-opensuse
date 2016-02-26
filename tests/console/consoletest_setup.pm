# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use testapi;
use utils;


sub run() {
    my $self = shift;

    # let's see how it looks at the beginning
    save_screenshot;

    if (!check_var('ARCH', 's390x')) {
        # verify there is a text console on tty1
        send_key_until_needlematch "tty1-selected", "ctrl-alt-f1", 6, 5;
    }

    # init
    select_console 'root-console';

    type_string "chown $username /dev/$serialdev\n";
    # Export the existing status of running tasks for future reference (fail would export it again)
    script_run "ps axf > /tmp/psaxf_consoletest_setup.log";

    # openSUSE 13.2's (and earlier) systemd has broken rules for virtio-net, not applying predictable names (despite being configured)
    # A maintenance update breaking networking names sounds worse than just accepting that 13.2 -> TW breaks
    # At this point, the system has been upadted, but our network interface changes name (thus we lost network connection)
    my @old_hdds = qw/openSUSE_12.1 openSUSE_12.2 openSUSE_12.3 openSUSE_13.1 openSUSE_13.2/;
    if (grep { check_var('HDDVERSION', $_) } @old_hdds) {    # copy eth0 network config to ens4
        script_run("cp /etc/sysconfig/network/ifcfg-eth0 /etc/sysconfig/network/ifcfg-ens4");
        script_run("/sbin/ifup ens4");
    }

    # Just after the setup: let's see the network configuration
    script_run "ip addr show";
    save_screenshot;

    # Stop packagekit
    script_run "systemctl mask packagekit.service";
    script_run "systemctl stop packagekit.service";
    # Installing a minimal system gives a pattern conflicting with anything not minimal
    # Let's uninstall 'the pattern' (no packages affected) in order to be able to install stuff
    script_run "zypper -n rm patterns-openSUSE-minimal_base-conflicts";
    # Install curl and tar in order to get the test data
    assert_script_run "zypper -n install curl tar";

    # upload_logs requires curl, but we wanted the initial state of the system
    upload_logs "/tmp/psaxf_consoletest_setup.log";
    save_screenshot;

    $self->clear_and_verify_console;

    select_console 'user-console';

    assert_script_run "curl -L -v -f " . autoinst_url('/data') . " > test.data";
    assert_script_run " cpio -id < test.data";
    script_run "ls -al data";

    save_screenshot;
}

sub post_fail_hook() {
    my $self = shift;

    $self->export_logs();
}

sub test_flags() {
    return {milestone => 1, fatal => 1};
}

1;
# vim: set sw=4 et:
