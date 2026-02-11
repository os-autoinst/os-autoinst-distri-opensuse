# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: setup performance run environment for the new deploy script.
# Maintainer: Qi Wang <qi.wang@suse.de>

package install_sleperf;
use base 'y2_installbase';
use power_action_utils 'power_action';
use utils;
use testapi;
use Utils::Architectures;
use version_utils qw(is_sle is_agama);
use mmapi 'wait_for_children';
use ipmi_backend_utils;
our $VERSION = get_var('VERSION');

sub install_pkg {
    my $deploy;
    my $repo = get_var("SLE_PERFORMANCE_REPO", "http://10.200.134.67/repo/sleperf/SLEPerf/utils/sleperf_deploy.sh");
    if (is_sle('<16')) {
        $deploy = lc($VERSION);
        $deploy =~ s/-//g;
    } elsif (is_sle('=16.0')) {
        $deploy = '16';
    } elsif (is_sle('=16.1')) {
        $deploy = '16.1';
    }
    assert_script_run("curl $repo >>sleperf_deploy.sh");
    assert_script_run("sh sleperf_deploy.sh -t sles$deploy");

}

sub extract_settings_qaset_config {
    my $values = shift;
    my @fields = split(/;/, $values);
    if (scalar @fields > 0) {
        foreach my $a_value (@fields) {
            assert_script_run("echo '${a_value}' >> /root/qaset/config");
        }
    }
}


sub setup_environment {
    my $qaset_role = get_required_var('QASET_ROLE');
    my $ver_cfg = get_var('VER_CFG');

    # Fill $ver_cfg by default value if it is undefined
    unless ($ver_cfg) {
        my $mybuild = check_var('BUILD', 'GM') ? "GM" : "Build" . get_var("BUILD", '');
        $ver_cfg = "PRODUCT_RELEASE=SLES-" . get_var('VERSION') . ";PRODUCT_BUILD=$mybuild";
    }

    assert_script_run("systemctl disable qaperf.service");

    # Extract the openQA parameter: VER_CFG="PRODUCT_RELEASE=SLES-15-SP3;PRODUCT_BUILD=202109"
    extract_settings_qaset_config($ver_cfg);
}

sub run {
    my $self = shift;
    install_pkg;
    setup_environment;
    power_action('poweroff', keepconsole => 1, textmode => 1);

}

sub post_fail_hook {
    my ($self) = @_;
}

sub test_flags {
    return {fatal => 1};
}

1;


