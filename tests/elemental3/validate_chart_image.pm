# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Validate chart image
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use Mojo::Base 'opensusebasetest';
use elemental3;
use testapi;
use serial_terminal qw(select_serial_terminal);

sub run {
    my $arch = get_required_var('ARCH');
    my $tested_chart = get_required_var('TESTED_CHART');
    my $totest_path = get_required_var('TOTEST_PATH');

    # No GUI, easier and quicker to use the serial console
    select_serial_terminal();

    # Basic test of Helm chart images
    if ($tested_chart =~ /lcm/) {
        foreach my $chart ('lifecycle-manager-crds', 'lifecycle-manager') {
            my $uri = get_artifact_uri(
                url => $totest_path,
                dir => '/charts',
                regex => ".*${chart}-\([0-9]\\..*\)",
                prefix => "\\.tgz\$"
            );
            assert_script_run("curl -sf -o ${chart}.tgz $uri");
            assert_script_run("tar tzf ${chart}.tgz | grep Chart.yaml");

            # Record files list
            record_info("$chart files", script_output("tar tzf ${chart}.tgz"));
        }
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
