# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Setup 'audit-test' test environment of a system running SELinux
# Maintainer: llzhao <llzhao@suse.com>
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

1;
