# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# All of cases is based on the reference:
# https://www.suse.com/documentation/sles-15/singlehtml/book_sle_admin/book_sle_admin.html#id-1.3.3.6.13.6.34
#
# Package: yast2-users yast2-nis-client ypbind yp-tools
# Summary: manages user accounts
#     Requirement: external NIS server "wotan.suse.de"
#     Key Steps:
#       - adds a new user with a password and verifies
#       - changes the passwd of the new user and homedir, and deletes this user
#       - binds a nis server and starts ypbind service, and then lists all users from NIS server
# Maintainer: Jun Wang <jgwang@suse.com>
#

use base 'y2_module_basetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my ($self) = @_;
    select_serial_terminal;
    zypper_call("in yast2-users yast2-nis-client ypbind", exitcode => [0, 102, 103, 106]);

    # adds a new user with a password and homedir and verifies
    # bsc#1143516: exit code is always NOT zero when the yast command works successfully, so once ZERO, it means a bug
    if (script_run("yast users add username=test_yast password=suse") != 0) {
        record_soft_failure("bsc#1143516 for SLE15+: exit code is NOT zero");
    }
    validate_script_output("yast users list local 2>&1 || echo BUG#1143516", sub { (m/test_yast/) and ((m/^BUG#1143516$/m) ? (!record_soft_failure("bsc#1143516 for SLE12SP2: exit code is NOT zero")) : return 1) }, timeout => 150);

    # changes the passwd of the new user and homedir, and delete this user
    assert_script_run("yast users edit username=test_yast new_uid=44444 home=/tmp/test_yast");
    validate_script_output("yast users show username=test_yast 2>&1", sub { m/44444/ and m/\/tmp\/test_yast/ }, timeout => 90, proceed_on_failure => 1);
    assert_script_run("yast users delete username=test_yast delete_home");

    # binds a nis server and start ypbind service, and then list all users from NIS server
    assert_script_run("yast nis enable domain=suse.de server=wotan.suse.de");
    my $nis_server = get_var('NAMESERVER');
    validate_script_output("ypwhich 2>&1", sub { m/((wotan|dns2).suse.de|$nis_server)/ });
    validate_script_output("yast users list nis 2>&1 | wc -l", sub { m/^(\d+)$/m and $1 > 20 }, timeout => 180, proceed_on_failure => 1);
    assert_script_run("yast nis disable");
}

1;
