# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Validate that the partitions are encrypted, as described
# in test_data. Example:
# test_data:
#   encrypted_filesystem:
#     - partition: vdb1
#       luks_type: 2
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use scheduler 'get_test_suite_data';

sub run {
    my $test_data            = get_test_suite_data();
    my $encrypted_partitions = $test_data->{encrypted_filesystem};

    select_console 'root-console';

    foreach (@{$encrypted_partitions}) {
        my $luks_type = $_->{luks_type};
        record_info("Encryption", "Verify that the partition encryptions is luks $luks_type");
        validate_script_output "cryptsetup luksDump /dev/$_->{partition}",
          sub { m/Version:\s+$luks_type.*/s };
    }
}

1;
