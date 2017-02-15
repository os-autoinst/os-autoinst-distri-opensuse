# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check that services are enables based on system role
# Maintainer: Martin Kravec <mkravec@suse.com>
# Tags: fate#321738

use strict;
use base "opensusebasetest";
use utils;
use testapi;

my %services_for = (
    default => [qw(sshd cloud-init-local cloud-init cloud-config cloud-final issue-generator issue-add-ssh-keys)],
    admin   => undef,
    worker  => ['salt-minion'],
    plain   => undef
);

sub check_services {
    my $services = shift;
    foreach my $s (@$services) {
        assert_script_run "systemctl is-enabled $s";
    }
}

sub run() {
    my $role = get_var('SYSTEM_ROLE');

    check_services $services_for{default};
    check_services $services_for{$role} if $role;
}

sub test_flags() {
    return {important => 1};
}


1;
# vim: set sw=4 et:
