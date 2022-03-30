# Copyright 2020-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test "# audit2allow" command with options
#          "-a / -i / -w / -R / -M / -r" can work
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#61792, tc#1741285

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle);
use registration qw(add_suseconnect_product);

sub run {
    my ($self) = @_;
    my $testfile = "test_file";
    my $test_module = "test_module";
    my $original_audit = "/var/log/audit/audit.log";
    my $audit_log = "/var/log/audit/audit.txt";
    my $audit_log_short = "/var/log/audit/audit.short.txt";

    $self->select_serial_terminal;

    assert_script_run("systemctl restart auditd");

    # read input from logs and translate to why
    assert_script_run("cp $original_audit $audit_log");
    validate_script_output("audit2allow -a", sub { m/allow\ .*_t\ .*;.*/sx });
    validate_script_output("audit2allow -i $audit_log", sub { m/allow\ .*_t\ .*;.*/sx });
    assert_script_run("tail -n 500 $audit_log > $audit_log_short");
    validate_script_output(
        "audit2allow -w -i $audit_log_short",
        sub {
            m/
	    type=.*AVC.*denied.*
	    Was\ caused\ by:.*
	    You\ can\ use\ audit2allow\ to\ generate\ a\ loadable\ module\ to\ allow\ this\ access.*/sx
        }, 600);

    # upload aduit log for reference
    upload_logs($audit_log);
    upload_logs($audit_log_short);

    # create an SELinux module, make this policy package active, check the new added module
    validate_script_output(
        "cat $audit_log_short | audit2allow -M $test_module",
        sub {
            m/
            To\ make\ this\ policy\ package\ active,\ execute:.*
            semodule\ -i\ $test_module.*\./sx
        }, 600);
    assert_script_run("semodule\ -i ${test_module}.pp");
    validate_script_output("semodule -lfull", sub { m/$test_module\ .*pp.*/sx });

    # remove the new added module for a cleanup, and check the cleanup
    assert_script_run("semodule -r $test_module", sub { m/Removing.*\ $test_module\ .*/sx });
    my $ret = script_run("semodule -lfull | grep ${test_module}");
    if (!$ret) {
        die "ERROR:\ \"$test_module\"\ module\ was\ not\ removed!";
    }

    if (is_sle('>=15')) {
        # generate reference policy using installed macros
        # install needed pkgs for interface
        add_suseconnect_product("sle-module-desktop-applications");
        add_suseconnect_product("sle-module-development-tools");
        zypper_call("in policycoreutils-devel");
    } elsif (is_sle('<15')) {
        zypper_call("in selinux-policy-devel");
    } else {
        zypper_call("in policycoreutils-devel");
    }

    # call sepolgen-ifgen to generate the interface descriptions
    assert_script_run("sepolgen-ifgen");
    # run "# audit2allow -R" to generate reference policy and verify the policy format
    # NOTE: the output depends on the contents of audit log it may change at any time
    #       so only check the policy format is OK
    # as suggested in bsc#1196116: Run it once without -R and check for allow,
    # then run it with -R again and check if you see calls to interfaces (need to check
    # if the second one is stable enough)
    validate_script_output(
        "audit2allow -i $audit_log_short",
        sub {
            m/
            .*#=============.*==============.*
            .*allow.*/sx
        }, 600);
    validate_script_output(
        "audit2allow -R -i $audit_log_short",
        sub {
            m/
            .*require\ \{.*
            .*type\ .*_t;.*
            #=============.*==============.*/sx
        }, 600);
}

1;
