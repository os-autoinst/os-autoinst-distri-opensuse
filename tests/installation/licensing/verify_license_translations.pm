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
#     - language: Greek
#       text: γεια σας
#     - language: French
#       text: Bonjour
#     - language: Russian
#       text: Привет
#     - language: Spanish
#       text: Hola
#     - language: Ukranian
#       text: Привіт

# Maintainer: QE YaST <qa-sle-yast@suse.de>

use strict;
use warnings;
use base 'y2_installbase';
use scheduler 'get_test_suite_data';
use testapi;
use List::Util 'first';
use Test::Assert 'assert_true';

sub run {
    my ($self) = @_;

    my $test_data       = get_test_suite_data();
    my $eula_controller = $testapi::distri->get_eula_controller();
    my $eula_page       = $eula_controller->get_license_agreement_page();

    # Accumulate errors
    my $errors           = '';
    my $default_language = $eula_page->get_selected_language();

    if ($test_data->{license}->{default} ne $default_language) {
        $errors = "Wrong EULA language is pre-selected, " .
          "expected: $test_data->{license}->{default}, actual: $default_language.\n";
    }

    my @available_translations = $eula_page->get_available_languages();

    foreach my $translation (@{$test_data->{license}->{translations}}) {
        unless (first { $_ eq $translation->{language} } @available_translations)
        {
            $errors .= "Language: '$translation->{language}' cannot be found in the list of available EULA translations.\n";
            next;
        }
        # Select language and validate translation
        $eula_page->select_language($translation->{language});
        my $eula_txt = $eula_page->get_eula_content();
        if ($eula_txt !~ /$translation->{text}/) {
            $errors .= "EULA content for the language: '$translation->{language}' didn't validate. Please, see autoints-log for the detailed content of EULA\n";
            diag("EULA validation failed:\nExpected:\n$translation->{text}\nActual:\n$eula_txt\n\n");
        }
    }
    # Assert no errors
    assert_true(!$errors, $errors);
    # Set language back to default
    $eula_page->select_language($default_language);
}

1;
