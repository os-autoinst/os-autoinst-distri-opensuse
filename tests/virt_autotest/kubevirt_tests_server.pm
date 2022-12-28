# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This kubevirt test relies on the upstream test code, which is downstreamed as virt-tests.
#          This is the part running on server node.
# Maintainer: Nan Zhang <nan.zhang@suse.com> qe-virt@suse.de

use base multi_machine_job_base;
use base prepare_transactional_server;
use strict;
use warnings;
use testapi;
use lockapi;
use transactional;
use utils;
use mmapi;
use version_utils qw(is_transactional);
use File::Basename;
use Utils::Systemd;
use Utils::Backends 'use_ssh_serial_console';
use Utils::Logging qw(save_and_upload_log save_and_upload_systemd_unit_log);

our $if_case_fail;
my @full_tests = (
    'vmi_lifecycle_test',
    'vm_test',
    'vmipreset_test',
    'vmi_configuration_test',
    'vmi_headless_test',
    'access_test',
    'storage_test',
    'container_disk_test',
    'datavolume_test',
    'hotplug_test',
    'vmi_cloudinit_test',
    'vmi_iothreads_test',
    'vmi_multiqueue_test',
    'primary_pod_network_test',
    'vmi_multus_test',
    'vmi_networking_test',
    'networkpolicy_test',
    'vmi_monitoring_test',
    'vnc_test',
    'console_test',
    'credentials_test',
    'expose_test',
    'replicaset_test',
    'network_services_test',
    'vmi_kernel_boot_test',
    'infra_test',
    'operator_test',
    'migration_test',
    'subresource_api_test',
    'virt_control_plane_test'
);
my @core_tests = (
    'vmi_lifecycle_test',
    'datavolume_test',
    'container_disk_test',
    'storage_test',
    'console_test',
    'vnc_test',
    'expose_test',
    'replicaset_test'
);

sub run {
    my ($self) = shift;

    if (get_required_var('WITH_HOST_INSTALL')) {
        my $sut_ip = get_required_var('SUT_IP');

        set_var('SERVER_IP', $sut_ip);
        bmwqemu::save_vars();

        # Synchronize the server & agent node before setup
        barrier_wait('kubevirt_test_setup');

        my $agent_ip = $self->get_var_from_child("AGENT_IP");
        record_info('Agent IP', $agent_ip);

        $self->rke2_server_setup($agent_ip);
        $self->install_kubevirt_packages();
        $self->deploy_kubevirt_manifests();
    } else {
        select_console 'sol', await_console => 0;
        use_ssh_serial_console;
    }

    $self->run_virt_tests();

    barrier_wait('kubevirt_test_done');

    die "Testing failed, please check details." if ($if_case_fail);
}

sub rke2_server_setup {
    my ($self, $agent_ip) = @_;

    record_info('Start RKE2 server setup', '');
    unless (is_transactional) {
        disable_and_stop_service('apparmor.service');
        disable_and_stop_service('firewalld.service');
    }
    $self->setup_passwordless_ssh_login($agent_ip);

    # rebootmgr has to be turned off as prerequisity for this to work
    script_run('rebootmgrctl set-strategy off') if (is_transactional);
    # Check if the package 'ca-certificates-suse' are installed on the node
    ensure_ca_certificates_suse_installed();
    transactional::process_reboot(trigger => 1) if (is_transactional);

    # RKE2 deployment on server node
    # Default is to setup service with the latest RKE2 version, the parameter INSTALL_RKE2_VERSION allows to setup with a specified version.
    my $rke2_ver = get_var('INSTALL_RKE2_VERSION');
    if ($rke2_ver) {
        record_info('RKE2 version', $rke2_ver);
        assert_script_run("curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=$rke2_ver sh -", timeout => 180);
    } else {
        assert_script_run('curl -sfL https://get.rke2.io | sh -', timeout => 180);
    }

    # Add kubectl command to $PATH environment varibable
    my $rke2_bin_path = "export PATH=\$PATH:/opt/rke2/bin:/var/lib/rancher/rke2/bin";
    assert_script_run("echo '$rke2_bin_path' >> \$HOME/.bashrc; source \$HOME/.bashrc");

    # For network multus backend testing
    assert_script_run("sed -i '/ExecStart=/s/server\$/server --cni=multus,canal/' /etc/systemd/system/rke2-server.service");

    # Enable rke2-server service
    systemctl('enable rke2-server.service');
    systemctl('start rke2-server.service', timeout => 180);
    $self->check_service_status();

    # Start rke2-server service ready
    barrier_wait('rke2_server_start_ready');

    assert_script_run('mkdir -p ~/.kube');
    assert_script_run('cp /etc/rancher/rke2/rke2.yaml ~/.kube/config');
    assert_script_run('kubectl get nodes');

    # Create registries ready
    script_run('cat > /etc/rancher/rke2/registries.yaml <<__END
mirrors:
  registry.suse.de:
    endpoint:
      - http://registry.suse.com
configs:
  registry.suse.com:
    tls:
      insecure_skip_verify: true
__END
true');

    # Wait for rke2-agent service to be ready
    my $children = get_children();
    mutex_wait('RKE2_AGENT_START_READY', (keys %$children)[0]);

    assert_script_run("scp /etc/rancher/rke2/registries.yaml root\@$agent_ip:/etc/rancher/rke2/registries.yaml");

    # Restart RKE2 service and check the service is active well after restart
    systemctl('restart rke2-server.service', timeout => 180);
    $self->check_service_status();

    # Restart rke2-server service complete
    barrier_wait('rke2_server_restart_complete');

    mutex_wait('RKE2_AGENT_RESTART_COMPLETE', (keys %$children)[0]);

    script_retry('! kubectl get nodes | grep NotReady', retry => 8, delay => 20, timeout => 180);
    assert_script_run('kubectl get nodes');
}

sub check_service_status {
    my $self = shift;
    # Check RKE2 service status and error message
    record_info('Check RKE2 service status and error message', '');
    assert_script_run("systemctl status rke2-server.service | grep 'active (running)'");
    assert_script_run("journalctl -u rke2-server | grep 'Started Rancher Kubernetes Engine v2 (server)'");
    assert_script_run("! journalctl -u rke2-server | grep \'\"level\":\"error\"\'");
}

sub install_kubevirt_packages {
    my $self = shift;
    # Install required kubevirt packages
    my $os_version = get_var('VERSION');
    my $virt_tests_repo = get_required_var('VIRT_TESTS_REPO');
    my $virt_manifests_repo = get_var('VIRT_MANIFESTS_REPO');

    record_info('Install kubevirt packages', '');
    # Development Tools repo for OBS Module, e.g. http://download.suse.de/download/ibs/SUSE/Products/SLE-Module-Development-Tools-OBS/15-SP4/x86_64/product/
    # Development product test repo for SLE official product OSD testing, e.g. http://download.suse.de/ibs/SUSE:/SLE-15-SP4:/GA/standard/
    # Devel test repo, e.g. http://download.suse.de/download/ibs/Devel:/Virt:/SLE-15-SP4/SUSE_SLE-15-SP4_Update_standard/
    # MU product test (SLE official MU channel+incidents)
    transactional::enter_trup_shell(global_options => '--drop-if-no-change') if (is_transactional);
    zypper_call("lr -d");
    zypper_call("ar $virt_tests_repo Virt-Tests-Repo");
    zypper_call("ar $virt_manifests_repo Virt-Manifests-Repo") if ($virt_manifests_repo);
    zypper_call("--gpg-auto-import-keys ref");

    my $virt_manifests = 'containerized-data-importer-manifests kubevirt-manifests kubevirt-virtctl';
    my $search_manifests = $virt_manifests =~ s/\s+/\\\|/gr;

    if ($virt_manifests_repo) {
        zypper_call("in -f -r Virt-Manifests-Repo $virt_manifests");
    } elsif (script_run("rpmquery $virt_manifests")) {
        if (is_transactional || script_run("zypper se -r SLE-Module-Containers${os_version}-Updates $virt_manifests | grep -w '$search_manifests'")) {
            zypper_call("in -f $virt_manifests");
        } else {
            zypper_call("in -f -r SLE-Module-Containers${os_version}-Updates $virt_manifests");
        }
    }
    zypper_call("in -f -r Virt-Tests-Repo kubevirt-tests");
    if (is_transactional) {
        transactional::exit_trup_shell_and_reboot();
        assert_script_run('kubectl get nodes');
    }
    record_info('Installed kubevirt package version', script_output('rpm -qa |grep -E "containerized|kubevirt|virt-test"'));
}

sub deploy_kubevirt_manifests {
    my $self = shift;
    # Deploy required kubevirt manifests
    my $kubevirt_ver = script_output("rpm -q --qf \%{VERSION} kubevirt-tests");

    record_info('Deploy kubevirt manifests', '');
    assert_script_run("kubectl apply -f /usr/share/cdi/manifests/release/cdi-operator.yaml");
    assert_script_run("kubectl apply -f /usr/share/cdi/manifests/release/cdi-cr.yaml");
    assert_script_run("kubectl -n cdi wait cdis cdi --for condition=available --timeout=30m", timeout => 1800);

    assert_script_run("kubectl apply -f /usr/share/kube-virt/manifests/release/kubevirt-operator.yaml");
    assert_script_run("kubectl apply -f /usr/share/kube-virt/manifests/release/kubevirt-cr.yaml");
    assert_script_run("kubectl -n kubevirt wait kv kubevirt --for condition=available --timeout=30m", timeout => 1800);

    # Check all loop devices to see if they refer to deleted files
    record_info('Check all loop devices', script_output('losetup -a -l'));
    # Detach all loop devices, the disk-image-provider needs to use it to setup images
    record_info('Detach all loop devices', script_output('losetup -D'));
    # Remove existing local disks
    record_info('Remove existing local disks', script_output('[ -d /tmp/hostImages -a -d /mnt/local-storage ] && rm -r /tmp/hostImages /mnt/local-storage', proceed_on_failure => 1));

    assert_script_run("kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v${kubevirt_ver}/rbac-for-testing.yaml");
    # Workaround for failure 'MountVolume.SetUp failed for volume "local-storage" : mkdir /mnt/local-storage: read-only file system'
    assert_script_run('mkdir -p /root/tmp && mount -o bind /root/tmp /mnt') if (is_transactional);
    assert_script_run("kubectl apply -f /usr/share/kube-virt/manifests/testing/disks-images-provider.yaml");

    my $hostname = script_output('hostname');
    assert_script_run("curl -JLO https://github.com/kubevirt/kubevirt/releases/download/v${kubevirt_ver}/local-block-storage.yaml");
    assert_script_run("sed -i 's/node01/$hostname/g' local-block-storage.yaml");
    assert_script_run("kubectl apply -f local-block-storage.yaml");

    assert_script_run("kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml");
    assert_script_run("kubectl -n local-path-storage wait deployment/local-path-provisioner --for condition=available --timeout=15m", timeout => 900);

    # Check if the local block device is available
    script_retry('losetup /dev/loop0', retry => 8, delay => 20, timeout => 180);

    record_info('List host images', script_output('ls /tmp/hostImages/ -l -R'));
    record_info('List local storage', script_output('ls /mnt/local-storage -R -l'));
    record_info('Check the loop device "loop0"', script_output('losetup /dev/loop0'));
    record_info('Check all loop devices', script_output('losetup -l -a'));
}

sub run_virt_tests {
    my $self = shift;
    my $test_conf;
    my @kubevirt_tests;
    my $test_suite_config = '/usr/share/kube-virt/manifests/testing/default-config.json';

    record_info('Run kubevirt tests', '');
    transactional::enter_trup_shell(global_options => '--drop-if-no-change') if (is_transactional);

    record_info('Set local storage class', '');
    assert_script_run("sed -i '/storageClassLocal/s/local/local-path/' $test_suite_config");

    if (is_transactional) {
        # Install required packages perl-CPAN-Changes and ant-junit
        $self->install_additional_pkgs();
    } else {
        zypper_call('in ant-junit') if (script_run('rpmquery ant-junit'));
    }

    # Ensure Config::Tiny module installed
    assert_script_run('cpan install Config::Tiny <<<yes', timeout => 300) if (script_run('cpan -l <<<yes | grep Config::Tiny') == 1);

    transactional::exit_trup_shell_and_reboot() if (is_transactional);

    my $result_dir = '/tmp/artifacts';
    record_info('Create artifacts path', $result_dir);
    assert_script_run("mkdir -p $result_dir");

    # Run virt-tests command for each go test files
    if (check_var('KUBEVIRT_TEST', 'full')) {
        $test_conf = 'full-tests.conf';
        @kubevirt_tests = @full_tests;
    } elsif (check_var('KUBEVIRT_TEST', 'core')) {
        $test_conf = 'core-tests.conf';
        @kubevirt_tests = @core_tests;
    }
    my $parser_script = 'config_parser.pl';
    assert_script_run("curl " . data_url("virt_autotest/kubevirt_tests/$test_conf") . " -o $test_conf");
    assert_script_run("curl " . data_url("virt_autotest/kubevirt_tests/$parser_script") . " -o $parser_script");

    my ($go_test, $skip_test, $extra_opt, $params);
    my ($artifacts, $junit_xml, $test_log, $test_cmd, $num_of_skipped);
    my $retry_times = get_var('FAILED_RETRY');

    # Workaround for bsc#1199448
    my $node_helper = 'node-helper.yaml';
    assert_script_run("curl " . data_url("virt_autotest/kubevirt_tests/$node_helper") . " -o $node_helper");
    assert_script_run("kubectl apply -f $node_helper");

    my $ginkgo_focus = get_var('GINKGO_FOCUS');
    if ($ginkgo_focus) {
        my $ginkgo_skip = get_var('GINKGO_SKIP');
        my $extra_opt = get_var('EXTRA_OPT');

        $ginkgo_skip = "|$ginkgo_skip" if (defined($ginkgo_skip));
        record_info('specific_test', $ginkgo_focus);
        $result_dir = "$result_dir/specific_test";
        assert_script_run("mkdir -p $result_dir");

        $junit_xml = "$result_dir/specific_test.xml";
        $test_log = "$result_dir/specific_test.log";
        $test_cmd = "virt-tests -ginkgo.regexScansFilePath=true " .
          "-ginkgo.focus='$ginkgo_focus' " .
          "-ginkgo.skip='QUARANTINE$ginkgo_skip' " .
          "-ginkgo.slowSpecThreshold 60 " .
          "-kubeconfig=/root/.kube/config " .
          "-kubectl-path=`which kubectl` " .
          "-virtctl-path=`which virtctl` " .
          "-installed-namespace=kubevirt " .
          "-deploy-testing-infra=false " .
          "-config=$test_suite_config " .
          "-dns-service-name=rke2-coredns-rke2-coredns " .
          "-ginkgo.v=true -test.v=true -ginkgo.trace=true " .
          "-ginkgo.noisySkippings=false -ginkgo.progress=true " .
          "-ginkgo.noColor -apply-default-e2e-configuration " .
          "$extra_opt " .
          "-artifacts=$result_dir " .
          "-junit-output=$junit_xml " .
          "2>&1 | tee $test_log";

        script_run($test_cmd, timeout => 7200);
        send_key 'ctrl-c';
        save_screenshot;
        $if_case_fail = 1 if (script_output("tail -1 $test_log") eq 'FAIL');
    } else {
        foreach my $section (@kubevirt_tests) {
            $go_test = '';
            $skip_test = '';
            $extra_opt = '';
            $params = script_output("perl $parser_script $test_conf $section");
            ($go_test, $skip_test, $extra_opt) = split(',', $params);
            record_info($section, join("\n", $go_test, $skip_test, $extra_opt));

            if ($section eq 'operator_test') {
                my $pre_rel_registry = get_required_var('PREVIOUS_RELEASE_REGISTRY');
                my $pre_rel_tag = get_required_var('PREVIOUS_RELEASE_TAG');
                $extra_opt =~ s/PREVIOUS_RELEASE_REGISTRY/$pre_rel_registry/;
                $extra_opt =~ s/PREVIOUS_RELEASE_TAG/$pre_rel_tag/;
            }

            $artifacts = "$result_dir/$section";
            $junit_xml = "$result_dir/${section}.xml";
            $test_log = "$result_dir/${section}.log";
            $test_cmd = "virt-tests -ginkgo.regexScansFilePath=true " .
              "-ginkgo.focus='$go_test' " .
              "-ginkgo.skip='QUARANTINE$skip_test' " .
              "-ginkgo.slowSpecThreshold 60 " .
              "-kubeconfig=/root/.kube/config " .
              "-kubectl-path=`which kubectl` " .
              "-virtctl-path=`which virtctl` " .
              "-installed-namespace=kubevirt " .
              "-deploy-testing-infra=false " .
              "-config=$test_suite_config " .
              "-dns-service-name=rke2-coredns-rke2-coredns " .
              "-ginkgo.v=true -test.v=true -ginkgo.trace=true " .
              "-ginkgo.noisySkippings=false -ginkgo.progress=true " .
              "-ginkgo.noColor -apply-default-e2e-configuration " .
              "$extra_opt " .
              "-artifacts=$artifacts " .
              "-junit-output=$junit_xml " .
              "2>&1 | tee $test_log";

            $retry_times = 1 unless ($retry_times);
            my $n_runs = 1;
            while ($n_runs <= $retry_times) {
                record_info("Run count: $n_runs", '');
                script_run($test_cmd, timeout => 7200);
                send_key 'ctrl-c';
                save_screenshot;
                last if (script_output("tail -1 $test_log") eq 'PASS');
                $n_runs++;
            }
            send_key 'ctrl-c';
            assert_script_run("sed -i 's/Tests Suite/$section/g' $junit_xml");
            $if_case_fail = 1 if (script_output("tail -1 $test_log") eq 'FAIL');
        }
    }

    $self->generate_test_report($result_dir);
    $self->upload_test_results($result_dir);
}

sub generate_test_report {
    my ($self, $result_dir) = @_;

    my $build_xml = "/tmp/buildTestReports.xml";
    my $html_dir = "$result_dir/html";

    record_info('Generate test report', '');
    script_run("cat > $build_xml <<__END
<project name=\"genTestReport\" default=\"gen\" basedir=\"$result_dir\">
    <description>
        Generate the HTML report from JUnit XML files
    </description>
    <target name=\"gen\">
        <property name=\"genReportDir\" location=\"$result_dir\"/>
        <delete dir=\"$html_dir\"/>
        <mkdir dir=\"$html_dir\"/>
        <junitreport todir=\"$result_dir\">
            <fileset dir=\"$result_dir\">
                <include name=\"*_test.xml\" />
            </fileset>
            <report format=\"frames\" todir=\"$html_dir\" />
        </junitreport>
    </target>
</project>
__END
true");

    # Generate JUnit HTML aggregate test reports
    script_run("ant -buildfile $build_xml");
}

sub upload_test_results {
    my ($self, $result_dir) = @_;

    my $test_artifacts = "/tmp/test_result_artifacts.tar.gz";
    my $html_dir = "$result_dir/html";

    record_info('Upload results', '');
    assert_script_run("rm -f $test_artifacts") if (!script_run("ls $test_artifacts"));

    if (!script_run("ls $result_dir")) {
        # Compress test artifacts & logs as a tarball and upload to openqa job logs & assets
        assert_script_run("tar czvf $test_artifacts $result_dir");
        upload_logs($test_artifacts, log_name => basename($test_artifacts));

        my @log_files = split(/\n/, script_output("ls $result_dir | grep .log"));
        upload_logs("$result_dir/$_", log_name => "$_") foreach @log_files;

        my @html_files = split(/\n/, script_output("ls -1 -F $html_dir"));
        my ($orig_filename, $new_filename);
        foreach (@html_files) {
            # Workaround for the uploaded file name with space
            if ($_ =~ /\s+/) {
                $orig_filename = $_;
                $_ =~ s/\s+/_/g;
                $new_filename = $_;
                assert_script_run("mv '$html_dir/$orig_filename' $html_dir/$_");
                assert_script_run("sed -i 's/$orig_filename/$new_filename/g' $html_dir/*");
            }
            upload_logs("$html_dir/$_", log_name => "$_");
        }

        my $openqa_host = get_var('OPENQA_URL');
        my $job_id = get_current_job_id();
        record_info('HTML report URL', "http://$openqa_host/tests/$job_id/file/index.html");
    }
}

sub post_fail_hook {
    my $self = shift;

    select_console 'log-console';
    save_and_upload_log('dmesg', '/tmp/dmesg.log', {screenshot => 0});
    save_and_upload_log('systemctl list-units -l', '/tmp/systemd_units.log', {screenshot => 0});
    save_and_upload_systemd_unit_log('rke2-server.service');
}

1;
