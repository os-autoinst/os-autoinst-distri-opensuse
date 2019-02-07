# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Additional actions and cleanup logic for the system before shutdown.
# The purpose of the module is to separate all the preparations from the shutdown
# itself and make the system ready for power off.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

use strict;
use base 'opensusebasetest';
use testapi;
use serial_terminal 'add_serial_console';
use utils;
use version_utils;

sub run {
    select_console('root-console');
    # Collect detailed logs to investigate shutdown issues and redirect them to serial console.
    # Please see https://freedesktop.org/wiki/Software/systemd/Debugging/#index2h1 for the details.
    # Boot options that are required to make logs more detalized are located in 'bootloader_setup.pm'
    if (get_var('DEBUG_SHUTDOWN')) {
        assert_script_run "echo -e '#!/bin/sh\\ndmesg > /dev/$serialdev' > /usr/lib/systemd/system-shutdown/debug.sh";
        assert_script_run "chmod +x /usr/lib/systemd/system-shutdown/debug.sh";
    }
    if (get_var('DROP_PERSISTENT_NET_RULES')) {
        type_string "rm -f /etc/udev/rules.d/70-persistent-net.rules\n";
    }
    # Configure serial consoles for virtio support
    # poo#18860 Enable console on hvc0 on SLES < 12-SP2
    # poo#44699 Enable console on hvc1 to fix login issues on ppc64le
    if (!check_var('VIRTIO_CONSOLE', 0)) {
        if (is_sle('<12-SP2') && !check_var('ARCH', 's390x')) {
            add_serial_console('hvc0');
        }
        elsif (get_var('OFW')) {
            add_serial_console('hvc1');
        }
    }
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
            assert_script_run('rm -f /var/lib/wicked/*.xml');
        }
    }
    # Make some information available on common systems to help debug shutdown issues.
    if (get_var('DESKTOP', '') =~ qr/gnome|kde/) {
        assert_script_run(q{echo 'ForwardToConsole=yes' >> /etc/systemd/journald.conf});
        assert_script_run(q{echo 'MaxLevelConsole=debug' >> /etc/systemd/journald.conf});
        assert_script_run(qq{echo 'TTYPath=/dev/$serialdev' >> /etc/systemd/journald.conf});
        assert_script_run(q{systemctl restart systemd-journald});
    }
}

1;

