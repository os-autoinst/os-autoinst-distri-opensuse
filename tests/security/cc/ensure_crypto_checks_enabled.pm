# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: ensure crypto checks are done on boot for common criteria installations
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#120894

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self, $run_args) = @_;
    select_console 'root-console';
    my $output = script_output "journalctl -u dracut-pre-pivot";
    record_info $output;
    die unless $output =~ /Checking integrity of kernel/m;
    die unless $output =~ /All initrd crypto checks done/m;
}

1;
