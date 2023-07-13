# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This module fetches the binary from defined URL in the OPENQA Variable
# EXTERNAL_TESTSUITE_URL and publishes the result in HDD
# Maintainer: QE Core <qe-core@suse.de>

use strict;
use warnings;
use File::Basename;
use Mojo::JSON qw(encode_json);
use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

my $testdir = '/usr/lib/test/external/';

sub run {
    my $systemd_suse_url = get_var("EXTERNAL_TESTSUITE_URL");    # Tarball location to do download
    select_serial_terminal;
    assert_script_run("mkdir -p  $testdir");
    assert_script_run("wget --no-check-certificate $systemd_suse_url -O $testdir" . basename($systemd_suse_url));
    assert_script_run("ls -l $testdir");
}

1;
