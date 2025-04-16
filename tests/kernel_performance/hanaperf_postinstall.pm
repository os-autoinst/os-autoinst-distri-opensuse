# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Post installation for HANA perf SLE16 testing
# Inherit from install_qatestset.pm
# Maintainer: QE-SAP <qe-sap@suse.de>

package hanaperf_postinstall;
use base 'y2_installbase';
use power_action_utils 'power_action';
use strict;
use warnings;
use utils;
use testapi;
use Utils::Architectures;
use repo_tools 'add_qa_head_repo';
use mmapi 'wait_for_children';
use version_utils qw(is_sle);
use ipmi_backend_utils;

sub install_sleperf {
    my $sleperf_source = get_var('SLE_SOURCE');
    my $ver_path = '/root';

    # Download SLEperf package, extract and install
    assert_script_run("wget --quiet -O $ver_path/sleperf.tar $sleperf_source 2>&1");
    assert_script_run('tar xf /root/sleperf.tar -C /root');
    assert_script_run('cd /root/sleperf/SLEPerf; ./installer.sh scheduler-service');
    assert_script_run('cd /root/sleperf/SLEPerf; ./installer.sh common-infra');
}

sub extract_settings_qaset_config {
    my $values = shift;
    my @fields = split(/;/, $values);
    if (@fields > 0) {
        foreach my $a_value (@fields) {
            record_info(${a_value});
            assert_script_run("echo '${a_value}' >> /root/qaset/config");
        }
    }
}

sub setup_environment {
    my $qaset_role = get_var('QASET_ROLE', 'HANA');
    my $mitigation_switch = get_var('MITIGATION_SWITCH', 'mitigations=auto');
    my $qaset_kernel_tag = get_var('QASET_KERNEL_TAG', '');
    my $ver_cfg = get_var('VER_CFG');

    # Fill $ver_cfg by default value if it is undefined
    unless ($ver_cfg) {
        my $mybuild = check_var('BUILD', 'GM') ? 'GM' : 'Build' . get_var('BUILD', '');
        $ver_cfg = 'PRODUCT_RELEASE=SLES-' . get_required_var('VERSION') . ";PRODUCT_BUILD=$mybuild";
        record_info($ver_cfg);
    }

    # Disable service
    assert_script_run('systemctl disable qaperf.service chronyd.service firewalld.service');

    # sync time
    assert_script_run("chronyd -q 'server 0.europe.pool.ntp.org iburst'");

    # set static hostname
    assert_script_run('hostnamectl hostname `hostname -s`');

    # create basic /root/qaset/config
    assert_script_run('mkdir -p /root/qaset/');
    my $qaset_config_file = <<'EOF';
_QASET_ROLE=HANA
SQ_TEST_RUN_SET=performance
SQ_MSG_QUEUE_ENALBE=y
_QASET_SOFTWARE_TAG=baremetal
_QASET_SOFTWARE_SUB_TAG=default
EOF
    assert_script_run("echo -n '$qaset_config_file' > /root/qaset/config");
    assert_script_run("echo '_QASET_KERNEL_TAG=$qaset_kernel_tag' >> /root/qaset/config") if $qaset_kernel_tag ne '';

    # workaround to prevent network interface random order
    if (check_var('PROJECT_M_ROLE', 'PROJECT_M_ABAP')) {
        my $service_file = <<'EOF';
[Unit]
Description=Load bnxt_en driver manually
After=sshd.service
[Service]
Type=oneshot
ExecStart=/sbin/modprobe bnxt_en
TimeoutSec=0
RemainAfterExit=no
TasksMax=12000
[Install]
WantedBy=multi-user.target
EOF
        assert_script_run("echo 'blacklist bnxt_en' >> /etc/modprobe.d/50-blacklist.conf");
        assert_script_run("echo '$service_file' > /usr/lib/systemd/system/load_bnxt_en.service");
        assert_script_run("systemctl enable load_bnxt_en.service --now");
    }


    # The qaset/config need not be updated when role is HANA and ABAP
    return if (get_var('PROJECT_M_ROLE', '') =~ /PROJECT_M_HANA|PROJECT_M_ABAP/);

    # Extract the openQA parameter: QASET_CONFIG and VER_CFG
    # Historical reasons that the different settings splitted into two parameters.
    # VER_CFG="PRODUCT_RELEASE=SLES-15-SP3;PRODUCT_BUILD=202109"
    extract_settings_qaset_config(get_var('QASET_CONFIG', ''));
    extract_settings_qaset_config($ver_cfg);
}

sub os_update {
    my $update_repo_url = shift;
    my $zypper_repo_path = '/etc/zypp/repos.d';

    assert_script_run("wget -N -P $zypper_repo_path $update_repo_url 2>&1");
    zypper_call('--gpg-auto-import-keys ref');
    zypper_call('dup', timeout => 1800);
}

sub handle_repo_and_package {
    # Add QA:HEAD repo
    add_qa_head_repo;

    # Install mandatory packages for SLE16
    zypper_call('install qa_lib_ctcs2 wget bc bzip2 screen cpupower pciutils lsscsi ' .
          'smartmontools netcat-openbsd libltdl7 unzip lvm hana_insserv_compat');
    zypper_call('rm snapper-zypp-plugin');
}

sub run {
    my $self = shift;

    my $project_m_role = get_var('PROJECT_M_ROLE', '');

    select_console 'root-console';

    # Add repo, remove and install packages
    handle_repo_and_package;

    # Update OS for MU testing
    if (my $hana_perf_os_update = get_var('HANA_PERF_OS_UPDATE')) {
        os_update($hana_perf_os_update);
    }

    # Install SLEperf test framework
    install_sleperf;

    # Setup environment
    setup_environment;

    # Hold and wait other job finish if role is driver
    wait_for_children if ($project_m_role eq 'PROJECT_M_DRIVER');

    # Reboot system
    power_action('reboot', textmode => 1);
    if (is_x86_64) {
        # Handle x86_64 bare-metal reboot
        switch_from_ssh_to_sol_console(reset_console_flag => 'on');
        sleep 30;
        assert_screen('linux-login', 2400);
    }
}

sub post_fail_hook {
    my ($self) = @_;
}

sub test_flags {
    return {fatal => 1};
}

1;
