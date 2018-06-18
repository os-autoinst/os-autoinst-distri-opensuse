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
use registration;
use qam;

sub run {
    my $git_repo = get_required_var('QA_TEST_KLP_REPO');
    my ($test_type) = $git_repo =~ /qa_test_(\w+).git/;

    # Set and check patch variables
    my $incident_id = get_var('INCIDENT_ID');
    my $patch       = get_var('INCIDENT_PATCH');
    check_patch_variables($patch, $incident_id);

    select_console('root-console');
    zypper_call('ar -f -G ' . get_required_var('QA_HEAD_REPO') . ' qa_head');
    zypper_call('in -l bats hiworkload');

    if (check_var('DISTRI', 'sle') and ($patch or $incident_id)) {
        add_suseconnect_product("sle-sdk");
    }

    zypper_call('in -l git gcc kernel-devel make');

    assert_script_run('git clone ' . $git_repo);

    assert_script_run("cd qa_test_$test_type;bats $test_type.bats", 2760);
}

1;
