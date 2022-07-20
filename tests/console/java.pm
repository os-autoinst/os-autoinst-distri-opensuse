# SUSE's openQA tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Description: Basic Java test
# Package: java-11-openjdk* java-1_* java-*
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
use utils qw(quit_packagekit zypper_call);
use version_utils qw(is_sle is_leap is_opensuse is_transactional);
use registration qw(add_suseconnect_product remove_suseconnect_product);
use main_common qw(is_updates_tests is_migration_tests);
use transactional qw(check_reboot_changes trup_call);

my $arch = get_var('ARCH');
# Transform the format of the version, e.g. from 15-SP3 to 15.3
my $version = get_var('VERSION');
my $version_id = (split('-', $version))[0] . '.' . (split('P', (split('-', $version))[1]))[1];

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    # Make sure that PackageKit is not running
    quit_packagekit;
    # if !QAM test suite then register Legacy module
    if (is_sle && !(is_updates_tests || is_migration_tests)) {
        if (is_transactional) {
            trup_call("register -p sle-module-legacy/$version_id/$arch");
        } else {
            add_suseconnect_product('sle-module-legacy');
        }
    }

    # Supported Java versions for sle15sp1+ and sle12sp5
    # https://www.suse.com/releasenotes/x86_64/SUSE-SLES/15-SP2/#development-java-versions
    # https://www.suse.com/releasenotes/x86_64/SUSE-SLES/12-SP5/index.html#TechInfo.Java
    # java-11-openjdk                   -> Basesystem
    # java-10-openjdk & java-1_8_0-ibm  -> Legacy
    my $cmd = 'install --auto-agree-with-licenses ';
    $cmd .= (is_sle('15+') || is_sle('=12-SP5') || is_leap) ? 'java-11-openjdk* java-1_*' : 'java-*';

    if (is_transactional) {
        select_console 'root-console';
        trup_call("--continue pkg $cmd", 2000);
        check_reboot_changes;
        reset_consoles;
        select_console('root-console', 200);
    }
    else {
        zypper_call($cmd, timeout => 2000);
        zypper_call 'in wget' if (script_run 'rpm -q wget');
    }
    assert_script_run 'wget --quiet ' . data_url('console/test_java.sh');
    assert_script_run 'chmod +x test_java.sh';
    assert_script_run('./test_java.sh' . (is_transactional ? ' --transactional-server' : ''), timeout => 180);

    # if !QAM test suite then cleanup test suite environment
    unless (is_updates_tests || is_opensuse || is_migration_tests) {
        if (is_transactional) {
            trup_call("register -d -p sle-module-legacy/$version_id/$arch");
            (script_run 'rpm -qa | grep java-1_') || trup_call('pkg remove --no-confirm java-1_*');
        }
        else {
            remove_suseconnect_product('sle-module-legacy');
            (script_run 'rpm -qa | grep java-1_') || zypper_call('rm java-1_*');
        }
    }
}

sub post_fail_hook {
    select_console 'log-console';
    upload_logs '/var/log/zypper.log';
    upload_logs '/var/log/zypp/history';
}

1;
