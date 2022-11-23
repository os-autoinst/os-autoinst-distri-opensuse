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
use version_utils qw(is_tumbleweed is_microos);

sub run {
    assert_screen('ntp_config_settings');

    my $ntp_pool = (is_microos || is_tumbleweed) ? 'opensuse-pool' : 'suse-pool';
    assert_screen($ntp_pool);

    send_key 'alt-n';
}

1;
