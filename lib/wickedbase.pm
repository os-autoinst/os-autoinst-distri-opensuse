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
    my ($self, $no_mask) = @_;
    if ($no_mask) {
        return check_var('IS_WICKED_REF', '1') ? '10.0.2.10' : '10.0.2.11';
    }
    else {
        return check_var('IS_WICKED_REF', '1') ? '10.0.2.10/15' : '10.0.2.11/15';
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

1;
