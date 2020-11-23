# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: [...]
# Maintainer: Michael Grifalconi <mgrifalconi@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils;
use repo_tools 'generate_version';
use version_utils 'is_sle';

sub run {
    #Preparation
    my $self = shift;
    $self->select_serial_terminal;

    #On SLE, get the latest sources to make sure the test patches are up to date
    #if (is_sle) {
      #      my $repo_url = 'http://download.suse.de/ibs/home:/adamm:/node_test/' . generate_version() . '/';
      #zypper_ar($repo_url, name => 'node', priority => 1);
      #}
    my $os_version = generate_version();
    #TODO: openSUSE, now assumes is SLE
   
    # Get test script and run it
    assert_script_run 'wget --quiet ' . data_url('console/test_node.sh');
    assert_script_run 'chmod +x test_node.sh';
    assert_script_run './test_node.sh ' . $os_version, 900; 
}


1;
