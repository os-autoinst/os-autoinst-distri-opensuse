# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Setup 'audit-test' test environment of a system with needed packages
# Maintainer: QE Security <none@suse.de>
# Tags: poo#93441, poo#104070

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_text_console';
use utils;
use package_utils 'install_package';
use registration 'add_suseconnect_product';
use audit_test;
use version_utils qw(is_sle is_tumbleweed);

sub run {
    my ($self) = @_;
    my $tmp_dir = $audit_test::tmp_dir;
    my $test_dir = $audit_test::test_dir;
    my $file_tar = $audit_test::testfile_tar . '.tar';
    my $audit_service = is_tumbleweed ? 'audit-rules' : 'auditd';

    select_text_console;

    unless (check_var('FLAVOR', 'Full-QR')) {
        if (script_run('which SUSEConnect') != 0) {
            record_soft_failure('bsc#1193782 - SUSEConnect is not installed when system role is common criteria');
            install_package('SUSEConnect', trup_reboot => 1);
        }

        add_suseconnect_product('sle-module-legacy');
        add_suseconnect_product('sle-module-desktop-applications');
        add_suseconnect_product('sle-module-development-tools');
    }
    # install_package does not pass its default timeout to trup_call, which has a
    # default of 180 seconds only. The pattern and the list are big.
    install_package('-t pattern devel_basis', timeout => 900);

    # On transactional systems, add the packages to the same snapshot as the pattern, then reboot once
    my $pkexec_package = is_sle('<15-SP5') ? "polkit" : "pkexec";
    install_package("git expect libcap-devel psmisc cryptsetup $pkexec_package vsftpd audit audit-audispd-plugins wget iputils curl netcat-openbsd", trup_continue => 1, trup_reboot => 1, timeout => 900);

    # Workaround for restarting audit service. Use a drop-in, because /usr
    # is read-only on transactional systems.
    assert_script_run('mkdir -p /etc/systemd/system/auditd.service.d');
    assert_script_run('printf "[Unit]\nStartLimitIntervalSec=0\n" > /etc/systemd/system/auditd.service.d/10-start-limit.conf');
    assert_script_run('systemctl daemon-reload');

    # Modify audit rules
    assert_script_run('sed -i \'s/-a task,never/#&/\' /etc/audit/rules.d/audit.rules');
    assert_script_run("systemctl restart $audit_service");

    # Download "audit-test", be aware of umask=0077 for cc role based system
    assert_script_run("wget --no-check-certificate $audit_test::code_repo -O ${tmp_dir}${file_tar}");
    assert_script_run("tar -xvf ${tmp_dir}${file_tar} -C ${tmp_dir}");
    assert_script_run("mv ${tmp_dir}/$audit_test::testfile_tar ${test_dir}");
    assert_script_run("chmod 755 ${test_dir}");
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
