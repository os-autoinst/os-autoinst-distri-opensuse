# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Disable root ssh login due to CC hard requirement
#          This test is needed on s390x SLE platform only
#
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#99096

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console "root-console";
    assert_script_run("sed -i 's/^PermitRootLogin.*\$/#/' /etc/ssh/sshd_config");
    assert_script_run("echo 'PermitRootLogin no' >> /etc/ssh/sshd_config");
    assert_script_run("systemctl restart sshd");
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
