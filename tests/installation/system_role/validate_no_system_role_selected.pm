# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Test module to validate that no system role is pre-selected in
# openSUSE.
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';
use Test::Assert 'assert_null';

sub run {
    assert_null(
        $testapi::distri->get_system_role()->get_selected_role(),
        'A System Role is pre-selected, none expected');
}

1;
