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
    assert_script_run("for dev in /sys/class/net/!(lo); do grep \"$status\" \$dev/operstate || (echo \"device \$dev is not $status\" && exit 1) ; done");
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
    my $log_name = join('', map { ("a" .. "z")[rand 26] } 1 .. 8);
    assert_script_run("journalctl -o short-precise > /tmp/$log_name.log");
    upload_logs("/tmp/$log_name.log");
}

sub get_from_data {
    my ($self, $source, $target, %args) = @_;
    $source .= check_var('IS_WICKED_REF', '1') ? 'ref' : 'sut' if $args{add_suffix};
    assert_script_run("wget --quiet " . data_url($source) . " -O $target");
    assert_script_run("chmod +x $target") if $args{executable};
}

1;
