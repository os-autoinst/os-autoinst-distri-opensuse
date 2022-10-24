# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: check contents of /etc/os-release per the current settings
# - get information from the running system (name, pretty name, id, cpe name)
# - get data from /etc/os-release
# - compare current values with those from /etc/os-release
# Maintainer: Alvaro Carvajal <acarvajal@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils qw(is_sle is_leap is_tumbleweed is_sles4sap is_rt is_hpc);
use main_common 'is_desktop';

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my %checker = ();
    $checker{VERSION} = get_var("TARGET_VERSION", get_required_var("VERSION"));
    $checker{VERSION_ID} = $checker{VERSION};

    if (is_sle) {
        my $product = get_required_var('SLE_PRODUCT');
        $product = 'sles_sap' if (is_sles4sap and is_sle('<15'));
        $product = 'sles' if (is_sles4sap and is_sle('>=15'));
        $product = 'sle_' . $product if is_rt or is_hpc;
        $checker{NAME} = uc($product);
        $checker{NAME} = 'SLES' if ($product =~ /^sles/);
        $checker{VERSION_ID} =~ s/\-SP/./;
        $checker{PRETTY_NAME} = "SUSE Linux Enterprise Server $checker{VERSION}";
        $checker{PRETTY_NAME} =~ s/\-SP/ SP/;
        $checker{PRETTY_NAME} =~ s/Server/Server for SAP Applications/ if (is_sles4sap and is_sle('<=12-SP2'));
        $checker{PRETTY_NAME} =~ s/Server/Desktop/ if is_desktop;
        $checker{PRETTY_NAME} =~ s/Server/Real Time/ if is_rt;
        $checker{PRETTY_NAME} =~ s/Server/High Performance Computing/ if is_hpc;
        $checker{ID} = lc($checker{NAME});
        $checker{CPE_NAME} = "cpe:/o:suse:$product:$checker{VERSION}";
        $checker{CPE_NAME} =~ s/\-SP/:sp/;
    }
    if (is_leap) {
        if ($checker{VERSION} =~ /^Jump/) {
            $checker{VERSION} =~ s/^Jump://;
            $checker{VERSION_ID} = $checker{VERSION};
        }
        $checker{NAME} = "openSUSE Leap";
        $checker{ID} = "opensuse";
        $checker{PRETTY_NAME} = $checker{NAME} . " " . $checker{VERSION};
        $checker{CPE_NAME} = "cpe:/o:opensuse:leap:$checker{VERSION}";
    }
    if (is_tumbleweed) {
        $checker{VERSION} = get_required_var('BUILD');
        $checker{VERSION_ID} = $checker{VERSION};
        $checker{NAME} = "openSUSE Tumbleweed";
        $checker{ID} = "opensuse-tumbleweed";
        $checker{CPE_NAME} = "cpe:/o:opensuse:tumbleweed:$checker{VERSION}";
        $checker{PRETTY_NAME} = $checker{NAME};
    }

    my $release = script_output "cat /etc/os-release";

    foreach my $key (keys %checker) {
        record_info $key, "Checking $key in /etc/os-release";
        my $regexp = "$key=\"?$checker{$key}\"?";
        if ($release !~ m|$regexp|) {
            record_info "Wrong $key value", "Wrong $key value in /etc/os-release. Expected $checker{$key}", result => 'fail';
            if (is_sle('=15-SP1') and is_sles4sap) {
                record_soft_failure "bsc#1135637";
            }
            else {
                $self->result('fail');
            }
        }
    }
}

1;
