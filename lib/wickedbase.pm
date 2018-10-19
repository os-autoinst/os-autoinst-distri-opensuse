# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Base module for all wicked scenarios
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>

package wickedbase;

use base 'opensusebasetest';
use utils 'systemctl';
use network_utils;
use lockapi;
use testapi qw(is_serial_terminal :DEFAULT);
use serial_terminal;

sub assert_wicked_state {
    my ($self, %args) = @_;
    systemctl('is-active wicked.service',  expect_false => $args{wicked_client_down});
    systemctl('is-active wickedd.service', expect_false => $args{wicked_daemon_down});
    my $status = $args{interfaces_down} ? 'down' : 'up';
    assert_script_run("/data/check_interfaces.sh $status");
    assert_script_run("ping -c 4 $args{ping_ip}") if $args{ping_ip};
    # this just FYI so we don't want to fail
    script_run('ip addr show ' . $args{iface}) if $args{iface};
}

sub get_ip {
    my ($self, %args) = @_;
    my $ip;

    if ($args{type} eq 'host') {
        $ip = $args{is_wicked_ref} ? '10.0.2.10/15' : '10.0.2.11/15';
    }
    elsif ($args{type} eq 'gre1') {
        $ip = $args{is_wicked_ref} ? '192.168.1.1' : '192.168.1.2';
    }
    elsif ($args{type} eq 'sit1') {
        $ip = $args{is_wicked_ref} ? '2001:0db8:1234::000e' : '2001:0db8:1234::000f';
    }
    elsif ($args{type} eq 'tunl1') {
        $ip = $args{is_wicked_ref} ? '3.3.3.10' : '3.3.3.11';
    }
    elsif ($args{type} eq 'tun1' || $args{type} eq 'tap1') {
        $ip = $args{is_wicked_ref} ? '192.168.2.10' : '192.168.2.11';
    }
    elsif ($args{type} eq 'br0') {
        $ip = $args{is_wicked_ref} ? '10.0.2.10' : '10.0.2.11';
    }
    elsif ($args{type} eq 'vlan') {
        $ip = $args{is_wicked_ref} ? '42.42.42.10/24' : '42.42.42.11/24';
    }
    elsif ($args{type} eq 'vlan_changed') {
        $ip = $args{is_wicked_ref} ? '42.42.42.110/24' : '42.42.42.111/24';
    }

    if (defined($ip) && $args{no_mask}) {
        $ip =~ s'/\d+$'';
    }
    return $ip if (defined($ip));
}

sub get_current_ip {
    my ($self, $ifc, %args) = @_;
    $args{ip_version} //= 'v4';
    die("Missing mandatory parameter ifc") unless ($ifc);

    my $out = script_output('ip -o ' . ($args{ip_version} eq 'v6' ? '-6' : '-4') . ' addr list ' . $ifc . ' | awk \'{print $4}\' | cut -d/ -f1');
    my @ips = split('\r?\n', $out);

    return $ips[0] if (@ips);
    return;
}

sub save_and_upload_wicked_log {
    my $log_path = '/tmp/journal.log';
    assert_script_run("journalctl -o short-precise > $log_path");
    upload_logs($log_path);
}

sub get_from_data {
    my ($self, $source, $target, %args) = @_;
    $source .= check_var('IS_WICKED_REF', '1') ? 'ref' : 'sut' if $args{add_suffix};
    assert_script_run("wget --quiet " . data_url($source) . " -O $target");
    assert_script_run("chmod +x $target") if $args{executable};
}

sub post_fail_hook {
    my ($self) = @_;
    systemctl('start network');
    systemctl('start wicked');
    recover_network() if !can_upload_logs();
    save_and_upload_wicked_log();
}

sub ping_with_timeout {
    my ($self, %args) = @_;
    $args{ip_version} //= 'v4';
    my $timeout = $args{timeout};
    my $ping_command = ($args{ip_version} eq "v6") ? "ping6" : "ping";
    while ($timeout > 0) {
        return 1 if script_run("$ping_command -c 1 $args{ip}") == 0;
        $timeout -= 1;
        sleep 5;
    }
    return 0;
}

sub setup_tuntap {
    my ($self, $config, $type, $is_wicked_ref) = @_;
    my $local_ip  = $self->get_ip(no_mask => 1, is_wicked_ref => $is_wicked_ref,  type => $type);
    my $remote_ip = $self->get_ip(no_mask => 1, is_wicked_ref => !$is_wicked_ref, type => $type);
    assert_script_run("sed \'s/local_ip/$local_ip/\' -i $config");
    assert_script_run("sed \'s/remote_ip/$remote_ip/\' -i $config");
    assert_script_run("cat $config");
    assert_script_run("wicked ifup --timeout infinite $type");
    assert_script_run('ip a');
}

sub setup_tunnel {
    my ($self, $config, $type) = @_;
    my $local_ip  = $self->get_ip(no_mask => 1, is_wicked_ref => 0, type => 'host');
    my $remote_ip = $self->get_ip(no_mask => 1, is_wicked_ref => 1, type => 'host');
    my $tunnel_ip = $self->get_ip(is_wicked_ref => 0, type => $type);
    assert_script_run("sed \'s/local_ip/$local_ip/\' -i $config");
    assert_script_run("sed \'s/remote_ip/$remote_ip/\' -i $config");
    assert_script_run("sed \'s/tunnel_ip/$tunnel_ip/\' -i $config");
    assert_script_run("cat $config");
    assert_script_run("wicked ifup --timeout infinite $type");
    assert_script_run('ip a');
}

sub create_tunnel_with_commands {
    my ($self, $type, $mode, $sub_mask) = @_;
    my $local_ip  = $self->get_ip(no_mask => 1, is_wicked_ref => 1, type => 'host');
    my $remote_ip = $self->get_ip(no_mask => 1, is_wicked_ref => 0, type => 'host');
    my $tunnel_ip = $self->get_ip(is_wicked_ref => 1, type => $type);
    assert_script_run("ip tunnel add $type mode $mode remote $remote_ip local $local_ip");
    assert_script_run("ip link set $type up");
    assert_script_run("ip addr add $tunnel_ip/$sub_mask dev $type");
    assert_script_run("ip addr");
}

sub setup_bridge {
    my ($self, $config, $dummy, $command) = @_;
    my $local_ip = $self->get_ip(no_mask => 1, is_wicked_ref => 0, type => 'host');
    assert_script_run("sed \'s/ip_address/$local_ip/\' -i $config");
    assert_script_run("cat $config");
    assert_script_run("wicked $command --timeout infinite br0");
    if ($dummy ne '') {
        assert_script_run("cat $dummy");
        assert_script_run("wicked $command --timeout infinite dummy0");
    }
    assert_script_run('ip a');
}

sub setup_openvpn_client {
    my ($self, $device) = @_;
    my $openvpn_client = '/etc/openvpn/client.conf';
    my $remote_ip = $self->get_ip(no_mask => 1, is_wicked_ref => 1, type => 'host');
    $self->get_from_data('wicked/openvpn/client.conf', $openvpn_client);
    assert_script_run("sed \'s/remote_ip/$remote_ip/\' -i $openvpn_client");
    assert_script_run("sed \'s/device/$device/\' -i $openvpn_client");
}

sub cleanup {
    my ($self, $config, $type) = @_;
    assert_script_run("ifdown $type");
    assert_script_run("rm $config");
}

sub before_scenario {
    my ($self, $title, $text, $iface) = @_;
    if ($iface) {
        assert_script_run("ifdown $iface");
        assert_script_run("ifbind.sh unbind $iface");
        script_run("rm /etc/sysconfig/network/ifcfg-$iface");
        assert_script_run("ifbind.sh bind $iface");
        setup_static_network(ip => $self->get_ip(is_wicked_ref => check_var('IS_WICKED_REF', 1), type => 'host'));
    }
    record_info($title, $text);
}

sub get_test_result {
    my ($self, $type, $ip_version) = @_;
    my $timeout = "60";
    my $ip      = $self->get_ip(is_wicked_ref => 1, type => $type, no_mask => 1);
    my $ret     = $self->ping_with_timeout(ip => "$ip", timeout => "$timeout", ip_version => $ip_version);
    if (!$ret) {
        record_info("PING FAILED", "Can't ping IP $ip", result => 'fail');
        return "FAILED";
    }
    else {
        return "PASSED";
    }
}

sub do_mutex {
    my ($self) = @_;
    my $mutex_name = 'test_' . $self->{name} . '_ready';
    if (check_var('IS_WICKED_REF', '1')) {
        mutex_wait($mutex_name);
    } else {
        mutex_create($mutex_name);
    }
}

sub done {
    my ($self) = @_;
    my $flags = $self->test_flags();
    if ($flags->{wicked_need_sync}) {
        $self->do_mutex();
    }
    $self->SUPER::done();
}

sub pre_run_hook {
    my ($self) = @_;
    if (is_serial_terminal()) {
        my $coninfo = '## START: ' . $self->{name};
        wait_serial(serial_term_prompt(), undef, 0, no_regex => 1);
        type_string($coninfo);
        wait_serial($coninfo, undef, 0, no_regex => 1);
        type_string("\n");
    }
}

1;
