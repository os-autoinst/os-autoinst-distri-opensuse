# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate system boot after agama reboot
# - Validate that system can bootup to welcome page
#   with right product version and arch.
# - Validate that the system login prompt is ready.
#

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;

sub run {
    my $product_id = get_var('AGAMA_PRODUCT_ID');
    my $arch = get_var('ARCH');
    my $version = get_var('VERSION');

    my %grub_prompts = (
        x86_64 => qr/Press enter to boot the selected OS/,
        aarch64 => qr/Please press 't' to show the boot menu/,
        ppc64le => qr/Trying to load:\s+from: .* \.\.\.\s+Successfully loaded/,
    );

    my %product_name = (
        SLES => 'SUSE Linux Enterprise Server',
        SLES_SAP => 'SUSE Linux Enterprise Server for SAP applications',
    );

    my $grub_found = wait_serial($grub_prompts{$arch}, timeout => 60);
    unless ($grub_found) {
        die "Failed to detect GRUB boot prompt on serial console for $arch within timeout";
    }

    send_key 'ret';

    my $version_regex = $version;
    $version_regex =~ s/\./\\./g;

    my $banner_regex = qr/Welcome to $product_name{$product_id}\s+$version_regex.*\($arch\)/;

    my $banner_match = wait_serial($banner_regex, timeout => 90);
    unless ($banner_match) {
        die "Failed to detect '$product_name{$product_id}' first boot welcome banner on serial console for $arch";
    }

    my $login_regex = qr/(\w+login:|login:)/i;

    my $login_match = wait_serial($login_regex, timeout => 30);
    unless ($login_match) {
        die "System booted banner appeared, but failed to reach getty login prompt on $arch";
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
