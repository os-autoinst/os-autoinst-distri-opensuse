# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Utils::Systemd;

use base 'Exporter';
use Exporter;
use Carp 'croak';
use strict;
use warnings;
use testapi qw(script_run assert_script_run);

our @EXPORT = qw(
  disable_and_stop_service
  get_started_systemd_services
  clear_started_systemd_services
  systemctl
  check_unit_file
);

=head1 Utils::Systemd

C<Utils::Systemd> - Library for systemd related functionality

=cut

my %started_systemd_services;

=head2 disable_and_stop_service

    disable_and_stop_service($service_name[, mask_service => $mask_service][, ignore_failure => $ignore_failure]);

Disable and stop the service C<$service_name>.
Mask it if I<$mask_service> evaluates to true. Default: false
Raise a failure if I<$ignore_failure> evaluates to true. Default: false

=cut

sub disable_and_stop_service {
    my ($service_name, %args) = @_;
    die "disable_and_stop_service(): no service name given" if ($service_name =~ /^ *$/);
    $args{mask_service} //= 0;
    $args{ignore_failure} //= 0;

    systemctl("mask $service_name", ignore_failure => $args{ignore_failure}) if ($args{mask_service});
    systemctl("disable $service_name", ignore_failure => $args{ignore_failure}) unless ($args{mask_service});
    systemctl("stop $service_name", ignore_failure => $args{ignore_failure});
}

=head2 systemctl

Wrapper around systemctl call to be able to add some useful options.

Please note that return code of this function can be handled by either
'script_run' or 'assert_script_run' function, and as such, can be different.
=cut

sub systemctl {
    my ($command, %args) = @_;
    croak "systemctl(): no command specified" if ($command =~ /^ *$/);
    my $expect_false = $args{expect_false} ? '! ' : '';
    my @script_params = ("${expect_false}systemctl --no-pager $command", timeout => $args{timeout}, fail_message => $args{fail_message});
    if ($command =~ /^(re)?start ([^ ]+)/) {
        my $unit_name = $2;
        $started_systemd_services{$unit_name} = 1;
    }
    if ($args{ignore_failure}) {
        script_run($script_params[0], $args{timeout});
    } else {
        assert_script_run(@script_params);
    }
}

=head2 get_started_systemd_services

Return list of started systemd services

=cut

sub get_started_systemd_services {
    return keys(%started_systemd_services);
}

=head2 clear_started_systemd_services

Clear the list of started systemd services

=cut

sub clear_started_systemd_services {
    %started_systemd_services = ();
}

=head2 check_unit_file

Check if the unit file exist

=cut

sub check_unit_file {
    my $unit_file = shift;
    return 1 if (script_run("systemctl list-unit-files --all $unit_file*") == 0);
    return 0;
}

1;
