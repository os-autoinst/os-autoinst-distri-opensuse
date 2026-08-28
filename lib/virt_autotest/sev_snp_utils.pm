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

use constant {
    # ucode-amd provides CPU microcode required by snphost ok verification
    SNP_HOST_TOOLS => ['snphost', 'sevctl', 'ucode-amd'],
    SNP_GUEST_TOOLS => ['snpguest'],
};

our @EXPORT_OK = qw(SNP_HOST_TOOLS SNP_GUEST_TOOLS);

1;
