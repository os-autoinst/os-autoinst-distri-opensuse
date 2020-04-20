# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
# Description: Basic Java test
# Summary: It installs every Java version which is available into
#          the repositories and then it performs a series of basic
#          tests, such as verifying the version, compile and run
#          the Hello World program
# - Stop packagekit service
# - Install java packages according to system
# - Download test_java.sh from data dir and execute
# Maintainer: Panos Georgiadis <pgeorgiadis@suse.com>
# Maintainer: Andrej Semen <asemen@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils qw(pkcon_quit zypper_call);
use version_utils qw(is_sle is_leap is_opensuse);
use registration qw(add_suseconnect_product remove_suseconnect_product);
use main_common 'is_updates_tests';

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    # Make sure that PackageKit is not running
    pkcon_quit;
    # if !QAM test suite then register Legacy module
    (is_updates_tests || is_opensuse) || add_suseconnect_product('sle-module-legacy');
    # Supported Java versions for sle15sp2
    # https://www.suse.com/releasenotes/x86_64/SUSE-SLES/15-SP2/#development-java-versions
    # java-11-openjdk                   -> Basesystem
    # java-10-openjdk & java-1_8_0-ibm  -> Legacy
    my $cmd = 'install --auto-agree-with-licenses ';
    $cmd .= (is_sle('15+') || is_leap) ? 'java-11-openjdk* java-1_*' : 'java-*';
    zypper_call($cmd, timeout => 1500);

    if (script_run 'rpm -q wget') {
        zypper_call 'in wget';
    }
    assert_script_run 'wget --quiet ' . data_url('console/test_java.sh');
    assert_script_run 'chmod +x test_java.sh';
    assert_script_run './test_java.sh';
    # if !QAM test suite then cleanup test suite environment
    unless (is_updates_tests || is_opensuse) {
        remove_suseconnect_product('sle-module-legacy');
        (script_run 'rpm -qa | grep java-1_') || zypper_call('rm java-1_*');
    }
}

sub post_fail_hook {
    select_console 'log-console';
    upload_logs '/var/log/zypper.log';
    upload_logs '/var/log/zypp/history';
}

1;
