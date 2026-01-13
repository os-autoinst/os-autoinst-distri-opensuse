# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Apply local user's password for root user
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';
use Test::Assert ':all';

sub run {
    my $local_user = $testapi::distri->get_local_user();

    $local_user->use_same_password_for_admin();
    assert_true($local_user->is_use_same_password_for_admin);
}

1;

