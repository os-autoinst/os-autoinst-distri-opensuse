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
use version_utils qw(is_sle is_sle_micro is_transactional is_tumbleweed);

use base 'Exporter';

our @EXPORT = qw(get_openssl_full_version get_openssl_x_y_version has_default_openssl1 has_default_openssl3 install_openssl OPENSSL1_BINARY);

use constant OPENSSL1_BINARY => "openssl-1_1";

sub get_openssl_full_version {
    my $openssl_binary = shift // "openssl";
    return script_output("rpm -q --qf '%{version}\n' $openssl_binary");
}

sub get_openssl_x_y_version {
    my $openssl_binary = shift // "openssl";
    my $openssl_version_output = script_output("$openssl_binary version | awk '{print \$2}'");
    my ($openssl_version) = $openssl_version_output =~ /(\d\.\d)/;
    return $openssl_version;
}

sub has_default_openssl1 {
    return (is_sle('>=15') && is_sle('<=15-SP5'));
}

sub has_default_openssl3 {
    return (is_sle('>=15-SP6') || is_sle_micro('>=6.0') || is_tumbleweed);
}

sub install_openssl {
    zypper_call 'in openssl' unless is_transactional;
    if (is_sle '>=15-SP6') {
        add_suseconnect_product('sle-module-legacy');
        zypper_call 'in openssl-1_1';
    }
}

1;
