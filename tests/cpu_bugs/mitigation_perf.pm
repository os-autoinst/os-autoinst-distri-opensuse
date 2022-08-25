# SUSE's openQA tests
#
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: mitigation_perf: virutalization and vulnerabiluty performance test
# Maintainer: xgwang@suse.com

package mitigation_perf;
use strict;
use warnings;
use testapi;
use base "consoletest";

sub get_perf_exec_cmd {
    my $logfile = shift;
    my $vt_perf_auto_path = '/root/vt-perf-auto/vt_perf_run.py';
    my $host = get_var('HOST');
    my $qaset_role = get_var('QASET_ROLE');
    my $prd_ver = get_var('PERF_PRD_VER');
    my $rls_ver = get_var('PERF_REL_VER');
    my $hyper_type = get_var('HYPER_TYPE');

    #my $logfile = 'screenlog_' . $hyper_type . '.' . $host;

    my $screen_name = 'vt_perf_auto_';
    my $exec_cmd;
    my $test_obj;
    $exec_cmd .= " python3 " . $vt_perf_auto_path . " perf_run ";
    $exec_cmd .= " --host=" . $host;
    $exec_cmd .= " --hypervisor=" . $hyper_type;
    $exec_cmd .= " --qaset-role=" . $qaset_role;
    $exec_cmd .= " --product-ver=" . lc($prd_ver);
    $exec_cmd .= " --release-ver=" . lc($rls_ver);

    my $exec_cmd_tmp;
    my $test_obj_tmp;
    if ($hyper_type eq 'kvm') {
        ($exec_cmd_tmp, $test_obj_tmp) =
          get_baremetal_and_kvm_guest_perf_cmd();
    }
    else {
        ($exec_cmd_tmp, $test_obj_tmp) = get_xen_dom0_and_guest_perf_cmd();
    }
    $exec_cmd .= $exec_cmd_tmp;
    $screen_name .= $test_obj_tmp . $host;

    return (
        'screen -dmS '
          . $screen_name
          . ' -L -Logfile '
          . $logfile
          . ' sh -c "script -c \\"'
          . $exec_cmd,
        $screen_name
    );
}

sub get_baremetal_and_kvm_guest_perf_cmd {
    my $exec_cmd;
    my $test_obj;
    if (check_var('BAREMETAL_PERF', '1')) {
        $exec_cmd .= " --enable_baremetal";
        $exec_cmd .=
          " --baremetal-tc-run-times=" . get_var('BAREMETAL_TC_RUN_TIMES', 3);
        $exec_cmd .= " --baremetal-hyper_mitigation="
          . get_var('BAREMETAL_KER_STATUS', 'all');
        foreach my $testcase (split(/,+/, get_var('BAREMETAL_CASES', "")))
        {
            $exec_cmd .= " --baremetal-tc=" . $testcase;
        }
        if (check_var('BAREMETAL_NETTEST', '1')) {
            $exec_cmd .= " --baremetal-nettest";
            $test_obj .= 'baremetal_netio_';
        }
        else {
            $test_obj .= "baremetal_diskio_";
        }
    }

    if (check_var('KVMGUEST_PERF', '1')) {
        $exec_cmd .= " --enable-kvm-guest";
        $exec_cmd .=
          " --kvm-tc-run-times=" . get_var('KVMGUEST_TC_RUN_TIMES', 3);
        $exec_cmd .=
          " --kvm-hyper_mitigation=" . get_var('KVM_HYPER_STATUS', 'all');
        $exec_cmd .=
          " --kvm-guest_mitigation=" . get_var('KVMGUEST_KER_STATUS', 'all');
        foreach my $testcase (split(/,+/, get_var('KVMGUEST_CASES', '')))
        {
            $exec_cmd .= " --kvm-tc=" . $testcase;
        }
        if (!check_var('KVMGUEST_PRD_URL', '')) {
            $exec_cmd .= " --kvm-guest-prd-url=" . get_var('KVMGUEST_PRD_URL');
        }
        if (check_var('KVMGUEST_NETTEST', '1')) {
            $exec_cmd .= " --kvm-guest-nettest";
            $test_obj .= 'kvm_netio_';
        }
        else {
            $test_obj .= "kvm_diskio_";
        }
    }

    $exec_cmd .= ' \\""';
    return ($exec_cmd, $test_obj);
}

sub get_xen_dom0_and_guest_perf_cmd {
    my $exec_cmd;
    my $test_obj;
    if (check_var('DOM0_PERF', '1')) {
        $exec_cmd .= " --enable_dom0";
        $exec_cmd .=
          " --dom0-tc-run-times=" . get_var('DOM0_TC_RUN_TIMES', 3);
        $exec_cmd .=
          " --dom0-kernel_mitigation=" . get_var('DOM0_KER_STATUS', 'all');
        $exec_cmd .=
          " --dom0-hyper_mitigation=" . get_var('DOM0_HYPER_STATUS', 'all');
        foreach my $testcase (split(/,+/, get_var('DOM0_CASES', ""))) {
            $exec_cmd .= " --dom0-tc=" . $testcase;
        }
        if (check_var('DOM0_NETTEST', '1')) {
            $exec_cmd .= " --dom0-nettest";
            $test_obj .= 'dom0_nettest_';
        }
        else {
            $test_obj .= "dom0_diskio_";
        }
    }
    if (check_var('XEN_HVM_PERF', '1')) {
        $exec_cmd .= " --enable-xen-hvm";
        $exec_cmd .=
          " --xen-hvm-tc-run-times=" . get_var('XEN_HVM_TC_RUN_TIMES', 3);
        $exec_cmd .= " --xen-hyper-mitigation-for-hvm="
          . get_var('XEN_HVM_HYPER_STATUS', 'all');
        $exec_cmd .=
          " --xen-hvm-mitigation=" . get_var('XEN_HVM_KER_STATUS', 'all');
        foreach my $testcase (split(/,+/, get_var('XEN_HVM_CASES', ''))) {
            $exec_cmd .= " --xen-hvm-tc=" . $testcase;
        }
        if (!check_var('XEN_HVM_PRD_URL', '')) {
            $exec_cmd .= " --xen-hvm-prd-url=" . get_var('XEN_HVM_PRD_URL');
        }
        if (check_var('XEN_HVM_NETTEST', '1')) {
            $exec_cmd .= " --xen-hvm-nettest";
            $test_obj .= 'xen_hvm_nettest_';
        }
        else {
            $test_obj .= "xen_hvm_diskio_";
        }
    }
    if (check_var('XEN_PV_PERF', '1')) {
        $exec_cmd .= " --enable-xen-pv";
        $exec_cmd .=
          " --xen-pv-tc-run-times=" . get_var('XEN_PV_TC_RUN_TIMES', 3);
        $exec_cmd .= " --xen-hyper-mitigation-for-pv="
          . get_var('XEN_PV_HYPER_STATUS', 'all');
        $exec_cmd .=
          " --xen-pv-mitigation=" . get_var('XEN_PV_KER_STATUS', 'all');
        foreach my $testcase (split(/,+/, get_var('XEN_PV_CASES', ''))) {
            $exec_cmd .= " --xen-pv-tc=" . $testcase;
        }
        if (!check_var('XEN_PV_PRD_URL', '')) {
            $exec_cmd .= " --xen-pv-prd-url=" . get_var('XEN_PV_PRD_URL');
        }
        if (check_var('XEN_PV_NETTEST', '1')) {
            $exec_cmd .= " --xen-pv-nettest";
            $test_obj .= 'xen_pv_nettest_';
        }
        else {
            $test_obj .= "xen_pv_diskio_";
        }
    }

    $exec_cmd .= ' \\""';
    return ($exec_cmd, $test_obj);
}

sub run {
    my $self = shift;
    my $miti_perf_code_path = '/root/vt-perf-auto';
    my $nettest = '';
    my $test_type = '';

    if (check_var('BAREMETAL_PERF', '1')) {
        $test_type = $test_type . '-baremetal';
    }
    if (check_var('KVMGUEST_PERF', '1')) {
        $test_type = $test_type . '-kvm';
    }
    if (check_var('DOM0_PERF', '1')) {
        $test_type = $test_type . '-dom0';
    }
    if (check_var('XEN_HVM_PERF', '1')) {
        $test_type = $test_type . '-hvm';
    }
    if (check_var('XEN_PV_PERF', '1')) {
        $test_type = $test_type . '-pv';
    }
    my $logfile =
      'screenlog_openqa-'
      . get_var('HYPER_TYPE')
      . $test_type
      . $nettest . '.'
      . get_var('HOST');

    my $svirt = select_console('svirt', await_console => 0);
    my $ret = $svirt->run_cmd('test -d ' . $miti_perf_code_path);
    my $ipmi_host = get_var("IPMI_HOST");
    if ($ret != 0) {
        $svirt->run_cmd('git clone ' . $miti_perf_code_path);
    }
    else {
        $svirt->run_cmd(
            'cd ' . $miti_perf_code_path . "; git pull" . "; cd ..");
    }

    my ($perf_exec_cmd, $screen_name) = get_perf_exec_cmd($logfile);
    print $perf_exec_cmd . "\n";
    $ret = $svirt->run_cmd('test -f ' . $logfile);
    if ($ret == 0) {
        $svirt->run_cmd('rm -rf ' . $logfile);
    }
    sleep 60;

    $ret = $svirt->run_cmd("screen -ls | grep -i " . $screen_name);
    if ($ret == 0) {
        $svirt->run_cmd("screen -S " . $screen_name . " -X quit");
    }
    $svirt->run_cmd($perf_exec_cmd);

    for (;;) {
        $svirt->run_cmd("screen -wipe");
        $ret = $svirt->run_cmd("screen -ls | grep -i " . $screen_name);
        if ($ret != 0) {
            last;
        }
        sleep(30);
    }

    #upload_logs("/root/$logfile");
}
1;

