# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Update the whole smart card package chain in SLE-15-SP4
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#103751, tc#1769856

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';
use registration 'add_suseconnect_product';

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    add_suseconnect_product('PackageHub', undef, undef, undef, 300, 1) if is_sle;

    # Version check
    my $pkg_list = {
        'pam_pkcs11' => '0.6.10',
        'pcsc-asekey' => '3.7',
        'pcsc-ccid' => '1.4.36',
        'pcsc-cyberjack' => '3.99.5final.SP14',
        'pcsc-gempc' => '1.0.8',
        opensc => '0.22.0',
        'pcsc-lite' => '1.9.4',
        'libp11-3' => '0.4.11',
        'pcsc-tools' => '1.5.8',
        'pkcs11-helper' => '1.25.1'
    };
    zypper_call("in " . join(' ', keys %$pkg_list));
    foreach my $pkg (keys %$pkg_list) {
        my $current_ver = script_output("rpm -q --qf '%{version}\n' $pkg");
        record_info("Current $pkg version is $current_ver, target version is $pkg_list->{$pkg}");
        if ($current_ver lt $pkg_list->{$pkg}) {
            die("The package $pkg is not updated yet, please check with developer");
        }
    }

    # pcscd service check
    systemctl('enable pcscd');
    systemctl('start pcscd');
    systemctl('is-active pcscd');
}

1;
