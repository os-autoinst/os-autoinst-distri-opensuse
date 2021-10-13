# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Package for ssh service tests
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package services::sshd;
use base 'opensusebasetest';
use testapi;
use utils;
use strict;
use warnings;

sub check_sshd_port {
    assert_script_run q(ss -pnl4 | egrep 'tcp.*LISTEN.*:22.*sshd');
    assert_script_run q(ss -pnl6 | egrep 'tcp.*LISTEN.*:22.*sshd');
}

sub check_sshd_service {
    systemctl 'show -p ActiveState sshd|grep ActiveState=active';
    systemctl 'show -p SubState sshd|grep SubState=running';
}

1;
