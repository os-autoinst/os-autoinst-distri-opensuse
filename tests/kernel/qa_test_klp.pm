# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Package: autoconf automake gcc git-core make
# Summary: Tests for kernel live patching infrastructure
# Maintainer: Ondřej Súkup <osukup@suse.cz>

use strict;
use warnings;
use File::Basename 'basename';

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

    if (script_run('[ -d /lib/modules/$(uname -r)/build ]') != 0) {
        zypper_call('in -l kernel-devel');
    }

    my $git_repo = get_required_var('QA_TEST_KLP_REPO');
    my $dir      = basename($git_repo);
    $dir =~ s/\.git$//;

    (is_sle(">12-sp1") || !is_sle) ? $self->select_serial_terminal() : select_console('root-console');

    add_suseconnect_product("sle-sdk") if (is_sle('<12-SP5'));
    zypper_call('in -l autoconf automake gcc git make');

    assert_script_run('git config --global http.sslVerify false');
    assert_script_run('git clone ' . $git_repo);
    assert_script_run("cd $dir && ./run.sh", 2760);
}

1;

=head1 Example configuration

=head2 QA_TEST_KLP_REPO

Git repository for kernel live patching infrastructure tests.
QA_TEST_KLP_REPO=https://github.com/lpechacek/qa_test_klp.git

=cut
