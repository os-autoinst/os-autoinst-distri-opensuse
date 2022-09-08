=head1 y2lan_restart_common

Library for non-destructive testing using yast2 lan.

=cut
# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: YaST logic on Network Restart while no config changes were made
# Maintainer: QE YaST <qa-sle-yast@suse.de>
# Tags: fate#318787 poo#11450

package y2lan_restart_common;

use strict;
use warnings;
use Exporter 'import';
use testapi;
use utils 'systemctl';
use version_utils qw(is_sle is_leap);
use y2_module_basetest qw(accept_warning_network_manager_default is_network_manager_default);
use y2_module_consoletest;
use Test::Assert ':all';
use x11utils "start_root_shell_in_xterm";

our @EXPORT = qw(
  check_etc_hosts_update
  close_network_settings
  check_network_status
  initialize_y2lan
  open_network_settings
  validate_etc_hosts_entry
  verify_network_configuration
  handle_Networkmanager_controlled
  handle_dhcp_popup
  open_yast2_lan
  close_yast2_lan
  open_yast2_routing
  change_ipforward
  wait_for_xterm_to_be_visible
  clear_journal_log
  close_xterm
);
my $module_name;
# Keeping "shutting down|ifdown all" for compatibility with NetworkManager and previous wicked versions.
my $query_pattern_for_restart = "shutting down|ifdown all|Stopping wicked";

=head2 initialize_y2lan

 initialize_y2lan();

Initialize yast2 lan. Stop firewalld. Ensure firewalld is stopped. Enable DEBUG. Clear journal.

=cut

sub initialize_y2lan
{
    start_root_shell_in_xterm();
    # make sure that firewalld is stopped, or we have later pops for firewall activation warning
    # or timeout for command 'ip a' later
    if ((is_sle('15+') or is_leap('15.0+')) and script_run("systemctl show -p ActiveState firewalld.service | grep ActiveState=inactive")) {
        systemctl 'stop firewalld';
        assert_script_run("systemctl show -p ActiveState firewalld.service | grep ActiveState=inactive");
    }
    # Enable DEBUG for NetworkManager or wicked, in order to get detailed messages and easier detection of restart.
    my $debug_conf = is_network_manager_default() ?
      'DEBUG="no"/DEBUG="yes"' :    # DEBUG configuration for NetworkManager
      '(WICKED_LOG_LEVEL).*/\1="info"';    # DEBUG configuration for wicked
    assert_script_run 'sed -i -E \'s/' . $debug_conf . '/\' /etc/sysconfig/network/config';
    assert_script_run 'systemctl restart network';
    enter_cmd "journalctl -f -o short-precise|egrep -i --line-buffered '$query_pattern_for_restart|Reloaded wicked' > journal.log &";
    clear_journal_log();
}

=head2 open_network_settings

 open_network_settings();

Open yast2 lan module, expecting Overview tab and select first device.

Accept warning for Networkmanager controls network device.

=cut

sub open_network_settings {
    $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'lan', extra_vars => get_var('YUI_PARAMS'));
    # 'Global Options' tab is opened after accepting the warning on the systems
    # with Network Manager.
    # Thus, there is no way to select device in Overview tab on such systems, so
    # just skipping the selection.
    if (is_network_manager_default()) {
        accept_warning_network_manager_default();
    }
    else {
        assert_screen 'yast2_lan', 180;    # yast2 lan overview tab
        send_key 'home';    # select first device
        wait_still_screen 1, 1;
    }
}

=head2 close_network_settings

 close_network_settings();

Close network settings checking for return code 0 on serial line.

=cut

sub close_network_settings {
    wait_still_screen 1, 1;
    send_key 'alt-o';
    # new: warning pops up for firewall, alt-y for assign it to zone
    if (!wait_serial("$module_name-0", 180)) {
        check_screen([qw(yast2-lan-restart_firewall_active_warning yast2_lan_packages_need_to_be_installed)], 0);
        if (match_has_tag 'yast2-lan-restart_firewall_active_warning') {
            send_key 'alt-y';
            wait_still_screen 1, 1;
            send_key 'alt-n';
            wait_still_screen 1, 1;
            send_key 'alt-o';
        }
        elsif (match_has_tag 'yast2_lan_packages_need_to_be_installed') {
            send_key 'alt-i';
        }
        wait_serial("$module_name-0", 180) || die "'yast2 lan' didn't finish or exited with non-zero code";
    }

    enter_cmd "\n";    # make space for better readability of the console
}

=head2 check_network_status

 check_network_status([$expected_status], [$device]);

Check network status for device, test connection and DNS. Print journal.log on screen if C<$expected_status> is restart.

=cut

sub check_network_status {
    my ($expected_status, $device) = @_;
    $expected_status //= 'no_restart_or_reload';
    assert_screen 'yast2_closed_xterm_visible', 120;
    assert_script_run 'ip a';
    if ($device eq 'bond') {
        record_soft_failure 'bsc#992113';
    }
    else {
        assert_script_run 'dig suse.com|grep \'status: NOERROR\'';    # test if conection and DNS is working
    }
    assert_script_run 'cat journal.log';    # print journal.log
    my $journal_findings = script_output('cat journal.log');
    record_info "$expected_status", "Network status expects $expected_status";
    if ($expected_status eq 'no_restart_or_reload') {
        assert_matches(qr/^\s*$/, $journal_findings, "Network service should not have been restarted/reloaded. Check journalctl findings \n$journal_findings\n\n");
    }
    elsif ($expected_status eq 'restart') {
        assert_matches(qr/$query_pattern_for_restart/, $journal_findings, "Network restart was expected. Check journalctl findings \n$journal_findings\n\n");
    }
    elsif ($expected_status eq 'reload') {
        assert_matches(qr/Reloaded wicked/, $journal_findings, "Network reload was expected. Check journalctl findings \n$journal_findings\n\n");
        assert_not_matches(qr/$query_pattern_for_restart/, $journal_findings, "Network restart happened when reload was expected. Check journalctl findings \n$journal_findings\n\n");
    }
    else {
        die "$expected_status was not any of the known expected status! Check journalctl findings \n$journal_findings\n\n";
    }
    clear_journal_log();
    type_string "\n\n";    # make space for better readability of the console
}

=head2 check_device_state

 check_device_state($args);

Checks state of the device using ip command, receives keys C<device> which contains
device name and C<state> which contains expected state of the device.

=cut

sub check_device_state {
    my ($args) = @_;
    assert_script_run "ip -s link show @{ [ $args->{device} ] } | grep -i 'state @{ [ $args->{state} ] }'";    # check if provided device is up and running
}

=head2 verify_network_configuration

 verify_network_configuration([$fn], [$expected_status], [$dev_name], [$workaround], [$no_network_check]);

C<$fn> is a reference to the function with the action to be performed.

C<$dev_name> is device name.

C<$expected_status> can be restart, no_restart or reload. If undef is set to no_restart.

C<$workaround> is workaround.

C<no_network_check> means no network check.

Verify network configurations for: device name, network status, workaround or no network check

Check network status C<$expected_status>, C<$workaround> if C<$no_network_check> is defined

=cut

sub verify_network_configuration {
    my ($fn, $expected_status, $dev_name, $workaround, $no_network_check) = @_;
    open_network_settings;

    $fn->($dev_name) if $fn;    # verify specific action

    close_network_settings;
    check_device_state({device => $dev_name, state => 'UP'}) if $dev_name;
    check_network_status($expected_status, $workaround) unless defined $no_network_check;
}

=head2 validate_etc_hosts_entry

 validate_etc_hosts_entry([$args]);

Validate /etc/hosts entries for ip, fqdn, host.

Run record_soft_failure for bsc#1115644 if C<$args> has not been found in /etc/hosts and print /etc/hosts.

=cut

sub validate_etc_hosts_entry {
    my (%args) = @_;

    script_run("egrep \"@{[$args{ip}]}\\s@{[$args{fqdn}]}\\s@{[$args{host}]}\" /etc/hosts", 30)
      && record_soft_failure "bsc#1115644 Expected entry:\n \"@{[$args{ip}]}    @{[$args{fqdn}]} @{[$args{host}]}\" was not found in /etc/hosts";
    script_run "cat /etc/hosts";
}

=head2 set_network

 set_network([$args]);

Manually configure network settings or set it to DHCP. C<$args> can be static, ip, mask, fqdn

=cut

sub set_network {
    my (%args) = @_;

    open_network_settings;
    send_key 'alt-i';    # edit NIC
    assert_screen 'yast2_lan_network_card_setup';
    if ($args{static}) {
        send_key 'alt-t';    # set to static ip
        assert_screen 'yast2_lan_static_ip_selected';
        send_key 'tab';
        if ($args{ip}) {    # To spare time, no update what to is already filled from previous run
            send_key_until_needlematch('ip_textfield_empty', 'backspace');    # delete existing IP if any
            type_string $args{ip};
        }
        send_key 'tab';
        if ($args{mask}) {    # To spare time, no update what to is already filled from previous run
            send_key_until_needlematch('mask_textfield_empty', 'backspace');    # delete existing netmask if any
            type_string $args{mask};
        }
        send_key 'tab';
        send_key_until_needlematch('hostname_textfield_empty', 'backspace', 31, 1);
        type_string $args{fqdn};
        assert_screen 'yast2_lan_static_ip_set';
    }
    else {
        send_key 'alt-y';    # set back to DHCP
        assert_screen 'yast2_lan_dhcp_set';
    }
    # Exit
    send_key 'alt-n';
    assert_screen "yast2_lan";
    close_network_settings;
}


=head2 check_etc_hosts_update

 check_etc_hosts_update();

Check update of /etc/hosts. In order to target bugs bsc#1115644 and bsc#1052042, we want to run steps:

=over

=item * set static IP and fqdn for first NIC in the list and check format of /etc/hosts

=item * open yast2 lan again and change fqdn, check if /etc/hosts is changed correctly (bsc#1052042)

=item * set it to DHCP

=item * set it again to static with  new FQDN and check if /etc/hosts is changed correctly (bsc#1115644)

=back

=cut

sub check_etc_hosts_update {

    my $ip = '192.168.122.10';
    my $mask = '255.255.255.0';
    script_run "cat /etc/hosts";

    record_info 'Test', 'Set static ip, FQDN and validate /etc/hosts entry';
    my $hostname = "test-1";
    my $fqdn = $hostname . '.susetest.com';
    set_network(static => 1, fqdn => $fqdn, ip => $ip, mask => $mask);
    validate_etc_hosts_entry(ip => $ip, host => $hostname, fqdn => $fqdn);

    record_info 'Test', 'Change FQDN and validate /etc/hosts entry';
    $hostname = "test-2";
    $fqdn = $hostname . '.susetest.com';
    set_network(static => 1, fqdn => $fqdn, ip => $ip, mask => $mask);
    validate_etc_hosts_entry(ip => $ip, host => $hostname, fqdn => $fqdn);

    # Set back to dhcp
    set_network(fqdn => $fqdn);

    record_info 'Test', 'Set to static from dchp, set FQDN and validate /etc/hosts entry';
    $hostname = "test-3";
    $fqdn = $hostname . '.susetest.com';
    set_network(static => 1, fqdn => $fqdn, ip => $ip, mask => $mask);
    validate_etc_hosts_entry(ip => $ip, host => $hostname, fqdn => $fqdn);

    # Set back to dhcp
    set_network;
}

=head2 handle_Networkmanager_controlled

 handle_Networkmanager_controlled();

Handle Networkmanager controls the network configurations.
Confirm if a warning popup for Networkmanager controls networking.

=cut

sub handle_Networkmanager_controlled {
    assert_screen 'Networkmanager_controlled', 300;
    send_key "ret";    # confirm networkmanager popup
    assert_screen "Networkmanager_controlled-approved";
    send_key "alt-c";
    if (check_screen('yast2-lan-really', 3)) {
        # SLED11...
        send_key 'alt-y';
    }
    wait_serial("$module_name-{0,16}", 60) || die "'yast2 lan' didn't finish";
}

=head2 handle_dhcp_popup

 handle_dhcp_popup();

Handle DHCP popup, confirm for DHCP popup.

=cut

sub handle_dhcp_popup {
    if (match_has_tag('dhcp-popup')) {
        wait_screen_change { send_key 'alt-o' };
    }
}

=head2 open_yast2_routing

 open_yast2_routing();

Open yast2 routing

=cut

sub open_yast2_routing {
    $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'routing');
    assert_screen "yast2_routing", 120;
}

=head2 change_ipforward

 change_ipforward([$state], [$should_conflict]);

C<$state> enabled/disabled will used to set the expected needle to match
C<$should_conflict> 1 means conflict is expected or 0 otherwise

Open routing module and enable or disable ip_forwarding

=cut

sub change_ipforward {
    my %options = @_;
    open_yast2_routing();
    send_key 'spc';
    assert_screen "ipv4_forwarding_$options{state}";
    send_key 'alt-n', wait_screen_change => 1;
    assert_screen "sysctl_ip_forward_conflict" if ($options{should_conflict});
    send_key 'alt-o';
    wait_serial("yast2-routing-status-0", 180) || die "'yast2-routing' didn't finish";
}

=head2 open_yast2_lan

 open_yast2_lan();

Open yast2 lan, run handle_dhcp_popup() and install and check firewalld

If network is controlled by Networkmanager, don't change any network settings.

=cut

sub open_yast2_lan {
    my $is_nm = !script_run('systemctl is-active NetworkManager');    # Revert boolean because of bash vs perl's return code.

    $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'lan');

    if ($is_nm) {
        handle_Networkmanager_controlled;    # don't change any settings
        return "Controlled by network manager";
    }

    assert_screen [qw(yast2_lan install-susefirewall2 install-firewalld dhcp-popup)], 240;
    handle_dhcp_popup;

    if (match_has_tag('install-susefirewall2') || match_has_tag('install-firewalld')) {
        # install firewall
        send_key "alt-i";
        # check yast2_lan again after firewall is installed
        assert_screen('yast2_lan', 90);
    }
}

=head2 close_yast2_lan

 close_yast2_lan();

Close yast2 lan configuration and check that it is closed successfully

=cut

sub close_yast2_lan {
    my ($tag) = @_;
    if ($tag eq '') {
        send_key 'alt-o';
    } else {
        send_key_until_needlematch($tag, 'alt-o', 6, 5);
    }
    wait_serial("$module_name-0", 180) || die "'yast2 lan' didn't finish";
}

=head2 clear_journal_log

 clear_journal_log();

Makes space for better readability of the console and clears journal.log,
so that the existing logs will not interfere with the new ones.

=cut

sub clear_journal_log {
    enter_cmd "\n";
    assert_script_run '> journal.log';
}

=head2 wait_for_xterm_to_be_visible

 wait_for_xterm_to_be_visible();

The function waits for the already opened xterm to be visible.

Raises failure in case it is not visible after timeout exceeded.

It is used to be sure, that all the yast2 lan windows are closed, so that all
further actions in xterm can be made.

=cut

sub wait_for_xterm_to_be_visible {
    assert_screen 'yast2_closed_xterm_visible', 120;
}

=head2 close_xterm

 close_xterm();

The function kills all the instances of xterm terminal to clear desktop for
further tests.

=cut

sub close_xterm {
    enter_cmd "killall xterm";
}

1;
