# Copyright (C) 2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

package Utils::Systemd;

use base 'Exporter';
use Exporter;
use Carp 'croak';
use strict;
use warnings;
use testapi qw(script_run assert_script_run);
use version_utils 'is_sle';

our @EXPORT = qw(
  disable_and_stop_service
  systemctl
);

=head1 Utils::Systemd

C<Utils::Systemd> - Library for systemd related functionality

=cut

=head2 disable_and_stop_service

    disable_and_stop_service($service_name[, mask_service => $mask_service][, %args]);

Disable and stop the service C<$service_name>.
Mask it if I<$mask_service> evaluates to true. Default: false
Pass additional arguments to the internal C<systemctl> call.

=cut
sub disable_and_stop_service {
    my ($service_name, %args) = @_;
    die "disable_and_stop_service(): no service name given" if ($service_name =~ /^ *$/);
    $args{mask_service} //= 0;

    my $cmd = $args{mask_service} ? 'mask' : 'disable';
    if (is_sle('<12-sp3')) {
        map { systemctl("$_ $service_name", %args) } ($cmd, 'stop');
    } else {
        systemctl("$cmd --now $service_name", %args);
    }
}

=head2 systemctl

Wrapper around systemctl call to be able to add some useful options.

Please note that return code of this function is handle by 'script_run' or
'assert_script_run' function, and as such, can be different.
Ignore any failure if I<$ignore_failure> evaluates to true. Default: false
=cut
sub systemctl {
    my ($command, %args) = @_;
    croak "systemctl(): no command specified" if ($command =~ /^ *$/);
    my $expect_false  = $args{expect_false} ? '!' : '';
    my @script_params = ("$expect_false systemctl --no-pager $command", timeout => $args{timeout}, fail_message => $args{fail_message});
    if ($args{ignore_failure}) {
        script_run($script_params[0], $args{timeout});
    } else {
        assert_script_run(@script_params);
    }
}

1;
