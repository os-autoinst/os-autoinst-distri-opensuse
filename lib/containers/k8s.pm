# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic functionality for testing kubernetes. Includes k3s tools
# Maintainer: qa-c team <qa-c@suse.de>


package containers::k8s;

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;
use utils qw(zypper_call script_retry file_content_replace validate_script_output_retry random_string);
use Utils::Systemd qw(systemctl);
use containers::utils 'registry_url';
use version_utils qw(is_sle is_microos is_public_cloud is_transactional is_alp is_sle_micro is_leap is_leap_micro);
use registration qw(add_suseconnect_product get_addon_fullname);
use transactional qw(trup_call check_reboot_changes);

our @EXPORT = qw(install_k3s uninstall_k3s install_kubectl install_helm install_oc apply_manifest wait_for_k8s_job_complete find_pods validate_pod_log);

sub check_k3s {
    record_info('k3s', "k3s version " . script_output("k3s --version") . " installed");
    record_info('kubectl version', script_output('k3s kubectl version'));
    assert_script_run('uname -a');
    assert_script_run('test -e /etc/rancher/k3s/k3s.yaml');
    assert_script_run('k3s check-config');
    validate_script_output('k3s kubectl config get-clusters', qr/default/);
    validate_script_output('k3s kubectl config get-users', qr/default/);
    validate_script_output('k3s kubectl config get-contexts --no-headers=true -o name', qr/default/);
    assert_script_run('k3s kubectl config view --raw');
    validate_script_output_retry("k3s kubectl get nodes", qr/ Ready.*control-plane,master /, retry => 6, delay => 15, timeout => 90);
    validate_script_output_retry("k3s kubectl get namespaces", qr/default.*Active/, timeout => 120, delay => 60, retry => 3);
    validate_script_output_retry('k3s kubectl get events -A', qr/Started container coredns/, retry => 6, delay => 30, timeout => 90);

    # the default service account should be ready by now
    assert_script_run("k3s kubectl get serviceaccount default -o name");
    # expect that k3s api to be ready and is accessible
    record_info("k3s api resources", script_output("k3s kubectl api-resources"));
    assert_script_run("k3s kubectl auth can-i 'create' 'pods'");
    assert_script_run("k3s kubectl auth can-i 'create' 'deployments'");
}

sub ensure_k3s_start {
    systemctl('start k3s');
    systemctl('is-active k3s');
}

sub set_custom_registry {
    return unless get_var('REGISTRY');

    script_run("mkdir -p /etc/rancher/k3s");
    my $registry = registry_url();
    assert_script_run "curl " . data_url('containers/registries.yaml') . " -o /etc/rancher/k3s/registries.yaml";
    file_content_replace("/etc/rancher/k3s/registries.yaml", REGISTRY => $registry);
}

sub setup_and_check_k3s {
    if (script_run('test -n "$INSTALL_K3S_SKIP_START"') == 0) {
        set_custom_registry;
        ensure_k3s_start;
    }
    script_run("rm -rf ~/.kube");
    script_run('mkdir -p ~/.kube/');
    assert_script_run('ln -s /etc/rancher/k3s/k3s.yaml ~/.kube/config');
    check_k3s;
}

=head2 install_k3s
Deploy k3s using k3s-install script that is either pulled from upstream or distro
=cut

sub install_k3s {
    # k3s might be already installed by default
    return if (script_run('which k3s') == 0);

    # Apply additional k3s installation options
    # Note: The install script starts a k3s-server by default, unless INSTALL_K3S_SKIP_START is set to true
    # For more information see https://rancher.com/docs/k3s/latest/en/installation/install-options/#options-for-installation-with-script
    my %k3s_args = (
        INSTALL_K3S_SYMLINK => get_var('K3S_SYMLINK'),
        INSTALL_K3S_BIN_DIR => get_var('K3S_BIN_DIR'),
        INSTALL_K3S_CHANNEL => get_var('K3S_CHANNEL'),
        INSTALL_K3S_VERSION => get_var('K3S_VERSION'),
        INSTALL_K3S_SKIP_START => get_var('K3S_SKIP_START', 'true'),
        K3S_NODE_NAME => 'k3s-node'
    );

    # github.com/k3s-io/k3s#5946 - The kubectl delete namespace helm-ns-413 command freezes and does nothing
    my $disables = '--disable=metrics-server';
    $disables .= ' --disable-helm-controller' unless (get_var('K3S_ENABLE_HELM_CONTROLLER'));

    while (my ($key, $value) = each %k3s_args) {
        if ($value) {
            assert_script_run("export $key=$value");
        }
        delete $k3s_args{$key};
    }

    if (get_var('K3S_INSTALL_UPSTREAM') || (is_sle || is_leap || is_sle_micro || is_leap_micro)) {
        script_retry("curl -sfL https://get.k3s.io  -o install_k3s.sh", timeout => 180, delay => 60, retry => 3);
        assert_script_run("sh install_k3s.sh $disables", timeout => 300);
        script_run("rm -f install_k3s.sh");
        zypper_call('in apparmor-parser') if is_sle('<15-SP4');
        setup_and_check_k3s;
        return;
    }

    # k3s-install script is already packaged for several products
    my @pkgs = qw(k3s-install);
    push @pkgs, 'apparmor-parser' if is_sle('<15-SP4');

    if (script_run(sprintf('rpm -q %s', join(" ", @pkgs))) != 0) {
        if (is_transactional) {
            trup_call("pkg install @pkgs");
            check_reboot_changes;
        } else {
            zypper_call("in @pkgs");
        }
    }

    assert_script_run("k3s-install $disables");

    setup_and_check_k3s;
}


=head2 uninstall_k3s
Uninstalls k3s
=cut

sub uninstall_k3s {
    assert_script_run("rm -f ~/.kube/config");
    assert_script_run("/usr/local/bin/k3s-uninstall.sh");
}

=head2 install_kubectl
Installs kubectl from the respositories
=cut

sub install_kubectl {
    if (script_run("which kubectl") == 0) {
        record_info('kubectl preinstalled', script_output('kubectl version --client'));
        return;
    }

    # kubectl is in the container module
    add_suseconnect_product(get_addon_fullname('contm')) if (is_sle);
    my $k8s_pkg = get_var('K8S_CLIENT', 'kubernetes-client-provider');
    if (!get_var('K8S_CLIENT') && (is_sle || is_sle_micro)) {
        die '"K8S_CLIENT" was not set in test suite definition';
    }
    zypper_call("in -C $k8s_pkg");
    record_info('kubectl version', script_output('kubectl version --client'));
}

=head2 install_helm
Installs helm from our repositories
=cut

sub install_helm {
    zypper_call("in helm");
    record_info('helm', script_output("helm version"));
}

=head2 install_oc
Installs oc
=cut

sub install_oc {
    my $url = get_required_var('CONTAINER_OC_BINARY_URL');
    assert_script_run("wget --no-check-certificate $url");
    $url =~ m|([^/]+)/?$|;
    assert_script_run("tar zxvf $1");
    assert_script_run('mv oc /usr/local/bin');
    assert_script_run('oc');
}

=head2 apply_manifest
Apply a kubernetes manifest
=cut

sub apply_manifest {
    my ($manifest) = @_;

    my $path = sprintf('/tmp/%s.yml', random_string(32));

    script_output("echo -e '$manifest' > $path");
    upload_logs($path, failok => 1);

    assert_script_run("kubectl apply -f $path");
}

=head2 find_pods
Find pods using kubectl queries
=cut

sub wait_for_k8s_job_complete {
    my ($job) = @_;
    my $cmd = "kubectl wait --for=condition=complete --timeout=300s job/$job";
    script_retry($cmd, retry => 5, timeout => 360, die => 1);
}

=head2 wait_for_k8s_job_complete
Wait until the job is complete
=cut

sub find_pods {
    my ($query) = @_;
    return script_output("kubectl get pods --no-headers -l $query -o custom-columns=':metadata.name'");
}

=head2 validate_pod_logs
Validates that the logs contains a text
=cut

sub validate_pod_log {
    my ($pod, $text) = @_;
    validate_script_output("kubectl logs $pod 2>&1", qr/$text/, timeout => 180);
}

1;
