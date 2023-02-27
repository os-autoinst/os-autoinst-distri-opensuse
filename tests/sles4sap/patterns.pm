# SUSE's openQA tests
#
# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: SAP Pattern test
# Working both on plain SLE and SLES4SAP products
# Maintainer: QE-SAP <qe-sap@suse.de>, Alvaro Carvajal <acarvajal@suse.de>

use base "sles4sap";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle is_upgrade);
use main_common 'is_updates_tests';
use strict;
use warnings;

sub run {
    my @sappatterns = qw(sap-nw sap-b1 sap-hana);
    $sappatterns[1] =~ s/b1/bone/ if (is_sle('15-SP5+'));
    my $output = '';

    select_serial_terminal;

    # Disable packagekit
    quit_packagekit;

    # Is HA pattern needed?
    push @sappatterns, 'ha_sles' if get_var('HA_CLUSTER');

    my $base_pattern = is_sle('15+') ? 'patterns-server-enterprise-sap_server' : 'patterns-sles-sap_server';

    zypper_enable_install_dvd;
    # First check pattern sap_server which is installed by default in SLES4SAP
    # when 'SLES for SAP Applications' system role is selected
    $output = script_output("zypper info -t pattern sap_server");
    if ($output !~ /i.?\s+\|\s$base_pattern\s+\|\spackage\s\|\sRequired/) {
        # Pattern sap_server is not installed. Could be a due to a bug, caused by the
        # use of the 'textmode' system role during install, or on upgrades when the
        # original system didn't have the pattern (for example, from SLES4SAP 11-SP4)
        die "Pattern sap_server not installed by default"
          unless (check_var('SYSTEM_ROLE', 'textmode') or is_upgrade() or is_updates_tests() or check_var('SLE_PRODUCT', 'sles'));
        record_info('install sap_server', 'Installing sap_server pattern');
        zypper_call('in -y -t pattern sap_server');
    }

    # This test is also used for testing SAP products installation on plain SLE
    # All SAP patterns are not available in SLE
    if (check_var('SLE_PRODUCT', 'sles4sap')) {
        # Dry run of each pattern's installation before actual installation
        foreach my $pattern (@sappatterns) {
            zypper_call("in -D -y -t pattern $pattern");
            $output = script_output("zypper info --requires $pattern");
            record_info("requirements pattern: $pattern", $output);
        }

        # Actual installation and verification
        foreach my $pattern (@sappatterns) {
            zypper_call("in -y -t pattern $pattern", timeout => 1500);
            $output = script_output "zypper info -t pattern $pattern";
            # Name of HA pattern is weird...
            $pattern = "ha-$pattern" if ($pattern =~ /ha_sles/) && get_var('HA_CLUSTER');
            die "SAP zypper pattern [$pattern] info check failed"
              unless ($output =~ /i.?\s+\|\spatterns-$pattern\s+\|\spackage\s\|\sRequired/);
        }
    }
    elsif (check_var('SLE_PRODUCT', 'sles') && get_var('HANA')) {
        # We need this package for installing HANA on SLE
        zypper_call 'in libatomic1';
    }

    # Some specific package may be needed in HA mode
    zypper_call 'in sap-suse-cluster-connector' if get_var('HA_CLUSTER');

    # Workaround for textmode based test, as there is no SAP profiles with textmode yet
    zypper_call 'in libgomp1' if check_var('SYSTEM_ROLE', 'textmode');
}

sub test_flags {
    return {milestone => 1};
}

1;
