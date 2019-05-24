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

use strict;
use warnings;

use utils 'systemctl';

our @EXPORT = qw(
  disable_and_stop_service
);

=head1 Utils::Systemd

C<Utils::Systemd> - Library for systemd related functionality

=cut

=head2 disable_and_stop_service

    disable_and_stop_service($service_name[, mask_service => $mask_service][, ignore_failure => $ignore_failure]);

Disable and stop the service C<$service_name>.
Mask it if I<$mask_service> evaluates to true. Default: false
Raise a failure if I<$ignore_failure> evaluates to true. Default: false

=cut
sub disable_and_stop_service {
    my ($service_name, %args) = @_;
    die "disable_and_stop_service(): no service name given" if ($service_name =~ /^ *$/);
    $args{mask_service}   //= 0;
    $args{ignore_failure} //= 0;

    systemctl("mask $service_name", ignore_failure => $args{ignore_failure}) if ($args{mask_service});
    systemctl("disable $service_name", ignore_failure => $args{ignore_failure}) unless ($args{mask_service});
    systemctl("stop $service_name", ignore_failure => $args{ignore_failure});
}


1;
