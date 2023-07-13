# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check which ifcfg wireless configuration will create a valid
#          wicked XML wireless configuration.
#
# Maintainer: cfamullaconrad@suse.com


use Mojo::Base 'wicked::wlan';
use testapi;
use serial_terminal 'select_serial_terminal';

has wicked_version => '>=0.6.66';
has stderr_file => '/tmp/wicked_stderr';

has ifcfg_wlan_enabled => sub { [
        q(
            WIRELESS=yes
        ),
        q(
            WIRELESS=true
        ),
        q(
            WIRELESS=On
        ),
        q(
            WIRELESS=1
        ),
        q(
            WIRELESS=no_valid_value
            WIRELESS_ESSID="FOO"
        ),
        q(
            WIRELESS=""
            WIRELESS_ESSID="FOO"
        ),
        q(
            WIRELESS_ESSID="FOO"
        )
] };

has ifcfg_wlan_disabled => sub { [
        q(
            WIRELESS=FALSE
            WIRELESS_ESSID="FOO"
        ),
        q(
            WIRELESS=no
            WIRELESS_ESSID="FOO"
        ),
        q(
            WIRELESS=0
            WIRELESS_ESSID="FOO"
        ),
        q(
            WIRELESS=off
            WIRELESS_ESSID="FOO"
        ),
        q(
            WIRELESS=no_valid_value
        ),
        q(
            WIRELESS=""
        ),
        q(
            BOOTPROTO="none"
        ),
] };


sub check_error {
    my ($self, $expect_error) = @_;

    if ($expect_error) {
        assert_script_run('grep no_valid_value ' . $self->stderr_file);
    } else {
        assert_script_run('! grep no_valid_value ' . $self->stderr_file);
    }
}


sub run {
    my $self = shift;
    select_serial_terminal;
    return if ($self->skip_by_wicked_version());

    for my $config (@{$self->ifcfg_wlan_enabled}) {
        $self->write_cfg('/etc/sysconfig/network/ifcfg-' . $self->sut_ifc, $config);
        assert_script_run('wicked show-config ' . $self->sut_ifc . ' 2> ' . $self->stderr_file . ' | grep -E "<wireless/?>"');
        $self->check_error($config =~ /no_valid_value/);
    }

    for my $config (@{$self->ifcfg_wlan_disabled}) {
        $self->write_cfg('/etc/sysconfig/network/ifcfg-' . $self->sut_ifc, $config);
        assert_script_run('! wicked show-config ' . $self->sut_ifc . ' 2> ' . $self->stderr_file . ' | grep -E "<wireless/?>"');
        $self->check_error($config =~ /no_valid_value/);
    }
}

1;
