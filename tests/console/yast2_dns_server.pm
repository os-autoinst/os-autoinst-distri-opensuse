# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-dns-server bind
# Summary: Ensure that all combinations of running/stopped and active/inactive can be set for yast2 dns-server
# Maintainer: jeriveramoya <jeriveramoya@suse.com>

use base 'y2_module_consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_leap is_sle);
use y2_module_basetest 'continue_info_network_manager_default';
use constant RETRIES => 5;
use yast2_widget_utils qw(change_service_configuration verify_service_configuration);

sub run {
    my $self = shift;

    # Preparation
    my $older_products = is_sle('<15') || is_leap('<15.1');
    $cmd{apply_changes} = $older_products ? "alt-a" : "alt-p";
    select_console 'root-console';
    zypper_call 'in yast2-dns-server bind ' . $self->firewall, timeout => 180;
    # Pretend this is the 1st execution (could not be the case if yast2_cmdline was executed before)
    assert_script_run 'rm -f /var/lib/YaST2/dns_server';

    record_info '1st run', '[wizard-like interface] -> service active & enabled';
    y2_module_consoletest::yast2_console_exec(yast2_module => 'dns-server');

    continue_info_network_manager_default;
    assert_screen 'yast2-dns-server-step1';
    send_key 'alt-n';
    assert_screen 'yast2-dns-server-step2';
    send_key 'alt-n';
    wait_still_screen(3);
    if ($older_products) {
        assert_screen 'yast2-dns-server-step3';
        # Enable dns server and finish after yast2 loads default settings
        assert_screen 'yast2-dns-server-fw-port-is-closed';
        send_key 'alt-s';
        assert_screen 'yast2-dns-server-start-named-now';
    }
    else {
        assert_screen 'yast2-dns-server-open-port-firewall-focused';    # ensure dialog content loaded
        change_service_configuration(
            after_writing => {start => 'alt-t'},
            after_reboot => {start_on_boot => 'alt-a'}
        );
    }
    send_key $cmd{finish};

    # Verify changes in console. Apply changes is not available to check in the gui first,
    # Service may take a bit to actually start -> acceptable behaviour (boo#1093029)
    assert_screen 'root-console';
    my $times = RETRIES;
    ($times-- && sleep 5) while (systemctl('is-active named') == 1 && $times);
    die 'named service is not active even after waiting 25s' unless $times;
    systemctl 'is-enabled named';

    record_info '2nd run', '[tree-based interface] -> service inactive & enabled';
    script_run 'yast2 dns-server', 0;
    continue_info_network_manager_default;
    if ($older_products) {
        assert_screen 'yast2-service-running-enabled';
        # Stop the service
        wait_screen_change { send_key 'alt-s' };
        assert_screen 'yast2-service-stopped-enabled';
    }
    else {
        change_service_configuration(after_writing => {stop => 'alt-t'});
        send_key $cmd{apply_changes};
        verify_service_configuration(status => 'inactive');
    }
    send_key $cmd{ok};
    assert_screen 'root-console';
    systemctl 'is-active named', expect_false => 1;
    systemctl 'is-enabled named';

    record_info '3rd run', '[tree-based interface] -> service active and disabled';
    script_run 'yast2 dns-server', 0;
    continue_info_network_manager_default;
    if ($older_products) {
        assert_screen 'yast2-service-stopped-enabled';
        send_key 'alt-s';    # Start the service
        assert_screen 'yast2-service-running-enabled';
        wait_screen_change { send_key 'alt-t' };    # Disable the service and finish
    }
    else {
        change_service_configuration(
            after_writing => {start => 'alt-t'},
            after_reboot => {do_not_start => 'alt-a'}
        );
        send_key $cmd{apply_changes};
        verify_service_configuration(status => 'active');
    }
    send_key $cmd{ok};
    assert_screen 'root-console', 180;
    systemctl 'is-active named';
    systemctl 'is-enabled named', expect_false => 1;

    record_info '4th run', '[tree-based interface] -> service inactive and disabled';
    script_run 'yast2 dns-server', 0;
    continue_info_network_manager_default;
    if ($older_products) {
        assert_screen 'yast2-service-running-disabled', 90;
        # Stop the service
        send_key 'alt-s';
        assert_screen 'yast2-service-stopped-disabled';
    }
    else {
        change_service_configuration(after_writing => {stop => 'alt-t'});
        send_key $cmd{apply_changes};
        verify_service_configuration(status => 'inactive');    # verify changes in gui first
    }
    send_key $cmd{ok};
    assert_screen 'root-console', 180;
    systemctl 'is-active named', expect_false => 1;
    systemctl 'is-enabled named', expect_false => 1;

    return if $older_products;    # only for new products as cancel do not revert changes in services status
    record_info '5th run', '[tree-based interface] -> service in same status than previous run';
    script_run 'yast2 dns-server', 0;
    continue_info_network_manager_default;
    change_service_configuration(
        after_writing => {start => 'alt-t'},
        after_reboot => {start_on_boot => 'alt-a'}
    );
    send_key_until_needlematch([qw(root-console yast2-dns-server-quit)], 'alt-c');    # Cancel to check there is not effect
    send_key 'alt-y';
    assert_screen 'root-console';
    systemctl 'is-active named', expect_false => 1;
    systemctl 'is-enabled named', expect_false => 1;
}

sub post_fail_hook {
    my $self = shift;
    $self->SUPER::post_fail_hook();
    my @tar_input_files;
    my %cmds = (
        rpm_bind_info => 'rpm -qi bind',
        rpm_bind_file_list => 'rpm -ql bind',
        rpm_all_installed_packages => 'rpm -qa',
        iptables_all_rules => 'iptables -L -v --line-numbers',
        firewalld_all_services => 'firewall-cmd --list-services',
        status_named_service => 'systemctl --no-pager status named',
        named_journal => 'journalctl -u named',
        named_config => 'cat /etc/named.conf'
    );

    foreach (keys %cmds) {
        assert_script_run "echo Executing $cmds{$_}: > /tmp/$_";
        assert_script_run "echo -------------------- >> /tmp/$_";
        script_run "$cmds{$_} >> /tmp/$_ 2>&1";
        push @tar_input_files, "/tmp/$_";
    }
    assert_script_run "tar cvf /tmp/dns_troubleshoot.tar @tar_input_files";
    upload_logs('/tmp/dns_troubleshoot.tar');
}

1;
