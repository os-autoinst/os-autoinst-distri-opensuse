# Certification
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE Security <none@suse.de>
#
# This code is similar to vendoraffirmation.pm (VA). Both are installing
# packages from the certification updates repository.
# The VA code installs exact versions in FIPS kernel mode only.
# This code is executed in FIPS env mode and only meant for SLE 15-SP7,
# as of now. It sets the certification updates repository to priority 1
# and calls zypper dup, which usually means downgrading certain packages
# that have been used in the certification process.
#

package security::certification;

use strict;
use warnings;
use testapi;
use base 'Exporter';
use registration qw(add_suseconnect_product);
use version_utils qw(is_sle);
use utils qw(zypper_call);

our @EXPORT = qw(install_certification_pkgs check_installed_certification_pkgs);

sub install_certification_pkgs {
    add_suseconnect_product('sle-module-certifications') if is_sle('=15-SP7');
    my $repo_id = script_output("zypper lr -E | grep 'Cert' | grep 'Updates' | cut -d'|' -f 1");
    zypper_call("mr -p 1 " . $repo_id);
    zypper_call("dup");
}

sub check_installed_certification_pkgs {
    my $prefix = "SLE-Module-Certifications";
    my $repo = $prefix . '-15-SP7-Updates';
    my $num_installed = script_output("zypper se -is --type package --repo $repo | grep $prefix | wc -l");
    die "Seems there are no packages installed from the $repo repository" if $num_installed == 0;
    return 1;
}

1;
