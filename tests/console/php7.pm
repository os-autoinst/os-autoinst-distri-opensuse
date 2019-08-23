# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Simple PHP7 code hosted locally
#   This test requires the Web and Scripting module on SLE.
# - Setup apache2 to use php7 modules
# - Run "curl http://localhost/index.php", check output for "PHP Version 7"
# Maintainer: Ondřej Súkup <osukup@suse.cz>


use base "consoletest";
use strict;
use warnings;
use testapi;
use apachetest;

sub run {
    select_console 'root-console';
    setup_apache2(mode => 'PHP7');
    validate_script_output('curl http://localhost/index.php', sub { /PHP Version 7/ });
}
1;
