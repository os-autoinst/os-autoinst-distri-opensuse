# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Kubic kubeadm role configuration
# Maintainer: Martin Kravec <mkravec@suse.com>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    assert_screen 'kubeadm-settings';
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
