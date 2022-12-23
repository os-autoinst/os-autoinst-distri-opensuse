# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Test module is used to validate that installation cannot be
#          continued without accepted license and appropriate message is shown.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use Test::Assert 'assert_true';

sub run {
    my $accept_license_popup = $testapi::distri->get_license_agreement()
      ->proceed_without_explicit_agreement();
    assert_true($accept_license_popup->is_shown(),
        'Accept License popup is not shown when license is not explicitly accepted.');
    $accept_license_popup->press_ok();
}

1;
