# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Record machine-id
# Maintainer: Michal Nowak <mnowak@suse.com>

use base 'opensusebasetest';
use testapi;

sub run {
    select_console 'root-console';

    my $machine_id = script_output('cat /etc/machine-id');
    record_info('/etc/machine-id', $machine_id);
}

1;
