# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: download specified guest vm images and xml configuration files from the NFS share location in openQA
#          the guest assets are uploaded by the guest installation tests and named based on the host OS, guest OS, hypervisor and build.
# Maintainer: Julie CAO <jcao@suse.com>
package download_guest_assets;

use strict;
use warnings;
use base "virt_autotest_base";
use testapi;
use virt_utils;

sub run {
    # download vm image and xml file from NFS location to skip installing guest
    my $vm_xml_dir = "/tmp/download_vm_xml";
    handle_sp_in_settings_with_fcs("GUEST_LIST");
    my $guest_list = get_required_var("GUEST_LIST");
    if (download_guest_assets($guest_list, $vm_xml_dir)) {
        die "Fatal Error: The guest assets for $guest_list were not downloaded successfully!";
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
