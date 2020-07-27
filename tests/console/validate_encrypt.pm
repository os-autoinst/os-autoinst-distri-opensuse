# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

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
        verify_restoring_luks_backups(encrypted_device => $devices->{$dev}->{encrypted_device},
            backup_file_info => $test_data->{backup_file_info}
        );
    }
}

1;
