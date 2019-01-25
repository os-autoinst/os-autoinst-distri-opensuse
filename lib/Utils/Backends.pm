# Copyright (C) 2018 SUSE LLC
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

package Utils::Backends;
use strict;
use warnings;

use base qw(Exporter);
use Exporter;
use testapi qw(:DEFAULT);

use constant {
    BACKEND => [
        qw(
          is_remote_backend
          has_ttys
          )
    ],
    CONSOLES => [
        qw(
          use_ssh_serial_console
          )
    ]
};

our @EXPORT = (@{(+CONSOLES)}, @{+BACKEND});

our %EXPORT_TAGS = (
    CONSOLES => (CONSOLES),
    BACKEND  => (BACKEND)
);

# Use it after SUT boot finish, as it requires ssh connection to SUT to
# interact with SUT, including window and serial console
sub use_ssh_serial_console {
    select_console('root-ssh');
    $serialdev = 'sshserial';
    set_var('SERIALDEV', $serialdev);
    bmwqemu::save_vars();
}

sub is_remote_backend {

    # s390x uses only remote repos
    return check_var('ARCH', 's390x') ||
      check_var('BACKEND', 'svirt') ||
      check_var('BACKEND', 'ipmi')  ||
      check_var('BACKEND', 'spvm');
}

# In some cases we are using a VNC connection provided by the hypervisor that
# allows access to the ttys same as for accessing any remote libvirt instance
# but not what we use for s390x-kvm.
sub has_ttys {
    return ((get_var('BACKEND', '') !~ /ipmi|s390x|spvm/) && !get_var('S390_ZKVM'));
}

1;
