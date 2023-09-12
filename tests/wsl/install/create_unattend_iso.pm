# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: create installation ISO for an unattended Windows install
# Maintainer: QAC team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;

sub run {
    my $win_iso = get_required_var('ISO');
    my $win_version = (split(/\./, $win_iso))[0];
    system "mkdir -v $win_version $win_version-unattend";
    system "sudo mount -v -o loop $win_iso $win_version";
    system "rsync -ar $win_version/ $win_version-unattend";
    system "chmod -R 755 $win_version-unattend";
    system "cd $win_version-unattend";
    if (get_var("UEFI")) {
        system "curl -o Autounattend.xml " . data_url("data/wsl/autounattend_UEFI.xml");
        system "mkisofs -iso-level 4 -udf -R -D -U -b boot/etfsboot.com -no-emul-boot -boot-load-size 8 -boot-load-seg 1984 -eltorito-alt-boot -b efi/microsoft/boot/efisys.bin -no-emul-boot -o $win_iso .";
    } else {
        system "curl -o Autounattend.xml " . data_url("data/wsl/autounattend_BIOS.xml");
        system "mkisofs -iso-level 4 -udf -R -D -U -b boot/etfsboot.com -no-emul-boot -boot-load-size 8 -boot-load-seg 1984 -no-emul-boot -o $win_iso .";
    }
    system "sudo umount -v $win_version";
    system "sudo mv -v $win_iso ..;";
}

1;
