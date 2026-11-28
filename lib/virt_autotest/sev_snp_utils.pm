# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Shared AMD SEV-SNP definitions used by multiple test modules
# Maintainer: QE-Virtualization <qe-virt@suse.de>

package virt_autotest::sev_snp_utils;

use strict;
use warnings;
use base 'Exporter';
use registration 'add_suseconnect_product';
use version_utils 'is_sle';

use constant {
    # ucode-amd provides CPU microcode required by snphost ok verification
    SNP_HOST_TOOLS => ['snphost', 'sevctl', 'ucode-amd'],
    SNP_GUEST_TOOLS => ['snpguest'],
};

our @EXPORT_OK = qw(SNP_HOST_TOOLS SNP_GUEST_TOOLS activate_coco_module_if_needed);

my $coco_module_activated = 0;

sub activate_coco_module_if_needed {
    return unless is_sle('=15-sp7');
    return if $coco_module_activated;

    add_suseconnect_product('sle-module-confidential-computing');
    $coco_module_activated = 1;
}

1;
