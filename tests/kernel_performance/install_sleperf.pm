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
use strict;
use warnings;
use utils;
use testapi;
use Utils::Architectures;
use version_utils qw(is_sle is_agama);
#use repo_tools 'add_qa_head_repo';
use mmapi 'wait_for_children';
use ipmi_backend_utils;
our $VERSION = get_var('VERSION');
sub install_pkg {
    my $deploy;
    my $sleperf_source = get_var('SLE_SOURCE');
    sleep 60;
    if ($VERSION =~ /^12/) {
        zypper_call("install python3");
    } elsif ($VERSION =~ /^15/) {
        $deploy = lc($VERSION);
        $deploy =~ s/-//g;
    } elsif ($VERSION =~ /^16/) {
        $deploy = '16';
    }
    assert_script_run("curl http://10.200.134.67/repo/sleperf/SLEPerf/utils/sleperf_deploy.sh >>sleperf_deploy.sh");
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

sub suseconnect_reg {
    ########
    # Workaround to install sle16 in beta1
    # Don't register the system during the installation and use daily build as install url
    # Register the system once installation done
    if (is_agama && is_sle) {
        zypper_call('in suseconnect-ng');
        record_info "agama pscc register";
        my $regcode = (get_var('AGAMA_PRODUCT_ID') =~ /SAP/) ? get_var('SCC_REGCODE_SLES4SAP') : get_var('SCC_REGCODE');
        my $regurl = get_var('SCC_URL');
        assert_script_run("suseconnect -r $regcode --url $regurl");
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
    # Add more packages for HANAonKVM with 15SP2

    my $project_m_role = get_var("PROJECT_M_ROLE", "");
    if ($VERSION =~ /16/)
    {
        suseconnect_reg;
    }
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

