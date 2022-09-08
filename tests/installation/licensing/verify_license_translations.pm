# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

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
    my ($self) = @_;
    my $test_data = get_test_suite_data();
    my $license_agreement = $testapi::distri->get_license_agreement();

    my $license_agreement_info = $license_agreement->collect_current_license_agreement_info();
    my $default_language = $license_agreement_info->{language};

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
            record_soft_failure("EULA content for the language: '$translation->{language}' didn't validate. See bsc#1203004 for details.\n");
            diag("EULA validation failed:\nExpected:\n$translation->{text}\nActual:\n$license_agreement_info->{text}\n\n");
        }
    }
    # Set language back to default
    $license_agreement->select_language($default_language);

    # Assert no errors
    assert_true(!$errors, $errors);
}

sub test_flags {
    return {fatal => 0};
}

1;
