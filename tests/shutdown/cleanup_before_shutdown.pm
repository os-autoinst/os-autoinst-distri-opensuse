# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Additional actions and cleanup logic for the system before shutdown.
# The purpose of the module is to separate all the preparations from the shutdown
# itself and make the system ready for power off.
# - if DEBUG_SHUTDOWN is set, then collect detailed logs to investigate shutdown issues
#   and redirect them to serial console
# - if DROP_PERSISTENT_NET_RULES is set, then remove 70-persistent-net.rules
# - dhcp cleanup on qemu backend (stop network and wickedd, remove xml files from /var/lib/wicked)
# - if DESKTOP is set, then set 'ForwardToConsole=yes', 'MaxLevelConsole=debug' and 'TTYPath=/dev/$serialdev'
#   in /etc/systemd/journald.conf and restart systemd-journalctl
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;
use serial_terminal 'prepare_serial_console';
use utils;
use version_utils;

sub run {
    select_console('root-console');
    # Collect detailed logs to investigate shutdown issues and redirect them to serial console.
    # Please see https://freedesktop.org/wiki/Software/systemd/Debugging/#index2h1 for the details.
    # Boot options that are required to make logs more detalized are located in 'bootloader_setup.pm'
    if (get_var('DEBUG_SHUTDOWN')) {
        my $script = << "END_SCRIPT";
             echo -e '#!/bin/sh
             echo --- dmesg log ---  > /dev/$serialdev
             dmesg -T >> /dev/$serialdev
             echo --- journactl log ---  >> /dev/$serialdev
             journalctl >> /dev/$serialdev'  > /usr/lib/systemd/system-shutdown/debug.sh \\
END_SCRIPT
        assert_script_run $script;
        assert_script_run "chmod +x /usr/lib/systemd/system-shutdown/debug.sh";
    }
    if (get_var('DROP_PERSISTENT_NET_RULES')) {
        type_string "rm -f /etc/udev/rules.d/70-persistent-net.rules\n";
    }

    prepare_serial_console;

    # Proceed with dhcp cleanup on qemu backend only.
    # Cleanup is made, because if same hdd image used in multimachine scenario
    # on several nodes, the dhcp clients use same id and cause conflicts on dhcpd server.
    if (check_var('BACKEND', 'qemu')) {
        my $network_status = script_output('systemctl status network');
        # Do dhcp cleanup for wicked
        if ($network_status =~ /wicked/) {
            systemctl 'stop network.service';
            systemctl 'stop wickedd.service';
            assert_script_run('ls /var/lib/wicked/');
            save_screenshot;
            script_run('rm -f /var/lib/wicked/*.xml');
        }
        script_run("echo -n '' > /etc/hostname") if get_var('RESET_HOSTNAME');
    }
    # Make some information available on common systems to help debug shutdown issues.
    if (get_var('DESKTOP', '') =~ qr/gnome|kde/) {
        assert_script_run(q{echo 'ForwardToConsole=yes' >> /etc/systemd/journald.conf});
        assert_script_run(q{echo 'MaxLevelConsole=debug' >> /etc/systemd/journald.conf});
        assert_script_run(qq{echo 'TTYPath=/dev/$serialdev' >> /etc/systemd/journald.conf});
        # Before updating this value again, check the system logs
        assert_script_run(q{systemctl restart systemd-journald}, 120);
    }
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    $self->save_and_upload_systemd_unit_log('systemd-journald');
}

1;
