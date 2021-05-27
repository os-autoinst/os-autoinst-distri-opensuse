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

use base 'y2_installbase';
use strict;
use warnings;
use scheduler 'get_test_suite_data';
use testapi;
use List::Util 'first';
use Test::Assert 'assert_true';

sub run {
    my ($self)            = @_;
    my $test_data         = get_test_suite_data();
    my $license_agreement = $testapi::distri->get_license_agreement();

    my $license_agreement_info = $license_agreement->collect_current_license_agreement_info();
    my $default_language       = $license_agreement_info->{language};

    # Accumulate errors
    my $errors = '';
    if ($test_data->{license}->{language} ne $default_language) {
        $errors = "Wrong EULA language is pre-selected, " .
          "expected: $test_data->{license}->{default}, actual: $license_agreement_info->{language}.\n";
    }

    my @available_translations = @{$license_agreement_info->{available_languages}};
    foreach my $translation (@{$test_data->{license}->{translations}}) {
        unless (first { $_ eq $translation->{language} } @available_translations)
        {
            $errors .= "Language: '$translation->{language}' cannot be found in the list of available EULA translations.\n";
            next;
        }

        # Select language and validate translation
        $license_agreement->select_language($translation->{language});
        $license_agreement_info = $license_agreement->collect_current_license_agreement_info();
        if ($license_agreement_info->{text} !~ /$translation->{text}/) {
            $errors .= "EULA content for the language: '$translation->{language}' didn't validate. Please, see autoints-log for the detailed content of EULA\n";
            diag("EULA validation failed:\nExpected:\n$translation->{text}\nActual:\n$license_agreement_info->{text}\n\n");
        }
    }
    # Assert no errors
    assert_true(!$errors, $errors);
    # Set language back to default
    $license_agreement->select_language($default_language);
}

1;
