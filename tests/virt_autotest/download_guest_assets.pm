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
    # For Unified frame installed guests, use UNIFIED_GUEST_LIST(eg. sles_15_sp7_64_kvm_hvm_uefi) directly
    # Parse the guest list for legacy ways(qa_lib_virtauto) to install guests
    # Curiously, if "$guest_list = get_var('UNIFIED_GUEST_LIST', get_guest_list())" is used, get_guest_list() is always run whatever UNIFIED_GUEST_LIST is.
    my $guest_list = get_var('UNIFIED_GUEST_LIST') ? get_var('UNIFIED_GUEST_LIST') : get_guest_list();

    if (download_guest_assets($guest_list, $vm_xml_dir) eq '0') {
        die "Fatal Error: The guest assets for $guest_list were not downloaded successfully!";
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
