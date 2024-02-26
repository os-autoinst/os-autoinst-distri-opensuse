# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: setup performance run environment
# Maintainer: Joyce Na <jna@suse.de>

package install_qatestset;
use base 'y2_installbase';
use power_action_utils 'power_action';
use strict;
use warnings;
use utils;
use testapi;
use Utils::Architectures;
use repo_tools 'add_qa_head_repo';
use mmapi 'wait_for_children';
use ipmi_backend_utils;

sub install_pkg {
    my $sleperf_source = get_var('SLE_SOURCE');
    my $ver_path = "/root";
    add_qa_head_repo;

    # Download SLEperf package, extract and install
    assert_script_run("wget --quiet -O $ver_path/sleperf.tar $sleperf_source 2>&1");
    assert_script_run("tar xf /root/sleperf.tar -C /root");
    assert_script_run("cd /root/sleperf/SLEPerf; ./installer.sh scheduler-service");
    assert_script_run("cd /root/sleperf/SLEPerf; ./installer.sh common-infra");

    # Install qa_lib_ctcs2 package to fix dependency issue
    zypper_call("install qa_lib_ctcs2");
    if (get_var('VERSION') =~ /^12/) {
        zypper_call("install python3");
    }
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
    my $mitigation_switch = get_required_var('MITIGATION_SWITCH');
    my $ver_cfg = get_required_var('VER_CFG');

    assert_script_run("systemctl disable qaperf.service");

    if (get_var("HANA_PERF")) {
        # workaround for kvmskx1
        if (get_var('MACHINE') =~ /64bit-ipmi-kvmskx1/) {
            assert_script_run(qq(echo "blacklist {\n\t device { \n\t\t   vendor FTS \n\t\t   product PRAID* \n\t   } \n}" > /etc/multipath.conf));
            assert_script_run("systemctl enable multipathd");
            assert_script_run("sed -e '/blacklist qla2xxx/s/^/#/g' -i /etc/modprobe.d/50-blacklist.conf");
        }
        # Workaround for hana02~05 disable megaraid_sas during installation and enable it during post-install
        if (get_var('MACHINE') =~ /64bit-ipmi-hana0[2-5]/) {
            assert_script_run("sed -e '/blacklist megaraid_sas/s/^/#/g' -i /etc/modprobe.d/50-blacklist.conf");
        }
        # END for workaround for kvmskx1
        my $qaset_kernel_tag = ' ' . get_var('QASET_KERNEL_TAG', '');
        assert_script_run("/usr/share/qa/qaset/bin/deploy_hana_perf.sh HANA $mitigation_switch $qaset_kernel_tag");
        assert_script_run("ls /root/qaset/deploy_hana_perf_env.done");

        return if (get_var('PROJECT_M_ROLE', "") =~ /PROJECT_M_HANA|PROJECT_M_ABAP/);

        if (my $qaset_config = get_var("QASET_CONFIG")) {
            extract_settings_qaset_config($qaset_config);
        }
    } else {
        assert_script_run(
            "/usr/share/qa/qaset/bin/deploy_performance.sh $qaset_role $mitigation_switch"
        );
        assert_script_run("cat /root/qaset/qaset-setup.log");
    }
    # Extract the openQA parameter: VER_CFG="PRODUCT_RELEASE=SLES-15-SP3;PRODUCT_BUILD=202109"
    extract_settings_qaset_config($ver_cfg);
}

sub os_update {
    my $update_repo_url = shift;
    my $zypper_repo_path = "/etc/zypp/repos.d";

    assert_script_run("wget -N -P $zypper_repo_path $update_repo_url 2>&1");
    zypper_call("--gpg-auto-import-keys ref");
    zypper_call("dup", timeout => 1800);
}

sub run {
    my $self = shift;
    # Add more packages for HANAonKVM with 15SP2
    if (get_var('HANA_PERF') && get_var('VERSION') eq '15-SP2' && get_var('SYSTEM_ROLE') eq 'kvm') {
        zypper_call("install wget iputils supportutils rsync screen smartmontools tcsh");
    }

    if (my $hana_perf_os_update = get_var("HANA_PERF_OS_UPDATE")) {
        os_update($hana_perf_os_update);
    }

    my $project_m_role = get_var("PROJECT_M_ROLE", "");

    install_pkg;
    setup_environment;

    wait_for_children if ($project_m_role eq "PROJECT_M_DRIVER");

    if (is_ppc64le) {
        power_action('reboot', keepconsole => 1, textmode => 1);
    } else {
        if ($project_m_role eq "PROJECT_M_HANA" || $project_m_role eq "PROJECT_M_ABAP") {
            power_action('reboot', textmode => 1);
            switch_from_ssh_to_sol_console(reset_console_flag => 'on');
            sleep 30;
            assert_screen("linux-login", 2400);
        } else {
            power_action('poweroff', keepconsole => 1, textmode => 1);
        }
    }
}

sub post_fail_hook {
    my ($self) = @_;
}

sub test_flags {
    return {fatal => 1};
}

1;
