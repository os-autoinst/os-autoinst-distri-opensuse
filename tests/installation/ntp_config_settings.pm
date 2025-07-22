# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: YaST/Installation screen: NTP Configuration
# Maintainer: Martin Kravec <mkravec@suse.com>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use version_utils qw(is_tumbleweed is_microos is_leap_micro);

sub run {
    assert_screen('ntp_config_settings');

    my $ntp_pool = (is_microos || is_tumbleweed || is_leap_micro) ? 'opensuse-pool' : 'suse-pool';
    # ipmi backend is linked to physical machine which can have ntp ip address offered by dhcp
    assert_screen($ntp_pool) unless (get_var('BACKEND', '') eq 'ipmi' and check_var('VIDEOMODE', 'text'));

    send_key 'alt-n';
}

1;
