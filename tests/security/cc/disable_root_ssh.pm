# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Disable or enable root ssh login due to CC hard requirement.
#          Only for s390x platform CC automation.
# Maintainer: Liu Xiaojing <xiaojing.liu@suse.com>
# Tags: poo#105564

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self, $run_args) = @_;

    select_console 'root-console';

    my $switch = $run_args ? $run_args->{option} : 'no';
    assert_script_run("sed -i 's/^PermitRootLogin.*/PermitRootLogin $switch/' /etc/ssh/sshd_config");
    systemctl('restart sshd');
}

1;
