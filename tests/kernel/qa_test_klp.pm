# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Tests for kernel live patching infrastructure
# Maintainer: Ondřej Súkup <osukup@suse.cz>

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;
use utils;

sub run {

    select_console('root-console');
    zypper_call('ar -f -G ' . get_required_var('QA_HEAD_REPO') . ' qa_head');
    zypper_call('in -l bats');

    if (check_var('DISTRI', 'sle') and get_var('INCIDENT_PATCH', '')) {
        my $version = get_required_var('VERSION') =~ s/-SP/\./gr;
        my $arch    = get_required_var('ARCH');
        assert_script_run("SUSEConnect -p sle-sdk/" . $version . "/" . $arch);
    }

    zypper_call('in -l git gcc kernel-devel');

    assert_script_run('git clone ' . get_var('QA_TEST_KLP_REPO'));

    assert_script_run('cd qa_test_klp;bats klp.bats');
}

1;
