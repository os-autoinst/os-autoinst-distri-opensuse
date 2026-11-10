# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Prepares environment to reinstall the SUT, forcing agama to reuse partitions
# Maintainer: santiago.zarate <santiago.zarate@suse.com>

use Mojo::Base 'basetest';
use testapi;

sub get_uefi_cd_rom_boot_entry {
    my $get_boot_order = q{efibootmgr | grep -oP "(?<=^Boot)(\d+)(?=.*UEFI.*QEMU CD-ROM)"};
    record_info('Boot Order', script_output($get_boot_order));
    return script_output($get_boot_order);
}

sub get_boot_options {
    my $boot_options = script_output("efibootmgr");
    record_info('efibootmgr', $boot_options);
    return $boot_options;
}

sub run {
    if (!get_var('BOOTFROM')) {

        set_var('BOOTFROM', 'd');

        my $boot_options = get_boot_options();

        my $cdrom_boot_entry = get_uefi_cd_rom_boot_entry();
        assert_script_run "efibootmgr -n \$($cdrom_boot_entry)";

        my $product = get_var('AGAMA_PRODUCT_ID');
        set_var('AGAMA_PROFILE_OPTIONS', 'product="' . $product . '" bootloader=false storage=raid0_uefi_search');
        set_var('INST_AUTO', 'yam/agama/auto/template.libsonnet');

    } else {
        set_var('BOOTFROM', undef);
        eject_cd;
        power('reset');

    }

    record_info('BOOTFROM', get_var('BOOTFROM'));
    record_info('AGAMA_PROFILE_OPTIONS', get_var('AGAMA_PROFILE_OPTIONS'));
    record_info('INST_AUTO', get_var('INST_AUTO'));

}

sub flags {
    return {fatal => 1};
}

1;
