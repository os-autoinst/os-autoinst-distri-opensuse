# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Check available kubernetes-client versions
#
# Maintainer: QE-C team <qa-c@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    my ($self, $args) = @_;

    select_serial_terminal;

    my $versions = script_output('zypper search kubernetes*client | grep -Eo "[0-9]\.[0-9]{2}" | xargs echo');
    if ($versions ne get_required_var("KUBERNETES_VERSIONS")) {
        record_soft_failure("poo#184447 - Must set KUBERNETES_VERSIONS=\"$versions\"");
    }
}

sub test_flags {
    return {fatal => 0};
}

1;
