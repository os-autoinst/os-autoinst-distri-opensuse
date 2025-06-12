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
use version_utils qw(is_sle has_selinux);

sub setup_rules_for_sleperf_when_selinux_enforcing {
    if (has_selinux && script_output('getenforce') eq 'Enforcing') {
        my @sleperf_selinux_rules = (
            '-t var_log_t "/var/log/qa(/.*)?"',
            '-t var_log_t "/var/log/qaset(/.*)?"',
            '-t usr_t "/usr/share/qa(/.*)?"',
            '-t bin_t "/usr/share/qa/qaset/bin(/.*)?"',
            '-t bin_t "/usr/share/qa/perfcom/perfcmd.py"',
            '-t systemd_unit_file_t "/usr/lib/systemd/system/qaperf.service"');
        assert_script_run("semanage fcontext -a -s system_u $_") foreach (@sleperf_selinux_rules);
        # TODO: SLEperf will fix to create /var/log/qa dir later, skip assert checking here
        script_run('restorecon -FR -v /var/log/qa');
        assert_script_run('restorecon -FR -v /var/log/qaset');
        assert_script_run('restorecon -FR -v /usr/share/qa');
        assert_script_run('restorecon -FR -v /usr/lib/systemd/system/qaperf.service');
        assert_script_run('restorecon -FR -v /etc/systemd/system/multi-user.target.wants/qaperf.service');
    }
}

sub install_pkg {
    my $sleperf_source = get_var('SLE_SOURCE');
    my $ver_path = "/root";
    add_qa_head_repo;

    # Download SLEperf package, extract and install
    assert_script_run("wget --quiet -O $ver_path/sleperf.tar $sleperf_source 2>&1");
    assert_script_run("tar xf /root/sleperf.tar -C /root");
    assert_script_run("cd /root/sleperf/SLEPerf; ./installer.sh scheduler-service");
    assert_script_run("cd /root/sleperf/SLEPerf; ./installer.sh common-infra");

    # Setup selinux rule for sleperf
    setup_rules_for_sleperf_when_selinux_enforcing;

    # Install qa_lib_ctcs2 package to fix dependency issue
    zypper_call("install qa_lib_ctcs2");
    if (get_var('VERSION') =~ /^12/) {
        zypper_call("install python3");
    }
    # Install missing packages for SLE16
    if (is_sle('16+') && get_var('HANA_PERF')) {
        zypper_call('install qa_lib_ctcs2 wget bc bzip2 screen cpupower pciutils lsscsi ' .
              'smartmontools netcat-openbsd libltdl7 unzip lvm hana_insserv_compat');
        zypper_call('rm snapper-zypp-plugin');
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
    my $ver_cfg = get_var('VER_CFG');

    # Fill $ver_cfg by default value if it is undefined
    unless ($ver_cfg) {
        my $mybuild = check_var('BUILD', 'GM') ? "GM" : "Build" . get_var("BUILD", '');
        $ver_cfg = "PRODUCT_RELEASE=SLES-" . get_var('VERSION') . ";PRODUCT_BUILD=$mybuild";
    }

    assert_script_run("systemctl disable qaperf.service");

    if (get_var("HANA_PERF")) {
        # workaround for kvmskx1
        if (get_var('MACHINE') =~ /64bit-ipmi-kvmskx1/) {
            assert_script_run(qq(echo "blacklist {\n\t device { \n\t\t   vendor FTS \n\t\t   product PRAID* \n\t   } \n}" > /etc/multipath.conf));
            assert_script_run("systemctl enable multipathd");
            assert_script_run("sed -e '/blacklist qla2xxx/s/^/#/g' -i /etc/modprobe.d/50-blacklist.conf");
        }
        # Workaround for hana02~05 disable megaraid_sas during installation and enable it during post-install
        if (is_sle("<16") && (get_var('MACHINE') =~ /64bit-ipmi-hana0[2-5]/)) {
            assert_script_run("sed -e '/blacklist megaraid_sas/s/^/#/g' -i /etc/modprobe.d/50-blacklist.conf");
        }
        # END for workaround for kvmskx1
        my $qaset_kernel_tag = get_var('QASET_KERNEL_TAG', '');
        if (is_sle("16+")) {
            # HANA perf does not use /usr/share/qa/qaset/bin/deploy_hana_perf.sh in SLE16
            # Disable and stop service
            assert_script_run('systemctl disable qaperf.service chronyd.service firewalld.service --now');
            # sync time
            assert_script_run("chronyd -q 'server ntp1.suse.de iburst'");
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
        } else {
            assert_script_run("/usr/share/qa/qaset/bin/deploy_hana_perf.sh HANA $mitigation_switch $qaset_kernel_tag");
            assert_script_run("ls /root/qaset/deploy_hana_perf_env.done");
        }

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

    select_console 'root-console' if (is_sle('16+') && get_var('HANA_PERF'));

    if (has_selinux) {
        my $selinux_mode = get_var('HANAPERF_SELINUX_SETENFORCE', 'Enforcing');
        record_info('sestatus', script_output('sestatus'));
        if (script_output('getenforce') !~ m/$selinux_mode/i) {
            assert_script_run('setenforce ' . $selinux_mode);
            validate_script_output('getenforce', sub { m/$selinux_mode/i });
            # Modify /etc/selinux/config and "SELINUX=" uses low case
            $selinux_mode = lc $selinux_mode;
            assert_script_run("sed -i -e 's/^SELINUX=/#SELINUX=/' /etc/selinux/config");
            assert_script_run("echo 'SELINUX=$selinux_mode' >> /etc/selinux/config");
            record_info('sestatus', script_output('sestatus'));
        }
    }

    # Add more packages for HANAonKVM with 15SP2
    if (get_var('HANA_PERF') && get_var('VERSION') eq '15-SP2' && get_var('SYSTEM_ROLE') eq 'kvm') {
        zypper_call("install wget iputils supportutils rsync screen smartmontools tcsh");
    }

    # Update OS for MU testing
    if (my $hana_perf_os_update = get_var("HANA_PERF_OS_UPDATE")) {
        os_update($hana_perf_os_update);
    }

    my $project_m_role = get_var("PROJECT_M_ROLE", "");

    install_pkg;
    setup_environment;

    wait_for_children if ($project_m_role eq "PROJECT_M_DRIVER");

    if (get_var('HANA_PERF')) {
        power_action('reboot', textmode => 1);
        if (is_x86_64) {
            # Handle x86_64 bare-metal reboot
            switch_from_ssh_to_sol_console(reset_console_flag => 'on');
            sleep 30;
            assert_screen("linux-login", 2400);
        }
    } else {
        power_action('poweroff', keepconsole => 1, textmode => 1);
    }
}

sub post_fail_hook {
    my ($self) = @_;
}

sub test_flags {
    return {fatal => 1};
}

1;
