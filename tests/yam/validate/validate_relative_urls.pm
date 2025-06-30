# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate relative URLs.
# Check the support of relative URLs, based on the URL of the profile.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use scheduler 'get_test_suite_data';

sub run {
    my $test_data = get_test_suite_data();
    select_console 'root-console';
    # see section "files" in data/yam/agama/auto/lib/base.libsonnet

    for my $file (@{$test_data->{files}}) {
        script_output(qq|ls -l $file->{path}; stat $file->{path}; cat $file->{path}|);
        validate_script_output(qq|stat -c "%a %U %n" $file->{path}|, qr/$file->{mode} $file->{owner} $file->{path}/);
        validate_script_output(qq|sha256sum $file->{path}|, qr/$file->{sha256sum}\s+$file->{path}/);
    }
}

1;
