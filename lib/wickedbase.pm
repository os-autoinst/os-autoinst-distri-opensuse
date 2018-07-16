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
use testapi;

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
    if ($args{type} eq 'host') {
        if ($args{no_mask}) {
            return $args{is_wicked_ref} ? '10.0.2.10' : '10.0.2.11';
        }
        else {
            return $args{is_wicked_ref} ? '10.0.2.10/15' : '10.0.2.11/15';
        }
    }
    elsif ($args{type} eq 'gre1') {
        return $args{is_wicked_ref} ? '192.168.1.1' : '192.168.1.2';
    }
    elsif ($args{type} eq 'sit1') {
        return $args{is_wicked_ref} ? '2001:0db8:1234::000e' : '2001:0db8:1234::000f';
    }
    elsif ($args{type} eq 'tunl1') {
        return $args{is_wicked_ref} ? '3.3.3.10' : '3.3.3.11';
    }
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
    my $iface    = $self->{iface};
    my $ifstatus = script_output("ifstatus $iface");
    if ($ifstatus !~ /state up/) {
        script_run("ip addr add 10.0.2.15/24 dev $iface");
        script_run("ip link set $iface up");
        script_run("ip route add default via 10.0.2.2 dev $iface");
    }
    save_and_upload_wicked_log();
}

sub ping_with_timeout {
    my ($self, %args) = @_;
    my $timeout = $args{timeout};
    my $ping_command = ($args{ip_version} eq "v6") ? "ping6" : "ping";
    while ($timeout > 0) {
        return 1 if script_run("$ping_command -c 1 $args{ip}") == 0;
        $timeout -= 1;
        sleep 5;
    }
    return 0;
}

sub before_scenario {
    my ($self, $title, $text, $iface) = @_;
    if ($iface) {
        assert_script_run("ifdown $iface");
        assert_script_run("ifbind.sh unbind $iface");
        script_run("rm /etc/sysconfig/network/ifcfg-$iface");
        assert_script_run("ifbind.sh bind $iface");
        $self->setup_static_network($self->get_ip(is_wicked_ref => check_var('IS_WICKED_REF', 1), type => 'host'));
    }
    record_info($title, $text);
}

1;
