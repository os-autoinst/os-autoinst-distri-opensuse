# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Disable root ssh login due to CC hard requirement.
#          Only for s390x platform CC automation.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#105564

use base 'consoletest';
use testapi;
use utils;

sub run {
    my ($self, $run_args) = @_;

    select_console 'root-console';

    assert_script_run("sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config");
    systemctl('restart sshd');
}

1;
