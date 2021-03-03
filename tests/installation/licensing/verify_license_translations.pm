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

# Summary: Test module is used to validate available EULA translations as well
#          as a translation selected by default. Test module is test data driven
#          and following structure should be used:
# license:
#   default: English (US)
#   translations:
#     - Greek
#     - French
#     - Russian
#     - Spanish
#     - Ukranian

# Maintainer: QE YaST <qa-sle-yast@suse.de>

use strict;
use warnings;
use base 'y2_installbase';
use scheduler 'get_test_suite_data';
use testapi;
use List::Util 'first';
use Test::Assert ':all';

sub run {
    my ($self) = @_;

    my $test_data = get_test_suite_data();

    my $eula_controller = $testapi::distri->get_eula_controller();
    my $eula_page       = $eula_controller->get_license_agreement_page();

    assert_str_equals($test_data->{license}->{default}, $eula_page->get_selected_language(),
        "Wrong EULA language is pre-selected");
    my @available_translations = $eula_page->get_available_languages();
    # Accumulate errors
    my $errors = '';
    foreach my $language (@{$test_data->{license}->{translations}}) {
        unless (first { /$language/ } @available_translations)
        {
            $errors += "Language: $language cannot be found in the list of available EULA translations\n";
        }
    }

    die "$errors" if $errors;
}

1;
