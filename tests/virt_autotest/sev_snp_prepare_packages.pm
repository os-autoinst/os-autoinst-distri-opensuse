# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Install AMD SEV-SNP tooling packages (snphost/sevctl/ucode-amd on
# the host, snpguest on each guest) before the generic
# virtualization/universal/kernel test module runs. This lets that generic
# module validate UPDATE_PACKAGE=snphost/snpguest with its own plain
# 'package is installed and up-to-date' check, without kernel.pm needing to
# know anything about SNP-specific package names.
#
# Full SEV-SNP verification (kernel parameters, guest attestation, etc.) is
# still owned entirely by sev_snp_validation.pm, which runs later. This
# module only makes sure the packages already exist by the time the generic
# kernel test looks for them.
#
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use virt_autotest::common;
use package_utils 'install_package';
use sev_snp_validation;

sub run {
    my $self = shift;
    select_console('root-console');

    record_info('Installing SNP host packages', 'Installing SEV-SNP host packages: ' . join(', ', @{sev_snp_validation::SNP_HOST_TOOLS()}));
    install_package(join(' ', @{sev_snp_validation::SNP_HOST_TOOLS()}));

    my $guest_packages = join(' ', @{sev_snp_validation::SNP_GUEST_TOOLS()});
    foreach my $guest (keys %virt_autotest::common::guests) {
        record_info("Installing SNP guest packages on $guest", "Installing: $guest_packages");
        assert_script_run("ssh root\@$guest zypper --non-interactive in $guest_packages", timeout => 180);
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
