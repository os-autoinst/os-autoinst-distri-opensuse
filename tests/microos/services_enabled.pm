# SUSE's openQA tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check that services are enables based on system role
# Maintainer: Martin Kravec <mkravec@suse.com>
# Tags: fate#321738

use strict;
use warnings;
use base "consoletest";
use utils;
use testapi;

my %services_for = (
    default => [qw(sshd issue-generator issue-add-ssh-keys transactional-update.timer)],
    cloud => [qw(cloud-init-local cloud-init cloud-config cloud-final)],
    cluster => [qw(chronyd)],
    admin => [qw(docker kubelet etcd)],
    worker => [qw(salt-minion systemd-timesyncd)],
    plain => undef
);

sub check_services {
    my $services = shift;
    while (my ($s, $on) = each %$services) {
        systemctl "is-enabled $s", expect_false => ($on ? 0 : 1);
    }
}

sub map_services {
    map { my $on = (s/^!//) ? 0 : 1; $_ => $on } @_;
}

sub run {
    my %services;

    # the SERVICES_ENABLED var allows to overwrite the test's built
    # in defaults. It's a space separated list of services to check
    # for. If the first service in the list starts with a plus or
    # minus, the listed services have to start with either a plus or
    # minus to indicates whether they are to be added or removed
    # from the built in list. Without plus or minus the built in
    # list gets ignored.
    # an exclamation mark in front of a service verifies the service is
    # disabled.
    # Example: SERVICES_ENABLED="+!sshd"
    my $extra = get_var('SERVICES_ENABLED');
    if ($extra && $extra !~ /^[+-]/) {
        %services = map_services split(/\s+/, $extra);
    } else {
        my $role = get_var('SYSTEM_ROLE');

        %services = map_services @{$services_for{default}};
        if ($role) {
            %services = (%services, map_services @{$services_for{$role}}) if $services_for{$role};
            %services = (%services, map_services @{$services_for{cluster}}) if $role =~ /admin|worker/;
        }

        if ($extra) {
            for my $s (split(/\s+/, $extra)) {
                if ($s =~ s/^-//) {
                    delete $services{$s};
                } else {
                    # even if there is no plus in following items we still add it
                    $s =~ s/^\+//;
                    my $on = ($s =~ s/^!//) ? 0 : 1;
                    $services{$s} = $on;
                }
            }
        }
    }

    check_services \%services if %services;
}

1;
