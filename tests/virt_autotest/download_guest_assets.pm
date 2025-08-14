# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: download specified guest vm images and xml configuration files from the NFS share location in openQA
#          the guest assets are uploaded by the guest installation tests and named based on the host OS, guest OS, hypervisor and build.
# Maintainer: Julie CAO <jcao@suse.com>
package download_guest_assets;

use base "virt_autotest_base";
use testapi;
use virt_utils;

sub run {
    # download vm image and xml file from NFS location to skip installing guest
    my $vm_xml_dir = "/tmp/download_vm_xml";
    my $guest_list = get_guest_list();
    if (download_guest_assets($guest_list, $vm_xml_dir) eq '0') {
        die "Fatal Error: The guest assets for $guest_list were not downloaded successfully!";
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
