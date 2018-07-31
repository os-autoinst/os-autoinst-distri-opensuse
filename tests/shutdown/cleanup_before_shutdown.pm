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
    if (get_var('DROP_PERSISTENT_NET_RULES')) {
        type_string "rm -f /etc/udev/rules.d/70-persistent-net.rules\n";
    }
    if (!sle_version_at_least('12-SP2') && check_var('VIRTIO_CONSOLE', 1)) {
        add_serial_console('hvc0');
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

