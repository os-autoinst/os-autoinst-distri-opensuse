# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Record machine-id
# Maintainer: Michal Nowak <mnowak@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;

sub run {
    select_console 'root-console';

    my $machine_id = script_output('cat /etc/machine-id');
    record_info('/etc/machine-id', $machine_id);
}

1;
