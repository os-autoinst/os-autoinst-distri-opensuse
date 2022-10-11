# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Additional actions and cleanup logic for the system before shutdown.
# The purpose of the module is to separate all the preparations from the shutdown
# itself and make the system ready for power off.
# - if DEBUG_SHUTDOWN is set, then collect detailed logs to investigate shutdown issues
#   and redirect them to serial console
# - if KEEP_PERSISTENT_NET_RULES is set, 70-persistent-net.rules will not be deleted on backend with image support
# - Clean /var/lib/wicked - remove the DUID so it gets regenerated and forget DHCP leases
#     ( There might be multiple machines at the same time originating from the same HDD )
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
use Utils::Backends;

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
    if (!get_var('KEEP_PERSISTENT_NET_RULES') && is_image_backend) {
        script_run('rm -f /etc/udev/rules.d/70-persistent-net.rules');
    }
    if (!get_var('KEEP_QUIET_BOOT') && check_var('FLAVOR', 'JeOS-for-RaspberryPi')) {
        assert_script_run('sed -i -e \'s/ quiet$//\' /boot/grub2/grub.cfg');
    }

    prepare_serial_console;

    # Proceed with dhcp cleanup on qemu backend only.
    # Cleanup is made, because if same hdd image used in multimachine scenario
    # on several nodes, the dhcp clients use same DUID and cause conflicts on dhcpd server.
    if (is_qemu || is_svirt_except_s390x) {
        my $network_status = script_output('systemctl status network');
        # Do dhcp cleanup for wicked
        if ($network_status =~ /wicked/) {
            systemctl 'stop network.service';
            systemctl 'stop wickedd.service';
            assert_script_run('ls /var/lib/wicked/');
            save_screenshot;
            assert_script_run('rm -f /var/lib/wicked/{duid,lease-*}.xml');
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
