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

# Summary: Test module to validate beta popup and accept it.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use Test::Assert ':all';

sub run {
    my $warnings = $testapi::distri->get_warnings_controller();
    assert_matches(qr/You are accessing our Beta Distribution/, $warnings->get_text(),
        "Warning Dialog for BETA did not appear, while it was expected.");
    $warnings->accept_warning();
}

1;
