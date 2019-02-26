# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify data integrity of the images provided by comparing checksums.
# Maintainer: Joaquín Rivera <jeriveramoya@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use data_integrity_utils 'verify_checksum';

sub run {
    my $dir_path;
    $dir_path = '/var/lib/libvirt/images/' if check_var('BACKEND', 'svirt');
    $dir_path = get_var('HYPERV_DISK', 'D:') . '\\cache\\' if check_var('VIRSH_VMM_FAMILY', 'hyperv');
    verify_checksum($dir_path);
}

1;
