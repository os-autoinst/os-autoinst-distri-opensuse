# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: OpenSSL update regression test using NodeJS tls and crypto tests
#          The test will:
#          - Check the latest nodejs package and sources available and install it
#          - Apply patches to the sources
#          - Run the crypto and tls tests.
#          - List eventually skipped and failed test
# Maintainer: Michael Grifalconi <mgrifalconi@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use repo_tools 'generate_version';
use version_utils qw(is_sle);
use registration qw(add_suseconnect_product);

sub run {
    #Preparation
    my $self = shift;
    $self->select_serial_terminal;

    my $os_version = generate_version();
    assert_script_run 'wget --quiet ' . data_url('console/test_openssl_nodejs.sh');
    assert_script_run 'chmod +x test_openssl_nodejs.sh';
    assert_script_run "./test_openssl_nodejs.sh $os_version", 900;
}

1;
