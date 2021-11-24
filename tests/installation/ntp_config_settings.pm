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

sub run {
    assert_screen ['ntp_config_settings', 'kubeadm-settings'];
    if (check_screen 'kubeadm-ntp-empty') {
        record_soft_failure 'bsc#1114818';
    }

    send_key 'alt-t';
    type_string '0.opensuse.pool.ntp.org';

    sleep 1;
    save_screenshot;
    send_key 'alt-n';
}

1;
