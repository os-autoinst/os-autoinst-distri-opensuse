# XEN regression tests
#
# Copyright 2019-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libvirt-client
# Summary: Storage pool / volume test
# Maintainer: Pavel Dostal <pdostal@suse.cz>, Felix Niederwanger <felix.niederwanger@suse.de>, Jan Baier <jbaier@suse.cz>

use base "virt_feature_test_base";
use virt_autotest::virtual_storage_utils;
#use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;
use virt_utils;
use version_utils;

our $dir_pool_name = 'testing';
sub run_test {
    my ($self) = @_;
    my @guests = @{get_var_array("TEST_GUESTS")};
    record_info "Prepare";
    ## Prepare Virtualization Dir Storage Pool source
    prepare_dir_storage_pool_source($dir_pool_name);

    record_info "Pool define";
    assert_script_run "virsh pool-define-as $dir_pool_name dir - - - - '/pool_testing'";

    ## Basic Dir Storage Management
    my $dir_vol_size = '100M';
    my $dir_vol_resize = '200M';
    virt_storage_management($dir_pool_name, \@guests, size => $dir_vol_size, dir => 1, resize => $dir_vol_resize);

    ## Cleanup
    # Destroy the Dir storage pool
    destroy_virt_storage_pool($dir_pool_name);
}

# Prepare Virtualization Dir Storage Pool source
sub prepare_dir_storage_pool_source {
    my $dir_pool_name = shift;
    my @guests = @{get_var_array("TEST_GUESTS")};
    assert_script_run "mkdir -p /pool_testing";
    script_run "virsh pool-destroy $dir_pool_name";
    script_run "virsh vol-delete --pool $dir_pool_name $_-storage" foreach (@guests);
    script_run "virsh vol-delete --pool $dir_pool_name $_-clone" foreach (@guests);
    script_run "virsh pool-undefine $dir_pool_name";
    # Ensure the new pool directory is empty
    script_run('rm -f /pool_testing/*');
}

1;
