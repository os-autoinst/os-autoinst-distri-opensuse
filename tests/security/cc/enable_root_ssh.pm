# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Enable root ssh login before reboot.
#          Only for s390x platform CC automation.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#105564

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self, $run_args) = @_;

    select_console 'root-console';

    assert_script_run("sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config");
    systemctl('restart sshd');
}

1;
