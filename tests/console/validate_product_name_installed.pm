# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Validate name of the installed product via /etc/os-release
# Maintainer: QA SLE YaST <qa-sle-yast@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use scheduler 'get_test_suite_data';
use Config::Tiny;
use Test::Assert ':all';

sub run {
    my $product = get_test_suite_data()->{product};
    select_console 'root-console';

    my $os_release_output = script_output('cat /etc/os-release');
    my $os_release_name   = Config::Tiny->read_string($os_release_output)->{_}->{NAME};
    assert_equals("\"$product\"", $os_release_name, 'Wrong product NAME in /etc/os-release');
}

1;
