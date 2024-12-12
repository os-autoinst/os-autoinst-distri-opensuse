# openssl fips test
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: openssl-fips common function for Hash test cases
#
# Maintainer: QE Security <none@suse.de>

package security::openssl_misc_utils;

use strict;
use warnings;
use testapi;
use registration 'add_suseconnect_product';
use utils 'zypper_call';
use version_utils qw(is_sle is_sle_micro is_microos is_transactional is_tumbleweed is_rt is_jeos is_sled);

use base 'Exporter';

our @EXPORT = qw(get_openssl_full_version get_openssl_x_y_version has_default_openssl1 has_default_openssl3 install_openssl OPENSSL1_BINARY);

use constant OPENSSL1_BINARY => "openssl-1_1";

sub get_openssl_full_version {
    my $openssl_binary = shift // "openssl";
    # for SLERT we don't install a package, we query the rpm file just downloaded in install_openssl
    return script_output("rpm -qp --qf '%{version}\n' openssl*.rpm") if (has_no_legacy_module() && $openssl_binary eq OPENSSL1_BINARY);
    return script_output("rpm -q --qf '%{version}\n' $openssl_binary");
}

sub get_openssl_x_y_version {
    my $openssl_binary = shift // "openssl";
    my $openssl_version_output = script_output("$openssl_binary version | awk '{print \$2}'");
    my ($openssl_version) = $openssl_version_output =~ /(\d\.\d)/;
    return $openssl_version;
}

sub has_no_legacy_module {
    return is_rt || is_jeos || is_sled;
}

sub has_default_openssl1 {
    return (is_sle('>=15') && is_sle('<=15-SP5'));
}

sub has_default_openssl3 {
    return (is_sle('>=15-SP6') || is_sle_micro('>=6.0') || is_tumbleweed || is_microos('Tumbleweed') || is_rt);
}

sub install_openssl {
    zypper_call 'in openssl' unless is_transactional;
    if (is_sle '>=15-SP6') {
        if (has_no_legacy_module()) {
            install_11_workaround_when_no_legacy();
        } else {
            record_info('Extensions List', script_output("SUSEConnect --list-extensions"));
            add_suseconnect_product('sle-module-legacy');
            zypper_call 'in openssl-1_1';
        }
    }
}

# if we don't have legacy module (i.e. for SLERT) download the rpm , extract and place in $PATH
sub install_11_workaround_when_no_legacy {
    my $product_version = get_required_var 'VERSION';
    my $arch = get_required_var 'ARCH';
    my $legacy_repourl = "https://download.suse.de/ibs/SUSE/Products/SLE-Module-Legacy/$product_version/$arch/product";
    # lookup the repo index to find out the exact package name
    # output will be somewhat like ./x86_64/openssl-1_1-1.1.1w-150600.3.10.x86_64.rpm
    my $rpm_name = (split '/', script_output "curl -Lsk $legacy_repourl/INDEX.gz | gzip -cd | grep 'openssl-1_1.*\.rpm'")[-1];
    assert_script_run "curl -skLO $legacy_repourl/$arch/$rpm_name";
    # extract the RPM package content
    assert_script_run "rpm2cpio $rpm_name | cpio -idmv";
    # copy the openssl binary in $PATH
    assert_script_run "cp ./usr/bin/openssl-1_1 /usr/local/bin";
}

1;
