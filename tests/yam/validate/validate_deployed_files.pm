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

sub run {
    select_console 'root-console';
    # see tag <files> in data/yam/agama/auto/autoyast_supported.xml
    my %files = (
        '/usr/local/share/dummy.xml' => {
            mode => '644',
            owner => 'root',
            sha256sum => '5f925f748a27b757853767477ec0e0e6f04b1727f3607c7f622a2a1e4bd2a0e5'
        },
        '/etc/mongod.conf' => {
            mode => '644',
            owner => 'root',
            sha256sum => 'c7ed38f682068cdacf04c61783c3bdf034cd8703de0aa6a0b8c6796f5be3e62b'
        }
    );

    for my $file (keys %files) {
        validate_script_output(qq|stat -c "%a %U %n" $file|, qr/$files{$file}->{mode} $files{$file}->{owner} $file/);
        validate_script_output(qq|sha256sum $file|, qr/$files{$file}->{sha256sum}\s+$file/);
    }
}

1;
