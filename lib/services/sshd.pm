# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
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
