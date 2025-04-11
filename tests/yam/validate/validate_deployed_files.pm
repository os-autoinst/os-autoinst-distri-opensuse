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
        '/usr/local/share/README.md' => {mode => '644', owner => 'root', sha256sum => 'cfadb6886121e27959b65a74044b2ca11bd6e2a96639c1244dd60d857171bf14'},
        '/etc/mongod.conf' => {mode => '644', owner => 'root', sha256sum => 'c7ed38f682068cdacf04c61783c3bdf034cd8703de0aa6a0b8c6796f5be3e62b'}
    );
    validate_script_output(qq|stat -c "%a %U %n" $_|, qr/$files{$_}->{mode} $files{$_}->{owner} $_/) for keys %files;
    validate_script_output(qq|sha256sum $_|, qr/$files{$_}->{sha256sum}\s+$_/) for keys %files;
}

1;
