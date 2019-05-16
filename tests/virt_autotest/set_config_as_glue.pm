# SUSE's openQA tests
#
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

# Summary: set configuration as glue
# Maintainer: Leon Guo <xguo@suse.com>

package set_config_as_glue;

use base "consoletest";
use xen;
use strict;
use warnings;
use testapi;

sub fufill_guests_in_setting {
    my $wait_script        = "30";
    my $get_vm_hostnames   = "virsh list  --all | grep sles | awk \'{print \$2}\'";
    my $vm_hostnames       = script_output($get_vm_hostnames, $wait_script, type_command => 0, proceed_on_failure => 0);
    my @vm_hostnames_array = split(/\n+/, $vm_hostnames);
    foreach (@vm_hostnames_array) { $xen::guests{$_} = '1'; }
}

sub run {
    fufill_guests_in_setting;
}

1;
