# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Leverage the test module 'ipxe_install' to wipe multiple disks and
#          also the EFI boot partition before starting installation
# Maintainer: Nan Zhang <nan.zhang@suse.com>, qe-virt@suse.de

package wipe_disks;

use testapi;
use base "installbasetest";
use utils;
use File::Basename;

BEGIN {
    unshift @INC, dirname(__FILE__) . '/../installation';
}
use ipxe_install;

sub run {
    my $self = shift;

    my $boot_hdd_image_tmp = get_var('BOOT_HDD_IMAGE');
    my $install_hdd_image_tmp = get_var('INSTALL_HDD_IMAGE');
    my $mirror_http_tmp = get_var('MIRROR_HTTP');

    set_var('BOOT_HDD_IMAGE', '');
    set_var('INSTALL_HDD_IMAGE', '');
    set_var('MIRROR_HTTP', 'http://openqa.suse.de/assets/repo/fixed/SLE-15-SP7-Full-x86_64-GM-Media1');
    set_var('HOST_INSTALL_AUTOYAST', '1');

    record_info('Wipe all disks before installation');
    $self->ipxe_install::run() if (check_var('IPXE', '1'));
    reset_consoles;

    set_var('BOOT_HDD_IMAGE', $boot_hdd_image_tmp);
    set_var('INSTALL_HDD_IMAGE', $install_hdd_image_tmp);
    set_var('MIRROR_HTTP', $mirror_http_tmp);
    set_var('HOST_INSTALL_AUTOYAST', '');
}

1;
