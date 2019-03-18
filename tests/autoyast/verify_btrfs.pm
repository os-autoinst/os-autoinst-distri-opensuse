# Copyright (C) 2017 SUSE LLC
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
#
# Summary: Test verifies installation using autoyast_sle_12_btrfs.xml profile
# configuration for btrfs partitions. Verify subvolumes stcructure, mount options
# subvolume attributes configured in profile.
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use base 'basetest';
use strict;
use warnings;
use testapi;

sub run {

    ### Verify mounted drives ###
    # Common part of regexp
    my $common_opts = qr/rw|relatime|space_cache|subvolid=\d+/;

    # Get verify mount options for root
    validate_script_output "findmnt / -no OPTIONS", sub {
        m/^((${common_opts}|subvol=\/\.snapshots\/1\/snapshot),?){5}/i;
    };

    # Verify configured subvolumes
    my @subvolumes = qw(opt tmp usr/local);

    foreach my $subvol (@subvolumes) {
        validate_script_output "findmnt /$subvol -no OPTIONS", sub {
            m/^((${common_opts}|subvol=\/${subvol}),?){5}/i;
        };
    }

    # Get verify mount options for /var/log mount point
    validate_script_output "findmnt /var/log -no OPTIONS", sub {
        m/^((${common_opts}|nodatasum|nodatacow|nobarrier|subvol=\/),?){8}/i;
    };

    ### Verify list of subvolumes ###
    my $subvol_list_cmd = "btrfs subvolume list -a";

    # Verify /var/log, should return no volumes
    validate_script_output "$subvol_list_cmd /var/log", sub { m/^$/; };

    # Verify "/" mount
    assert_script_run("$subvol_list_cmd / | grep \"path <FS_TREE>/\"");

    # Verify all subvolumes
    foreach my $subvol (@subvolumes) {
        assert_script_run("$subvol_list_cmd / | grep \"path <FS_TREE>/$subvol\"");
    }

    # Verify snapshots subvolume
    assert_script_run("$subvol_list_cmd / | grep \"path <FS_TREE>/.snapshots\"");

    ### Verify copy on write flags for subvolumes.
    # Use -d option to list directories as files and l option to print long
    # attribite name. Only tmp has flag set,usr.local has no setting, by default flag is set
    validate_script_output "lsattr -dl /tmp",       sub { m/\/tmp.*No_COW/i; };
    validate_script_output "lsattr -dl /usr/local", sub { m/\/usr\/local.*---/i; };
    validate_script_output "lsattr -dl /opt",       sub { m/\/opt.*---/i; };

}

1;

