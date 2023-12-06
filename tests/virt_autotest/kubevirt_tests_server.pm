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

    record_info('RKE2 Server Setup', '');
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
    record_info('Installed certificates packages', script_output('rpm -qa | grep certificates'));

    $self->install_kubevirt_packages();

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
    systemctl('enable --now rke2-server.service', timeout => 180);
    $self->check_service_status();

    # Start rke2-server service ready
    barrier_wait('rke2_server_start_ready');
    record_info('Start RKE2 Server', '');

    assert_script_run('mkdir -p ~/.kube');
    assert_script_run('cp /etc/rancher/rke2/rke2.yaml ~/.kube/config');
    assert_script_run('kubectl config view');
    assert_script_run('kubectl get nodes');

    # Create registries ready
    our $local_registry_fqdn = get_required_var("LOCAL_REGISTRY_FQDN");
    our $local_registry_ip = script_output("nslookup $local_registry_fqdn|sed -n '5,1p'|awk -F' ' '{print \$2}'");
    assert_script_run("cat > /etc/rancher/rke2/registries.yaml <<__END
mirrors:
  $local_registry_fqdn:5000:
    endpoint:
      - http://$local_registry_fqdn:5000
  $local_registry_ip:5000:
    endpoint:
      - http://$local_registry_ip:5000
__END
(exit \$?)");

    # Wait for rke2-agent service to be ready
    my $children = get_children();
    mutex_wait('rke2_agent_start_ready', (keys %$children)[0]);

    assert_script_run("scp /etc/rancher/rke2/registries.yaml root\@$agent_ip:/etc/rancher/rke2/registries.yaml");

    # Workaround for bsc#1217658
    my $config_toml_tmpl = 'config.toml.tmpl';
    assert_script_run("curl " . data_url("virt_autotest/kubevirt_tests/$config_toml_tmpl") . " -o $config_toml_tmpl");
    assert_script_run("cp $config_toml_tmpl /var/lib/rancher/rke2/agent/etc/containerd/$config_toml_tmpl");

    # Restart RKE2 service and check the service is active well after restart
    systemctl('restart rke2-server.service', timeout => 180);
    $self->check_service_status();

    # Restart rke2-server service complete
    barrier_wait('rke2_server_restart_complete');
    record_info('Restart RKE2 Server', '');

    mutex_wait('rke2_agent_restart_complete', (keys %$children)[0]);

    script_retry('! kubectl get nodes | grep NotReady', retry => 14, delay => 20, timeout => 300);
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

    # Install Longhorn dependencies
    our $kubevirt_ver = script_output("rpm -q --qf \%{VERSION} kubevirt-tests");
    record_info('Kubevirt test version', $kubevirt_ver);
    zypper_call('in jq open-iscsi') if (script_run('rpmquery jq open-iscsi') && ($kubevirt_ver ge "0.50.0"));

    # Install required packages perl-CPAN-Changes and ant-junit
    if (is_transactional) {
        $self->install_additional_pkgs();
    } else {
        zypper_call('in git ant-junit') if (script_run('rpmquery git ant-junit'));
    }

    # Ensure Config::Tiny module installed
    assert_script_run('cpan install Config::Tiny <<<yes', timeout => 300) if (script_run('cpan -l <<<yes | grep Config::Tiny') == 1);

    transactional::exit_trup_shell_and_reboot() if (is_transactional);

    record_info('Installed kubevirt package version', script_output('rpm -qa |grep -E "containerized|kubevirt|virt-test"'));

    # Enable iscsid service
    systemctl('enable --now iscsid', timeout => 180) if ($kubevirt_ver ge "0.50.0");

    # Install kubevirt packages complete
    barrier_wait('kubevirt_packages_install_complete');
}

sub deploy_kubevirt_manifests {
    my $self = shift;
    our $kubevirt_ver;

    # Deploy required kubevirt manifests
    record_info('Deploy kubevirt manifests', '');
    assert_script_run("kubectl apply -f /usr/share/cdi/manifests/release/cdi-operator.yaml");
    assert_script_run("kubectl apply -f /usr/share/cdi/manifests/release/cdi-cr.yaml");
    assert_script_run("kubectl -n cdi wait cdis cdi --for condition=available --timeout=30m", timeout => 1800);

    assert_script_run("kubectl apply -f /usr/share/kube-virt/manifests/release/kubevirt-operator.yaml");
    assert_script_run("kubectl apply -f /usr/share/kube-virt/manifests/release/kubevirt-cr.yaml");
    assert_script_run("kubectl -n kubevirt wait kv kubevirt --for condition=available --timeout=30m", timeout => 1800);

    # Workaround for failure 'MountVolume.SetUp failed for volume "local-storage" : mkdir /mnt/local-storage: read-only file system'
    assert_script_run('mkdir -p /root/tmp && mount -o bind /root/tmp /mnt') if (is_transactional);
    # Check all loop devices to see if they refer to deleted files
    record_info('Check all loop devices', script_output('losetup -a -l'));
    # Detach all loop devices, the disk-image-provider needs to use it to setup images
    record_info('Detach all loop devices', script_output('losetup -D'));
    # Remove existing local disks
    record_info('Remove existing local disks', script_output('[ -d /tmp/hostImages -a -d /mnt/local-storage ] && rm -r /tmp/hostImages /mnt/local-storage', proceed_on_failure => 1));

    assert_script_run("kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v${kubevirt_ver}/rbac-for-testing.yaml");
    assert_script_run("kubectl apply -f /usr/share/kube-virt/manifests/testing/disks-images-provider.yaml");

    if ($kubevirt_ver lt "0.50.0") {
        my $hostname = script_output('hostname');
        assert_script_run("curl -JLO https://github.com/kubevirt/kubevirt/releases/download/v${kubevirt_ver}/local-block-storage.yaml");
        assert_script_run("sed -i 's/node01/$hostname/g' local-block-storage.yaml");
        assert_script_run("kubectl apply -f local-block-storage.yaml");
    }
    else {
        $self->setup_longhorn_csi();
    }

    assert_script_run("kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml");
    assert_script_run("kubectl -n local-path-storage wait deployment/local-path-provisioner --for condition=available --timeout=15m", timeout => 900);

    # Check if the local block device is available
    script_retry('losetup /dev/loop0', retry => 8, delay => 20, timeout => 180);

    record_info('List host images', script_output('ls /tmp/hostImages/ -l -R'));
    record_info('List local storage', script_output('ls /mnt/local-storage -R -l'));
    record_info('Check the loop device "loop0"', script_output('losetup /dev/loop0'));
    record_info('Check all loop devices', script_output('losetup -l -a'));

    $self->apply_test_config();
}

sub setup_longhorn_csi {
    my $self = shift;

    record_info('Install Longhorn CSI', '');

    # Install Longhorn CSI
    my $longhorn_ver = get_var('LONGHORN_VERSION');
    assert_script_run("kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v$longhorn_ver/deploy/longhorn.yaml");

    # Ensure successful Longhorn deployment
    my @deployments = split(/\n/, script_output("kubectl get --no-headers deployments -n longhorn-system -o custom-columns=:.metadata.name"));
    assert_script_run("kubectl rollout status deployment --timeout=20m -n longhorn-system $_") foreach (@deployments);
    my @daemonsets = split(/\n/, script_output("kubectl get --no-headers daemonsets -n longhorn-system -o custom-columns=:.metadata.name"));
    assert_script_run("kubectl rollout status daemonset --timeout=40m -n longhorn-system $_") foreach (@daemonsets);

    # Adjust Longhorn settings (lhs)
    script_retry('kubectl get -n longhorn-system lhs', retry => 8, delay => 10, timeout => 90);
    assert_script_run(qq(kubectl patch -n longhorn-system lhs storage-minimal-available-percentage --type merge -p '{"value": "5"}'));

    # Create storage classes
    assert_script_run("kubectl apply -f https://gitlab.suse.de/virtualization/kubevirt-ci/-/raw/main/storage/longhorn-sc.yaml");

    # Ensure only one default storage class exists
    assert_script_run(qq(kubectl patch storageclass longhorn-default -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'));
    assert_script_run("kubectl delete --ignore-not-found configmaps -n longhorn-system longhorn-storageclass");
    assert_script_run("kubectl delete --ignore-not-found storageclass longhorn");

    # Update storage profiles (give CDI some time to reconcile)
    script_retry('kubectl get StorageProfile longhorn-default longhorn-migratable longhorn-wffc', retry => 8, delay => 10, timeout => 90);
    assert_script_run("curl -kJLO https://gitlab.suse.de/virtualization/kubevirt-ci/-/raw/main/storage/longhorn-sp-patch.yaml");
    assert_script_run("kubectl patch StorageProfile longhorn-default --type merge --patch-file longhorn-sp-patch.yaml");
    assert_script_run("kubectl patch StorageProfile longhorn-migratable --type merge --patch-file longhorn-sp-patch.yaml");
    assert_script_run(qq(kubectl patch StorageProfile longhorn-wffc --type merge -p '{"spec": {"claimPropertySets": [{"accessModes": ["ReadWriteOnce"]}]}}'));

    # Enable snapshots support
    my @crd = (
        'snapshot.storage.k8s.io_volumesnapshotclasses.yaml',
        'snapshot.storage.k8s.io_volumesnapshotcontents.yaml',
        'snapshot.storage.k8s.io_volumesnapshots.yaml'
    );
    assert_script_run("kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.0/client/config/crd/$_") foreach (@crd);

    my @snapshot_controller = (
        'rbac-snapshot-controller.yaml',
        'setup-snapshot-controller.yaml'
    );
    assert_script_run("kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.0/deploy/kubernetes/snapshot-controller/$_") foreach (@snapshot_controller);

    # Create a backup target
    assert_script_run("kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v$longhorn_ver/deploy/backupstores/nfs-backupstore.yaml");

    # Set backup target URL to nfs://longhorn-test-nfs-svc.default:/opt/backupstore
    assert_script_run(qq(kubectl patch -n longhorn-system lhs backup-target --type merge -p '{"value": "nfs://longhorn-test-nfs-svc.default:/opt/backupstore"}'));

    # Add a default VolumeSnapshotClass
    assert_script_run("kubectl apply -f - <<EOF
kind: VolumeSnapshotClass
apiVersion: snapshot.storage.k8s.io/v1
metadata:
  name: longhorn-default
driver: driver.longhorn.io
deletionPolicy: Delete
parameters:
    type: snap
EOF
(exit \$?)");

    # Setup access to Longhorn UI (useful for debugging)
    assert_script_run("curl -kJLO https://gitlab.suse.de/virtualization/kubevirt-ci/-/raw/main/storage/longhorn-auth");
    assert_script_run("kubectl -n longhorn-system create secret generic basic-auth --from-file=auth=longhorn-auth || true");
    assert_script_run("kubectl -n longhorn-system apply -f https://gitlab.suse.de/virtualization/kubevirt-ci/-/raw/main/storage/longhorn-ingress.yaml");
}

sub apply_test_config {
    my $self = shift;

    record_info('Apply test config', '');

    # bsc#1210696, 1210863
    our $local_registry_fqdn;
    our $local_registry_ip;
    assert_script_run("cat > 1210696_1210863.yaml <<EOF
spec:
  config:
    dataVolumeTTLSeconds: -1
    featureGates:
    - HonorWaitForFirstConsumer
    insecureRegistries:
    - registry:5000
    - fakeregistry:5000
    - $local_registry_fqdn:5000
    - $local_registry_ip:5000
    uploadProxyURLOverride: https://127.0.0.1:31001
EOF
(exit \$?)");
    assert_script_run("kubectl patch cdi cdi --type merge --patch-file 1210696_1210863.yaml");

    # bsc#1210856
    assert_script_run("mkdir -p /var/provision/kubevirt.io/tests && mount -t tmpfs tmpfs /var/provision/kubevirt.io/tests");
    assert_script_run("echo 'tmpfs /var/provision/kubevirt.io/tests tmpfs rw 0 0' >> /etc/fstab");

    # bsc#1210884
    assert_script_run(qq(kubectl -n kubevirt patch kubevirt kubevirt --type merge --patch '{"spec": {"configuration": {"developerConfiguration": {"pvcTolerateLessSpaceUpToPercent": 30}}}}'));

    # bsc#1210906
    assert_script_run("sysctl -w vm.unprivileged_userfaultfd=1");
    # Installing Whereabouts plugin
    assert_script_run("git clone https://github.com/k8snetworkplumbingwg/whereabouts && cd whereabouts", 600);
    assert_script_run("kubectl apply -f doc/crds/daemonset-install.yaml " .
          "-f doc/crds/whereabouts.cni.cncf.io_ippools.yaml " .
          "-f doc/crds/whereabouts.cni.cncf.io_overlappingrangeipreservations.yaml && cd");
}

sub run_virt_tests {
    my $self = shift;
    my $test_suite_conf;
    my $test_scope_conf;
    my @kubevirt_tests;
    our $kubevirt_ver;

    record_info('Run kubevirt tests', $kubevirt_ver);

    # Create a valid config for the test suite
    # Default testing config path: /usr/share/kube-virt/manifests/testing/default-config.json
    if ($kubevirt_ver lt "0.50.0") {
        $test_suite_conf = '/tmp/local-config.json';
        assert_script_run(qq(cat > $test_suite_conf <<EOF
{
    "storageClassLocal":       "local-path",
    "storageClassHostPath":    "host-path",
    "storageClassHostPathSeparateDevice":    "host-path-sd",
    "storageClassBlockVolume": "block-volume",
    "storageClassRhel":        "rhel",
    "storageClassWindows":     "windows",
    "manageStorageClasses":     true
}
EOF
(exit \$?)));
    } else {
        $test_suite_conf = '/tmp/longhorn-config.json';
        assert_script_run(qq(cat > $test_suite_conf <<EOF
{
    "storageClassRhel":        "longhorn-default",
    "storageClassWindows":     "longhorn-default",
    "storageRWXFileSystem":    "longhorn-default",
    "storageRWXBlock":         "longhorn-migratable",
    "storageRWOFileSystem":    "longhorn-wffc",
    "storageRWOBlock":         "longhorn-migratable",
    "storageSnapshot":         "longhorn-default"
}
EOF
(exit \$?)));
    }

    my $result_dir = '/tmp/artifacts';
    record_info('Create artifacts path', $result_dir);
    assert_script_run("mkdir -p $result_dir");

    # Run virt-tests command for each go test files
    if (check_var('KUBEVIRT_TEST', 'full')) {
        $test_scope_conf = 'full-tests.conf';
        @kubevirt_tests = @full_tests;
    } elsif (check_var('KUBEVIRT_TEST', 'core')) {
        $test_scope_conf = 'core-tests.conf';
        @kubevirt_tests = @core_tests;
    }
    my $parser_script = 'config_parser.pl';
    assert_script_run("curl " . data_url("virt_autotest/kubevirt_tests/$test_scope_conf") . " -o $test_scope_conf");
    assert_script_run("curl " . data_url("virt_autotest/kubevirt_tests/$parser_script") . " -o $parser_script");

    my ($ginkgo_focus, $ginkgo_skip, $extra_opt, $specific_test, $ginkgo_v2);
    my ($go_test, $skip_test, $params, $server_ip, $nic_name);
    my ($artifacts, $junit_xml, $test_log, $test_cmd, $num_of_skipped);
    my $retry_times = get_var('FAILED_RETRY');

    # Workaround for bsc#1199448
    my $node_helper = 'node-helper.yaml';
    assert_script_run("curl " . data_url("virt_autotest/kubevirt_tests/$node_helper") . " -o $node_helper");
    assert_script_run("sed -e \"s/$kubevirt_ver/\${KUBEVIRT_VERSION}/g\"");
    assert_script_run("kubectl apply -f $node_helper");
    assert_script_run("kubectl -n kubevirt-tests rollout status daemonset node-helper --timeout=50m");

    my $pre_rel_reg = get_required_var('PREVIOUS_RELEASE_REGISTRY');
    my $pre_rel_tag = get_required_var('PREVIOUS_RELEASE_TAG');
    my $additional_reg_tag = "-previous-release-registry=$pre_rel_reg -previous-release-tag=$pre_rel_tag";

    our $local_registry_fqdn;
    my ($container_prefix, $container_tag, $pre_util_container_reg, $pre_util_container_tag);
    if ($kubevirt_ver ge "0.50.0") {
        $container_prefix = "$local_registry_fqdn:5000";
        $container_tag = get_required_var('CONTAINER_TAG');
        $pre_util_container_reg = "$local_registry_fqdn:5000";
        $pre_util_container_tag = get_required_var('PREVIOUS_UTILITY_CONTAINER_TAG');
        $additional_reg_tag = "$additional_reg_tag " .
          "-container-prefix=$container_prefix -container-tag=$container_tag " .
          "-previous-utility-container-registry=$pre_util_container_reg " .
          "-previous-utility-container-tag=$pre_util_container_tag";
    }

    $ginkgo_focus = get_var('GINKGO_FOCUS');
    if ($ginkgo_focus) {
        $ginkgo_skip = get_var('GINKGO_SKIP');
        $extra_opt = get_var('EXTRA_OPT');
        $specific_test = 'test' . int(rand(999));

        $ginkgo_skip = "|$ginkgo_skip" if (defined($ginkgo_skip));
        record_info($specific_test, $ginkgo_focus);
        $result_dir = "$result_dir/$specific_test";
        assert_script_run("mkdir -p $result_dir");

        $junit_xml = "$result_dir/$specific_test.xml";
        $test_log = "$result_dir/$specific_test.log";

        if ($kubevirt_ver lt "1.0.0") {
            $ginkgo_v2 = "--ginkgo.focus='$ginkgo_focus' " .
              "--ginkgo.skip='QUARANTINE$ginkgo_skip' " .
              "--ginkgo.slow-spec-threshold 60s " .
              "--ginkgo.v=true --ginkgo.trace=true " .
              "--ginkgo.progress=true";
        } else {
            $ginkgo_v2 = "--ginkgo.focus='$ginkgo_focus' " .
              "--ginkgo.skip='QUARANTINE$ginkgo_skip' " .
              "--ginkgo.poll-progress-after 60s " .
              "--ginkgo.v=true --ginkgo.trace=true " .
              "--ginkgo.show-node-events";
        }

        $test_cmd = "virt-tests $ginkgo_v2 -kubeconfig=/root/.kube/config " .
          "-kubectl-path=`which kubectl` -virtctl-path=`which virtctl` " .
          "-installed-namespace=kubevirt -deploy-testing-infra=false " .
          "-config=$test_suite_conf -dns-service-name=rke2-coredns-rke2-coredns " .
          "$extra_opt $additional_reg_tag " .
          "-test.v=true -apply-default-e2e-configuration " .
          "-artifacts=$artifacts -junit-output=$junit_xml " .
          "2>&1 | tee $test_log";

        record_info("Run test cmd", $test_cmd);
        script_run($test_cmd, timeout => 7200);
        send_key 'ctrl-c';
        save_screenshot;
        $if_case_fail = 1 if (script_output("tail -1 $test_log") eq 'FAIL');
    } else {
        foreach my $section (@kubevirt_tests) {
            $go_test = '';
            $skip_test = '';
            $extra_opt = '';
            $params = script_output("perl $parser_script $test_scope_conf $section");
            ($go_test, $skip_test, $extra_opt) = split(',', $params);
            record_info($section, join("\n", $go_test, $skip_test, $extra_opt));

            if ($section eq 'migration_test') {
                assert_script_run("kubectl delete net-attach-def migration-cni -n kubevirt") if (!script_run("kubectl get net-attach-def -A | grep migration-cni"));
                $server_ip = get_required_var('SERVER_IP');
                $nic_name = script_output("ip addr | grep $server_ip | awk -F' ' '{print \$NF}'");
                $extra_opt = "-migration-network-nic=$nic_name";
            }

            $artifacts = "$result_dir/$section";
            $junit_xml = "$result_dir/${section}.xml";
            $test_log = "$result_dir/${section}.log";

            if ($go_test =~ /\.go$/) {
                $ginkgo_focus = "--ginkgo.focus-file='$go_test' ";
            } else {
                $ginkgo_focus = "--ginkgo.focus='$go_test' ";
            }

            if ($kubevirt_ver lt "1.0.0") {
                $ginkgo_v2 = $ginkgo_focus .
                  "--ginkgo.skip='QUARANTINE$skip_test' " .
                  "--ginkgo.slow-spec-threshold 60s " .
                  "--ginkgo.v=true --ginkgo.trace=true " .
                  "--ginkgo.progress=true " .
                  "--ginkgo.timeout=24h";
            } else {
                $ginkgo_v2 = $ginkgo_focus .
                  "--ginkgo.skip='QUARANTINE$skip_test' " .
                  "--ginkgo.poll-progress-after 60s " .
                  "--ginkgo.v=true --ginkgo.trace=true " .
                  "--ginkgo.show-node-events " .
                  "--ginkgo.timeout=24h";
            }

            $test_cmd = "virt-tests $ginkgo_v2 -kubeconfig=/root/.kube/config " .
              "-kubectl-path=`which kubectl` -virtctl-path=`which virtctl` " .
              "-installed-namespace=kubevirt -deploy-testing-infra=false " .
              "-config=$test_suite_conf -dns-service-name=rke2-coredns-rke2-coredns " .
              "$extra_opt $additional_reg_tag " .
              "-test.v=true -apply-default-e2e-configuration " .
              "-artifacts=$artifacts -junit-output=$junit_xml " .
              "2>&1 | tee $test_log";

            $retry_times = 1 unless ($retry_times);
            my $n_runs = 1;
            while ($n_runs <= $retry_times) {
                record_info("Run count: $n_runs", $test_cmd);
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
    assert_script_run(qq(cat > $build_xml <<__END
<project name="genTestReport" default="gen" basedir="$result_dir">
    <description>
        Generate the HTML report from JUnit XML files
    </description>
    <target name="gen">
        <property name="genReportDir" location="$result_dir"/>
        <delete dir="$html_dir"/>
        <mkdir dir="$html_dir"/>
        <junitreport todir="$result_dir">
            <fileset dir="$result_dir">
                <include name="*_test.xml" />
            </fileset>
            <report format="frames" todir="$html_dir" />
        </junitreport>
    </target>
</project>
__END
(exit \$?)));

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
