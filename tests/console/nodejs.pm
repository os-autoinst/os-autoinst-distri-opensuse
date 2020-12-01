# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: NodeJS test to run specific checks availalble on the source code 
#          about TLS to avoid regressions due to OpenSSL updates.
#          The test will:
#          - Check the latest nodejs package available and install it
#          - Download latest sources of the package from IBS
#          - Apply patches to the sources
#          - Run the crypto and tls tests.
#          - List eventually failed test in the end
# Maintainer: Michael Grifalconi <mgrifalconi@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils;
use repo_tools 'generate_version';

sub run {
    #Preparation
    my $self = shift;
    $self->select_serial_terminal;

    my $os_version = generate_version();

    # Get test script and run it
    assert_script_run 'wget --quiet ' . data_url('console/test_node.sh');
    assert_script_run 'chmod +x test_node.sh';
    assert_script_run './test_node.sh ' . $os_version, 900; 
}


1;
