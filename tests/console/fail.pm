# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: dracut
# Summary: Test dracut installation and verify that it works as expected
# Maintainer: qe-core@suse.de

use testapi;

sub run {
    assert_test_fails('This test is designed to always fail as requested.');
}

1;
