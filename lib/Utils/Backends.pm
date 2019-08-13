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

=head1 Backends

=head1 SYNOPSIS

use Utils::Backends
It defines various functions that allows to check for different backend or console types. It exports C<CONSOLES> and C<BACKEND>

=cut

package Utils::Backends;
use strict;
use warnings;

use base 'Exporter';
use Exporter;
use testapi ':DEFAULT';

use constant {
    BACKEND => [
        qw(
          is_remote_backend
          has_ttys
          is_hyperv
          is_hyperv_in_gui
          is_svirt_except_s390x
          is_spvm
          is_xen
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

=head2 use_ssh_serial_console

Selects the root-ssh and saves it to SERIALDEV

=cut

sub use_ssh_serial_console {
    select_console('root-ssh');
    $serialdev = 'sshserial';
    set_var('SERIALDEV', $serialdev);
    bmwqemu::save_vars();
}

=head2 is_remote_backend

Returns true if the current instance is running as remote backend

=cut

sub is_remote_backend {
    # s390x uses only remote repos
    return check_var('ARCH', 's390x') || (get_var('BACKEND', '') =~ /ipmi|svirt/) || is_spvm();
}

# In some cases we are using a VNC connection provided by the hypervisor that
# allows access to the ttys same as for accessing any remote libvirt instance
# but not what we use for s390x-kvm.

=head2 has_ttys

Returns true if the current instance is using ttys for: ipmi, s390x, spvm, except S390_ZKVM

=cut

sub has_ttys {
    return ((get_var('BACKEND', '') !~ /ipmi|s390x|spvm/) && !get_var('S390_ZKVM'));
}

=head2 is_hyperv

Returns true if the current instance is running as hyperv backend

=cut

sub is_hyperv {
    my $hyperv_version = shift;
    return 0 unless check_var('VIRSH_VMM_FAMILY', 'hyperv');
    return defined($hyperv_version) ? check_var('HYPERV_VERSION', $hyperv_version) : 1;
}

=head2 is_xen

Returns true if the current instance is running as xen backend

=cut

sub is_xen {
    return check_var('VIRSH_VMM_FAMILY', 'xen');
}

=head2 is_hyperv_in_gui

Returns true if the current instance is running as hyperv gui backend

=cut

sub is_hyperv_in_gui {
    return is_hyperv && !check_var('VIDEOMODE', 'text');
}

=head2 is_svirt_except_s390x

Returns true if the current instance is running as svirt backend except s390x

=cut

sub is_svirt_except_s390x {
    return !get_var('S390_ZKVM') && check_var('BACKEND', 'svirt');
}

=head2 is_spvm

Returns true if the current instance is running as PowerVM backend 'spvm'

=cut

sub is_spvm {
    return check_var('BACKEND', 'spvm');
}

1;
