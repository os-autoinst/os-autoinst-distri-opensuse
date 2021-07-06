# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Setup 'audit-test' test environment of a system with needed packages
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#93441

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use registration 'add_suseconnect_product';
use audit_test;

sub run {
    my ($self)   = @_;
    my $dir      = $audit_test::testdir;
    my $file_tar = $audit_test::testfile_tar . '.tar';

    select_console 'root-console';

    # Add needed modules
    add_suseconnect_product('sle-module-legacy');
    add_suseconnect_product('sle-module-desktop-applications');
    add_suseconnect_product('sle-module-development-tools');

    # Install needed packages/paterns
    zypper_call('in -t pattern devel_basis');
    zypper_call('in git expect libcap-devel psmisc cryptsetup');

    # Install vsftpd
    zypper_call('in vsftpd');

    # Install audit packages
    zypper_call('in audit audit-audispd-plugins');

    # Export MODE
    assert_script_run("export MODE=$audit_test::mode");

    # Download "audit-test"
    assert_script_run("wget --no-check-certificate $audit_test::code_repo -O ${dir}${file_tar}");
    assert_script_run("tar -xvf ${dir}${file_tar} -C ${dir}");
}

1;
