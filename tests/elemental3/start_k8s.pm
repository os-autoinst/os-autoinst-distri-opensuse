# Copyright 2023-2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test installation and boot of Elemental OS image.
#
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use Mojo::Base 'opensusebasetest';
use testapi;
use lockapi;
use elemental3;
use serial_terminal qw(select_serial_terminal);
use utils qw(file_content_replace);
use Mojo::File qw(path);
use Carp qw(croak);

=head2 prepare_test_framework

 prepare_test_framework( arch => <value>, k8s => <value> );

Prepare for K8s tests to be done with ECM's distro-test-framework.
It can be executed on different architectures and K8s distributions.

=cut

sub prepare_test_framework {
    my (%args) = @_;
    my $hostname = script_output('hostnamectl hostname');

    croak('Arch should be defined!') unless (defined $args{arch} && $args{arch} ne '');
    croak('K8s should be defined!') unless (defined $args{k8s} && $args{k8s} ne '');

    # Define architecture
    my $arch;
    $arch = 'arm' if ($args{arch} eq 'aarch64');
    $arch = 'amd64' if ($args{arch} eq 'x86_64');

    # Only needed on first master node
    if ($hostname eq 'node01') {
        # Get some informations from the cluster
        my ($k8s_version) = script_output('kubectl version') =~ /[Ss]erver.*:\s*(.*)/;
        my $k8s_yaml = "/etc/rancher/$args{k8s}/$args{k8s}.yaml";

        # We have to use this dirty workaround, as the result of this command
        # is way too big for 'file_content_replace' function
        assert_script_run("sed 's/127\.0\.0\.1/$hostname/g' $k8s_yaml | base64 -w0 > /tmp/k8s.config");

        # Get number of nodes
        my $nb_server_nodes = script_output('kubectl get nodes --no-headers | wc -l');
        my $nb_worker_nodes = script_output(
            q@kubectl get nodes --no-headers | awk 'BEGIN {N=0} $3=="agent" {N++} END {print N}'@
        );
        $nb_server_nodes -= $nb_worker_nodes;

        # Framework configuration files
        foreach my $file ('/tmp/env', '/tmp/tfvars') {
            assert_script_run(
                "curl -sf -o $file "
                  . data_url('elemental3/test-framework/' . path($file)->basename)
            );
            file_content_replace(
                $file, '--sed-modifier' => 'g',
                '%ARCH%' => $arch,
                '%ACCESS_KEY%' => '/root/.ssh/id_rsa',
                '%FQDN%' => $hostname,
                '%K8S%' => $args{k8s},
                '%K8S_VERSION%' => $k8s_version,
                '%NB_SERVER_NODES%' => $nb_server_nodes,
                '%NB_WORKER_NODES%' => $nb_worker_nodes
            );

            # Dirty workaround, see above for more details
            assert_script_run("sed -E \"s|%K8S_CONFIG%|\$(</tmp/k8s.config)|\" -i $file");
        }
    }

    # Tells the master that it can download the files
    barrier_wait('FILES_READY');

    # mutex_lock/unlock are used to avoid a sporadic crash with
    #  next 'barrier_wait' when master stopped too quickly
    mutex_lock('wait_nodes') if ($hostname eq 'node01');

    # Wait for tests to be executed on master node
    barrier_wait('TEST_FRAMEWORK_DONE');
    mutex_unlock('wait_nodes') if ($hostname eq 'node01');
}

sub run {
    my ($self) = @_;
    my $arch = get_required_var('ARCH');
    my $k8s = get_required_var('K8S');
    my $k8s_dir = "/etc/rancher/$k8s";
    my $timeout = 2400;    # Will be adapted when we will have more successful tests

    # Skip the test with if the OS image is not generated with 'customize'
    unless (check_var('TESTED_CMD', 'customize')) {
        record_info('SKIP', 'Skip test - No K8s installed in basic container image');
        $self->result('skip');
        return;
    }

    # Set default root password
    $testapi::password = get_required_var('TEST_PASSWORD');

    # No GUI, easier and quicker to use the serial console
    select_serial_terminal();

    # Cannot be defined with the other variables, as we need terminal access
    my $hostname = get_var('HOSTNAME', script_output('hostnamectl hostname'));

    # Wait for K8s directory to appears
    wait_on_cmd(cmd => "test -d $k8s_dir", timeout => $timeout);

    # Record K8s configuration files
    record_info("$k8s_dir config files", "ls -l $k8s_dir; echo; cat $k8s_dir/*");

    # Wait for kubectl command to be available
    wait_kubectl_cmd(timeout => $timeout);

    unless ($hostname eq 'node04') {
        # Check K8s status
        wait_k8s_state(regex => 'status.*restarts|(1/1|2/2|3/3|4.4).*running|0/1.*completed', timeout => $timeout);

        # Record K8s status (we want all, stderr as well)
        record_info('K8s status', script_output('kubectl get pod -A 2>&1'));

        # Wait until node(s) is/are in Ready state
        wait_nodes_ready(timeout => $timeout);

        # Record K8s version/nodes
        record_info('K8s version/nodes', script_output('kubectl version; kubectl get nodes'));

        # Record K8s services
        record_info('K8s services', script_output('kubectl get services -A'));

        # Check toolkit version
        record_info('Elemental version', script_output('elemental3ctl version'));

        # Check that test namespace has been created
        kubectl_cmd(cmd => 'get namespace openqa-ns', timeout => $timeout);
        record_info('Test Namespace creation', 'Namespace created!');
    }

    # Only in single-node/multi-node tests
    prepare_test_framework(arch => $arch, k8s => $k8s)
      if (get_var('CLUSTER_TYPE') =~ /(singlenode|multinode)/);
}

sub post_fail_hook {
    my ($self) = @_;

    record_info(__PACKAGE__ . ':' . 'post_fail_hook');

    # Useful to debug K8s starting issues
    foreach my $svc ('k8s-resource-installer', 'k3s', 'rke2-server') {
        script_run("journalctl -xeu $svc.service > /tmp/${svc}_journal.log");
        upload_logs("/tmp/${svc}_journal.log", failok => 1);
    }

    # Execute the common part
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
