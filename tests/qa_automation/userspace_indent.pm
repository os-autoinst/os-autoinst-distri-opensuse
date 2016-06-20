# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "qa_run";
use strict;
use testapi;

sub test_run_list() {
    return qw(_reboot_off indent);
}

sub test_suite() {
    return 'regression';
}

sub junit_type() {
    return 'user_regression';
}

1;

