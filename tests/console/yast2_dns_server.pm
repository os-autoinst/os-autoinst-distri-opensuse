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

use base qw(console_yasttest y2logsstep);
use strict;
use testapi;
use utils;
use version_utils qw(is_leap is_sle sle_version_at_least);
use constant RETRIES => 5;
# Test "yast2 dhcp-server" functionality
# Ensure that all combinations of running/stopped and active/inactive
# can be set

# Assert if the dns service is running or stopped
sub assert_running {
    my $self    = shift;
    my $running = shift;
    my $cmd     = '(systemctl is-active named || true) | grep -E';

    if ($running) {
        $cmd .= ' "^active"';
        my $counter = RETRIES;
        # Service may take a bit of time to actually start
        while (script_run $cmd) {
            sleep 5;
            $counter--;
            # Service was not started after 25 seconds
            die 'named service is not active even after 25s delay' if $counter == 0;
        }
        # Service was started after some delay
        record_soft_failure 'bsc#1093029' if $counter < RETRIES;
    }
    else {
        $cmd .= ' "^(inactive|unknown)"';
        record_soft_failure 'bsc#1102235' if (script_run $cmd);
    }
}

# Assert if the dns service is enabled or disabled
sub assert_enabled {
    my $self    = shift;
    my $enabled = shift;

    if ($enabled) {
        systemctl 'is-enabled named';
    }
    else {
        systemctl 'is-enabled named', expect_false => 1;
    }
}

sub run {
    my $self = shift;

    #
    # Preparation
    #
    select_console 'root-console';

    # Make sure packages are installed
    my $firewall_package = $self->firewall;
    zypper_call("in yast2-dns-server bind $firewall_package", timeout => 180);
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
    wait_still_screen(3);
    assert_screen([qw(yast2-dns-server-step3 yast2_still_susefirewall2)], 90);
    if (match_has_tag 'yast2_still_susefirewall2') {
        record_soft_failure "bsc#1059569";
        send_key 'alt-i';
        assert_screen 'yast2-dns-server-step3';
    }

    # Enable dns server and finish after yast2 loads default settings
    assert_screen 'yast2-dns-server-fw-port-is-closed';
    send_key 'alt-s';
    assert_screen 'yast2-dns-server-start-named-now';
    send_key 'alt-f';
    assert_screen 'root-console';
    # The wizard-like interface still uses the old approach of always starting the service
    # while enabling it, so named should be both active and enabled
    $self->assert_running(1);
    $self->assert_enabled(1);

    #
    # Second execution (tree-based interface)
    #
    script_run 'yast2 dns-server', 0;
    assert_screen([qw(yast2-service-running-enabled yast2_still_susefirewall2)], 90);
    if (match_has_tag 'yast2_still_susefirewall2') {
        record_soft_failure "bsc#1059569";
        send_key 'alt-i';
        assert_screen 'yast2-service-running-enabled';
    }
    # Stop the service
    wait_screen_change { send_key 'alt-s' };
    assert_screen 'yast2-service-stopped-enabled';
    # Cancel yast2 to check the effect
    # workaround for single send_key 'alt-c' because it doesn't work.
    send_key_until_needlematch([qw(root-console yast2-dns-server-quit)], 'alt-c');
    send_key 'alt-y';
    assert_screen 'root-console', 180;
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
    send_key 'alt-o';
    assert_screen 'root-console', 180;
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
    send_key 'alt-o';
    assert_screen 'root-console', 180;
    $self->assert_running(0);
    $self->assert_enabled(0);
}

sub post_fail_hook {
    my $self = shift;
    my @tar_input_files;
    my %cmds = (
        rpm_bind_info              => 'rpm -qi bind',
        rpm_bind_file_list         => 'rpm -ql bind',
        rpm_all_installed_packages => 'rpm -qa',
        iptables_all_rules         => 'iptables -L -v --line-numbers',
        firewalld_all_services     => 'firewall-cmd --list-services',
        status_named_service       => 'systemctl --no-pager status named',
        named_journal              => 'journalctl -u named',
        named_config               => 'cat /etc/named.conf'
    );

    foreach (keys %cmds) {
        assert_script_run "echo Executing $cmds{$_}: > /tmp/$_";
        assert_script_run "echo -------------------- >> /tmp/$_";
        script_run "$cmds{$_} >> /tmp/$_ 2>&1";
        push @tar_input_files, "/tmp/$_";
    }
    assert_script_run "tar cvf /tmp/dns_troubleshoot.tar @tar_input_files";
    upload_logs('/tmp/dns_troubleshoot.tar');
    $self->SUPER::post_fail_hook();
}

1;
