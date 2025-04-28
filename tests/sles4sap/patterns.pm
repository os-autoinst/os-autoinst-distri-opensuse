# SUSE's openQA tests
#
# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: SAP Pattern test
# Working both on plain SLE and SLES4SAP products
# Maintainer: QE-SAP <qe-sap@suse.de>, Alvaro Carvajal <acarvajal@suse.de>

use base 'sles4sap';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle is_upgrade);
use main_common 'is_updates_tests';
use registration qw(add_suseconnect_product);
use strict;
use warnings;

sub run {
    my @sappatterns = is_sle('16+') ? ("sles_sap_APP", "sles_sap_DB", "sles_sap_addons", "sles_sap_automation", "sles_sap_debug", "sles_sap_security", "sles_sap_trento_agent", "sles_sap_trento_server") : ("sap-nw", "sap-b1", "sap-hana");
    splice(@sappatterns, 1, 1) if (is_sle('15-SP5+') && !is_sle('16+'));    # sap-bone pattern is no longer part of SLES4SAP starting on 15-SP5
    my $output = '';

    select_serial_terminal;

    # Disable packagekit
    quit_packagekit;

    # Is HA pattern needed?
    if (get_var('HA_CLUSTER')) {
        push(@sappatterns, 'ha_sles');
        push(@sappatterns, 'sles_sap_HAAPP', 'sles_sap_HADB') if is_sle('16+');
    }

    my $base_pattern = is_sle('15+') ? 'patterns-server-enterprise-sap_server' : 'patterns-sles-sap_server';
    $base_pattern = 'patterns-sap-base_sap_server' if (is_sle('16+'));

    zypper_enable_install_dvd;
    # First check pattern sap_server which is installed by default in SLES4SAP
    # when 'SLES for SAP Applications' system role is selected
    my $sap_server = is_sle('16+') ? "sles_sap_base_sap_server" : "sap_server";
    $output = script_output("zypper info -t pattern $sap_server");
    if ($output !~ /i.?\s+\|\s$base_pattern\s+\|\spackage\s\|\sRequired/) {
        # Pattern sap_server is not installed. Could be a due to a bug, caused by the
        # use of the 'textmode' system role during install, or on upgrades when the
        # original system didn't have the pattern (for example, from SLES4SAP 11-SP4)
        die "Pattern sap_server not installed by default"
          unless (check_var('SYSTEM_ROLE', 'textmode') or is_upgrade() or is_updates_tests() or check_var('SLE_PRODUCT', 'sles'));
        record_info('install sap_server', 'Installing sap_server pattern');
        zypper_call("in -y -t pattern $sap_server");
    }

    record_info("pattern list", script_output("zypper se -t pattern"));

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
            $pattern =~ s/^sles_sap_/sap-/ if (is_sle('16+'));
            die "SAP zypper pattern [$pattern] info check failed"
              unless ($output =~ /i.?\s+\|\spatterns-$pattern\s+\|\spackage\s\|\sRequired/);
        }
    }
    elsif (check_var('SLE_PRODUCT', 'sles') && get_var('HANA')) {
        # We need this package for installing HANA on SLE
        zypper_call 'in libatomic1';
    }
    if (get_var('BONE')) {
        # enable business one repositories
        add_suseconnect_product('sle-module-development-tools');
        add_suseconnect_product('sle-module-sap-business-one');
        # also enable legacy module, due to bsc#1231763
        add_suseconnect_product('sle-module-legacy');
        my @bonepatterns = qw(patterns-sap-bone jq libidn11 rpm-build xmlstarlet glibc-i18ndata libicu60_2 nfs-kernel-server libcap-progs libopenssl3 openssl-3);
        my $wiz_name = is_sle('>=15-SP5') ? 'bone-installation-wizard' : 'sap-installation-wizard';    # wizard is called bone-installation-wizard in SLE15SP5+
        push @bonepatterns, $wiz_name;
        foreach my $pkg (@bonepatterns) {
            zypper_call("in -y $pkg");
        }
    }

    # Some specific package may be needed in HA mode
    zypper_call 'in sap-suse-cluster-connector' if get_var('HA_CLUSTER');

    # Workaround for textmode based test, as there is no SAP profiles with textmode yet
    zypper_call 'in libgomp1' if check_var('SYSTEM_ROLE', 'textmode');

    if (get_var('SAVE_LIST_OF_PACKAGES')) {
        script_run("rpm -qa > /tmp/rpm_packages_list.txt");
        upload_logs("/tmp/rpm_packages_list.txt");
    }
}

sub test_flags {
    return {milestone => 1};
}

1;
