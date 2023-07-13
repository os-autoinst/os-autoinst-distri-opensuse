package login;

# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: login console
# Maintainer: Tony Yuan <tyuan@suse.com>, qe-virt@suse.com

use base 'consoletest';
use strict;
use warnings;
use testapi;
use lib 'sle/tests/virt_autotest';
use lib 'os-autoinst-distri-opensuse/tests/virt_autotest';

sub run {
    my $self = shift;
    select_console 'root-ssh';
    record_info("console logined");
}
1;
