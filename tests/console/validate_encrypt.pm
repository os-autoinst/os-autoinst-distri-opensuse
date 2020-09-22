# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
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
# Summary: Validation module to check encrypted volumes.
# Scenarios covered:
# - Verify existence and content of '/etc/crypttab';
# - Verify number of encrypted devices is correct;
# - Verify the following for each encrypted device:
#    - It is active;
#    - Its properties are correct.
#    - Storing and restoring for binary backups of LUKS header and keyslot areas.
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

package validate_encrypt;
use strict;
use warnings;
use base "opensusebasetest";
use scheduler 'get_test_suite_data';
use validate_encrypt_utils;
use testapi;

sub run {
    select_console 'root-console';
    my $test_data = get_test_suite_data();
    my $devices   = parse_devices_in_crypttab();
    verify_crypttab_file_existence();
    verify_number_of_encrypted_devices($test_data->{crypttab}->{num_devices_encrypted}, scalar keys %{$devices});
    foreach my $dev (sort keys %{$devices}) {
        my $status = parse_cryptsetup_status($dev);
        verify_cryptsetup_message($test_data->{cryptsetup}->{device_status}->{message}, $status->{message});
        verify_cryptsetup_properties($test_data->{cryptsetup}->{device_status}->{properties}, $status->{properties});
    }
    foreach my $dev (sort keys %{$devices}) {
        # This does not solve the problem with the multi-disks for ppc64le-hmc-single-disk
        my $backup_name = check_var("MACHINE", "ppc64le-hmc-single-disk") ? '/root/bkp_luks_header_cr_scsi' : $test_data->{$dev}->{backup_path};
        verify_restoring_luks_backups(
            encrypted_device_path => $devices->{$dev}->{encrypted_device},
            backup_file_info      => $test_data->{backup_file_info},
            backup_path           => $backup_name
        );
    }
}

1;
