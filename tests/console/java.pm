# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
# Description: Basic Java test
# Summary: It installs every Java version which is available into
#	   the repositories and then it performs a series of basic
#          tests, such as verifying the version, compile and run
#          the Hello World program
# Maintainer: Panos Georgiadis <pgeorgiadis@suse.com>
# Maintainer: Andrej Semen <asemen@suse.com>
use strict;
use warnings;
use testapi;
use utils;
use base "consoletest";
sub run() {
    select_console 'root-console';
    zypper_call "in java-*";
    assert_script_run "wget --quiet " . data_url('console/test_java.sh');
    assert_script_run 'chmod +x test_java.sh';
    assert_script_run './test_java.sh';
}
1;
