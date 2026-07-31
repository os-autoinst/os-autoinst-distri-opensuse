# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Prepares environment to reinstall the SUT, forcing agama to reuse partitions
# Maintainer: santiago.zarate <santiago.zarate@suse.com>

use Mojo::Base 'basetest';
use testapi;

sub run {
    if (!get_var('BOOTFROM')) {

        set_var('BOOTFROM', 'd');

        my $boot_options = script_output("efibootmgr");
        record_info('efibootmgr', $boot_options);

        my $get_boot_order = q{efibootmgr | grep -oP "(?<=^Boot)(\d+)(?=.*UEFI.*QEMU CD-ROM)"};
        assert_script_run "efibootmgr -n \$($get_boot_order)";

        my $product = get_var('AGAMA_PRODUCT_ID');
        set_var('AGAMA_PROFILE_OPTIONS', 'product="' . $product . '" bootloader=false storage=raid0_uefi_search');
        set_var('INST_AUTO', 'yam/agama/auto/template.libsonnet');

    } else {
        set_var('BOOTFROM', undef);
    }

    record_info('BOOTFROM', get_var('BOOTFROM'));
    record_info('AGAMA_PROFILE_OPTIONS', get_var('AGAMA_PROFILE_OPTIONS'));
    record_info('INST_AUTO', get_var('INST_AUTO'));

}

sub flags {
    return {fatal => 1};
}

1;
