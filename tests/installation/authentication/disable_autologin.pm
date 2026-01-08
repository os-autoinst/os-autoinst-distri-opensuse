# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Disable automatic login during user creation
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';
use Test::Assert ':all';

sub run {
    my $local_user = $testapi::distri->get_local_user();

    $local_user->disable_automatic_login();
    assert_false($local_user->is_autologin());
}

1;
