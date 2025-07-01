# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate files section.
# Check the existence of the file(s) and its attributes.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use scheduler 'get_test_suite_data';

sub run {
    my $test_data = get_test_suite_data();
    select_console 'root-console';

    for my $file (@{$test_data->{files}}) {
        validate_script_output(qq|stat -c "%a %U %n" $file->{path}|, qr/$file->{mode} $file->{owner} $file->{path}/);
        validate_script_output(qq|sha256sum $file->{path}|, qr/$file->{sha256sum}\s+$file->{path}/);
    }
}

1;
