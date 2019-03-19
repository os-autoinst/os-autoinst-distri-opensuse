# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
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
use version_utils 'is_sle';

sub run {
    my $self = shift;

    if (get_var('AZURE')) {
        record_info("Azure don't have kGraft/LP infrastructure");
        return;
    }
    my $git_repo = get_required_var('QA_TEST_KLP_REPO');
    my ($test_type) = $git_repo =~ /qa_test_(\w+).git/;

    (is_sle(">12-sp1") || !is_sle) ? $self->select_serial_terminal() : select_console('root-console');
    zypper_call('ar -f -G ' . get_required_var('QA_HEAD_REPO') . ' qa_head');
    zypper_call('in -l bats hiworkload', exitcode => [0, 106, 107]);

    add_suseconnect_product("sle-sdk") if (is_sle('<12-SP5'));

    zypper_call('in -l git gcc kernel-devel make');

    assert_script_run('git clone ' . $git_repo);

    assert_script_run("cd qa_test_$test_type;bats $test_type.bats", 2760);
}

1;

=head1 Example configuration

=head2 QA_HEAD_REPO

RPM repository for used for hiworkload.
QA_HEAD_REPO=http://dist.nue.suse.com/ibs/QA:/Head/SLE-%VERSION%
QA_HEAD_REPO=http://dist.nue.suse.com/ibs/QA:/Head/openSUSE_%VERSION%

=head2 QA_TEST_KLP_REPO

Git repository for kernel live patching infrastructure tests.
QA_TEST_KLP_REPO=https://github.com/lpechacek/qa_test_klp.git

=cut
