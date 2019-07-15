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

package Utils::Architectures;
use strict;
use warnings;

use base 'Exporter';
use Exporter;
use testapi 'check_var';

use constant {
    ARCH => [
        qw(
          is_s390x
          is_i586
          is_i686
          is_x86_64
          is_aarch64
          is_ppc64le
          )
    ]
};

our @EXPORT = @{(+ARCH)};

our %EXPORT_TAGS = (
    ARCH => (ARCH),
);

# specific architectures

sub is_s390x {
    return check_var('ARCH', 's390x');
}
sub is_i586 {
    return check_var('ARCH', 'i586');
}
sub is_i686 {
    return check_var('ARCH', 'i686');
}
sub is_x86_64 {
    return check_var('ARCH', 'x86_64');
}
sub is_aarch64 {
    return check_var('ARCH', 'aarch64');
}
sub is_ppc64le {
    return check_var('ARCH', 'ppc64le');
}

1;
