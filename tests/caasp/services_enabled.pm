# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check that services are enables based on system role
# Maintainer: Martin Kravec <mkravec@suse.com>
# Tags: fate#321738

use strict;
use warnings;
use base "opensusebasetest";
use utils;
use testapi;
use version_utils 'is_caasp';

my %services_for = (
    default => [qw(sshd issue-generator issue-add-ssh-keys transactional-update.timer)],
    cloud   => [qw(cloud-init-local cloud-init cloud-config cloud-final)],
    cluster => [qw(chronyd)],
    admin   => [qw(docker kubelet etcd)],
    worker  => [qw(salt-minion systemd-timesyncd)],
    plain   => undef
);

sub check_services {
    my $services = shift;
    foreach my $s (@$services) {
        systemctl "is-enabled $s";
    }
}

sub run {
    my $role = get_var('SYSTEM_ROLE');

    check_services $services_for{default};
    check_services $services_for{cloud}   if is_caasp('caasp');
    check_services $services_for{$role}   if $role;
    check_services $services_for{cluster} if $role =~ /admin|worker/;
}

1;
