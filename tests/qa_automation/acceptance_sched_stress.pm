# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: splite acceptance test into three to avoid timeout issue
# G-Maintainer: Yong Sun <yosun@suse.com>

use base "qa_run";
use strict;
use warnings;
use testapi;

sub test_run_list {
    return qw(_reboot_off sched_stress);
}

sub junit_type {
    return 'stress_validation';
}

sub test_suite {
    return 'acceptance';
}

1;

