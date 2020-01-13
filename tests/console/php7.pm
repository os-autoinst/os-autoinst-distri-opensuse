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
use utils;
use testapi;
use apachetest;

sub run {
    select_console 'root-console';
    setup_apache2(mode => 'PHP7');
    assert_script_run('curl http://localhost/index.php | tee /tmp/tests-console-php7.txt');
    assert_script_run('grep "PHP Version 7" /tmp/tests-console-php7.txt');

    # test function provided by external module (php7-json RPM)
    zypper_call 'in php-json';
    assert_script_run('php -r \'echo json_encode(array("foo" => true))."\n";\' | grep :true');

    # test reading file
    assert_script_run('php -r \'echo readfile("/etc/hosts")."\n";\' | grep localhost');
}
1;
