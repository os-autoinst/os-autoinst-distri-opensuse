# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: SAP Pattern test
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use base "sles4sap";
use testapi;
use utils;
use version_utils qw(is_sle is_upgrade);
use strict;

sub run {
    my ($self)      = @_;
    my @sappatterns = qw(sap-nw sap-b1 sap-hana);
    my $output      = '';

    select_console 'root-console';

    # Disable packagekit
    pkcon_quit;

    my $base_pattern = is_sle('>=15') ? 'patterns-server-enterprise-sap_server' : 'patterns-sles-sap_server';

    # First check pattern sap_server which is installed by default in SLES4SAP
    # when 'SLES for SAP Applications' system role is selected
    $output = script_output("zypper info -t pattern sap_server");
    if ($output !~ /i\+\s\|\s$base_pattern\s+\|\spackage\s\|\sRequired/) {
        # Pattern sap_server is not installed. Could be a due to a bug, caused by the
        # use of the 'textmode' system role during install, or on upgrades when the
        # original system didn't have the pattern (for example, from SLES4SAP 11-SP4)
        die "Pattern sap_server not installed by default"
          unless (check_var('SYSTEM_ROLE', 'textmode') or is_upgrade());
        record_info('install sap_server', 'Installing sap_server pattern and starting tuned');
        assert_script_run("zypper in -y -t pattern sap_server");
        assert_script_run("systemctl start tuned");
    }

    # Dry run of each pattern's installation before actual installation
    foreach my $pattern (@sappatterns) {
        assert_script_run("zypper in -D -y -t pattern $pattern");
        $output = script_output("zypper info --requires $pattern");
        record_info("requirements pattern: $pattern", $output);
    }

    # Actual installation and verification
    foreach my $pattern (@sappatterns) {
        assert_script_run("zypper in -y -t pattern $pattern", 100);
        $output = script_output "zypper info -t pattern $pattern";
        die "SAP zypper pattern [$pattern] info check failed"
          unless ($output =~ /i\+\s\|\spatterns-$pattern\s+\|\spackage\s\|\sRequired/);
    }
}

sub test_flags {
    return {milestone => 1};
}

1;
