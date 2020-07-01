# SUSE's openQA tests
#
# Copyright (C) 2020 SUSE LLC
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

# Summary: virtualization test utilities.
# Maintainer: Julie CAO <jcao@suse.com>

package virt_autotest::utils;

use base Exporter;
use Exporter;

use strict;
use warnings;
use utils;
use testapi;

our @EXPORT
  = qw(is_fv_guest is_pv_guest is_xen_host is_kvm_host check_host check_guest print_cmd_output_to_file);

#return 1 if it is a fv guest judging by name
#feel free to extend to support more cases
sub is_fv_guest {
    my $guest = shift;
    return $guest =~ /\bfv\b/ || $guest =~ /\bhvm\b/;
}

#return 1 if it is a pv guest judging by name
#feel free to extend to support more cases
sub is_pv_guest {
    my $guest = shift;
    return $guest =~ /\bpv\b/;
}

#return 1 if test is expected to run on KVM hypervisor
sub is_kvm_host {
    return check_var("SYSTEM_ROLE", "kvm") || check_var("HOST_HYPERVISOR", "kvm");
}

#return 1 if test is expected to run on XEN hypervisor
sub is_xen_host {
    return get_var("XEN") || check_var("SYSTEM_ROLE", "xen") || check_var("HOST_HYPERVISOR", "xen");
}

#check host to make sure it works well
#welcome everybody to extend this function
sub check_host {

}

#check guest to make sure it works well
#welcome everybody to extend this function
sub check_guest {
    my $vm = shift;

    #check if guest is still alive
    validate_script_output "virsh domstate $vm", sub { /running/ };

    #TODO: other checks like checking journals from guest
    #need check the oops bug

}

#ammend the output of the command to an existing log file
#passing guest name or an remote IP as the 3rd parameter if running command in a remote machine
sub print_cmd_output_to_file {
    my ($cmd, $file, $machine) = @_;

    $cmd = "ssh root\@$machine \"" . $cmd . "\"" if $machine;
    script_run "echo -e \"\n# $cmd\" >> $file";
    script_run "$cmd >> $file";

}

1;
