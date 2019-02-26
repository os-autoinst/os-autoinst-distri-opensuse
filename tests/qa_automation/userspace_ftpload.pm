# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Simple ftp setting check, and ftpload test by check md5sum.
# Maintainer: Zhao Jiang Tao <jtzhao@suse.com>

use base "qa_run";
use strict;
use warnings;
use testapi;

sub test_run_list {
    return qw(_reboot_off ftpload);
}

sub test_suite {
    return 'regression';
}

sub junit_type {
    return 'user_regression';
}

1;

