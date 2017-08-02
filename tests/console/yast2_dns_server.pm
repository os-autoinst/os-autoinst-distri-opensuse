# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: New test for yast2-dns-server (service management)
# Maintainer: mgriessmeier <mgriessmeier@suse.de>

use base "console_yasttest";
use strict;
use testapi;
use utils "zypper_call";

# Test "yast2 dhcp-server" functionality
# Ensure that all combinations of running/stopped and active/inactive
# can be set

# Assert if the dns service is running or stopped
sub assert_running {
    my $self    = shift;
    my $running = shift;

    if ($running) {
        assert_script_run '(systemctl is-active named || true) | grep -E "^active"', timeout => 300;
    }
    else {
        assert_script_run '(systemctl is-active named || true) | grep -E "^(inactive|unknown)"';
    }
}

# Assert if the dns service is enabled or disabled
sub assert_enabled {
    my $self    = shift;
    my $enabled = shift;

    if ($enabled) {
        assert_script_run 'systemctl is-enabled named';
    }
    else {
        assert_script_run '! systemctl is-enabled named';
    }
}

sub run {
    my $self = shift;

    #
    # Preparation
    #
    select_console 'root-console';

    # Make sure packages are installed
    zypper_call('in yast2-dns-server bind SuSEfirewall2', timeout => 180);
    # Let's pretend this is the first execution (could not be the case if
    # yast2_cmdline was executed before)
    script_run 'rm /var/lib/YaST2/dns_server';

    #
    # First execution (wizard-like interface)
    #
    script_run 'yast2 dns-server', 0;
    # Just do next-next until the last step
    assert_screen 'yast2-dns-server-step1';
    send_key 'alt-n';
    assert_screen 'yast2-dns-server-step2';
    send_key 'alt-n';
    assert_screen 'yast2-dns-server-step3';
    # Enable dns server and finish
    send_key 'alt-s';
    wait_screen_change { send_key 'alt-f'; };
    # The wizard-like interface still uses the old approach of always starting the service
    # while enabling it, so named should be both active and enabled
    $self->assert_running(1);
    $self->assert_enabled(1);

    #
    # Second execution (tree-based interface)
    #
    script_run 'yast2 dns-server', 0;
    assert_screen 'yast2-service-running-enabled';
    # Stop the service
    send_key 'alt-s';
    assert_screen 'yast2-service-stopped-enabled';
    # Cancel yast2 to check the effect
    wait_screen_change { send_key 'alt-c' };
    if (check_screen('yast2-dns-server-quit')) {
        wait_screen_change { send_key 'alt-y' };
    }
    $self->assert_running(0);
    $self->assert_enabled(1);

    #
    # Third execution (tree-based interface)
    #
    script_run 'yast2 dns-server', 0;
    assert_screen 'yast2-service-stopped-enabled';
    # Start the service
    send_key 'alt-s';
    assert_screen 'yast2-service-running-enabled';
    # Disable the service and finish
    wait_screen_change { send_key 'alt-t' };
    wait_screen_change { send_key 'alt-o' };
    $self->assert_running(1);
    $self->assert_enabled(0);

    #
    # Fourth execution (tree-based interface)
    #
    script_run 'yast2 dns-server',                  0;
    assert_screen 'yast2-service-running-disabled', 90;
    # Stop the service
    send_key 'alt-s';
    assert_screen 'yast2-service-stopped-disabled';
    # Finish
    wait_screen_change { send_key 'alt-o' };
    $self->assert_running(0);
    $self->assert_enabled(0);
}

1;

# vim: set sw=4 et:
