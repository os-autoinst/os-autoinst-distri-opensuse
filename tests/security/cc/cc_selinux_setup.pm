# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Setup 'audit-test' test environment of a system running SELinux
# Maintainer: QE Security <none@suse.de>
# Tags: poo#93441

use base 'selinuxtest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    my $file = "$selinuxtest::dir" . "$selinuxtest::policyfile_tar" . '/data/selinux/selinux-policy-targeted-*.noarch.rpm';
    $self->download_policy_pkgs();
    assert_script_run("rpm -ivh --nosignature --nodeps --noplugins $file");

    # Set SELINUXTYPE=targeted
    # NOTE: 'targeted' type still has some problems (reboot failed)
    # We use 'minimum' atm for a workaround, related poo: poo#94910
    $self->set_sestatus('permissive', 'minimum');
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
