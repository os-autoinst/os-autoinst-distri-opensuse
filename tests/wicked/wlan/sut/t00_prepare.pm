# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Wifi preparation
# Maintainer: cfamullaconrad@suse.com


use Mojo::Base 'wickedbase';
use testapi;

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    assert_script_run('modprobe mac80211_hwsim radios=2');
    assert_script_run('ip netns add wifi_master');
    assert_script_run('ip netns list');
    assert_script_run('iw dev');
    assert_script_run('iw phy phy0 set netns name wifi_master');
    assert_script_run('iw dev');
    assert_script_run('ip netns exec wifi_master iw dev');
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
