# SUSE"s openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: aaa_base
# Summary: test that uses some aaa_base binaries command line tools to regression test.
# - Creates directory /tmp/aaa_base_test
# - Changes to /tmp/aaa_base_test directory
# - Creates test-file.txt and test_dir
# - run command "old test-file.txt", after, ls -lah test-file*
# - run safe-rm /tmp/aaa_base_test/test-file.txt; then ls -lah
# - run safe-rmdir /tmp/aaa_base_test/test_dir; then ls -lah
# - run get_kernel_version \$(ls /boot/vmlinu*-* | sort | tail -1)
# - run rpmlocate aaa_base
# - run /usr/sbin/sysconf_addword /etc/sysconfig/console CONSOLE_ENCODING
# ISO-8859-1; grep CONSOLE_ENCODING /etc/sysconfig/console
# - run /usr/sbin/sysconf_addword -r /etc/sysconfig/console CONSOLE_ENCODING ISO-8859-1;
# grep CONSOLE_ENCODING /etc/sysconfig/console
# - run service --status-all, checks for "loaded"
# - remove /tmp/aa_base_test directory
# Maintainer: Marcelo Martins <mmartins@suse.cz>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    my $self = shift;
    select_serial_terminal;

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

    #Clean files used:
    assert_script_run "cd ; rm -rf /tmp/aa_base_test";
}

1;
