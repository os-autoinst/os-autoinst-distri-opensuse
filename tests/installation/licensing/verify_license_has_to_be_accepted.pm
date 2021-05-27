# Copyright (C) 2021 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: Test module is used to validate that installation cannot be
#          continued without accepted license and appropriate message is shown.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

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
