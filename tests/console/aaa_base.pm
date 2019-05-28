# SUSE"s openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: test that uses some aaa_base binaries command line tool to regression test.
# If succeed, the test passes without error.
#
# Maintainer: Marcelo Martins <mmartins@suse.cz>

use base "consoletest";
use strict;
use warnings;
use testapi;

sub run {
    select_console 'root-console';
    #create work dir
    assert_script_run "mkdir /tmp/aaa_base_test ; cd /tmp/aaa_base_test; touch test-file.txt ; mkdir test_dir";

    #test basic aaa_base commands, and verify if works when need.
    assert_script_run "old test-file.txt ; ls -lah test-file*";
    assert_script_run "safe-rm /tmp/aaa_base_test/test-file.txt; ls -lah";
    assert_script_run "safe-rmdir /tmp/aaa_base_test/test_dir; ls -lah";
    assert_script_run "get_kernel_version \$(ls /boot/vmlinu*-* | sort | tail -1)";
    assert_script_run "rpmlocate aaa_base";
    assert_script_run "/usr/sbin/sysconf_addword /etc/sysconfig/console CONSOLE_ENCODING ISO-8859-1 ; grep CONSOLE_ENCODING /etc/sysconfig/console";
    assert_script_run "/usr/sbin/sysconf_addword -r /etc/sysconfig/console CONSOLE_ENCODING ISO-8859-1; grep CONSOLE_ENCODING /etc/sysconfig/console";
    validate_script_output "service --status-all", sub { /loaded/ };

    # On SLES 15+ command returns empty. chkconfig only list SysV services only and does not include native
    # systemd services.
    assert_script_run "chkconfig --list";

    #Clean files used:
    assert_script_run "cd ; rm -rf /tmp/aa_base_test";
}

1;
