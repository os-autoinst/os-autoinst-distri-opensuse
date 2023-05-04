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
use version_utils qw(is_sle is_microos is_public_cloud);
use registration qw(add_suseconnect_product get_addon_fullname);
use transactional qw(trup_call check_reboot_changes);

our @EXPORT = qw(install_k3s uninstall_k3s install_kubectl install_helm install_oc apply_manifest wait_for_k8s_job_complete find_pods validate_pod_log);

=head2 install_k3s
Installs k3s, checks the instalation and prepare the kube/config
=cut

sub install_k3s {
    if (get_var("DISTRI") eq "alp") {
        assert_script_run('/usr/bin/k3s-install');
    }
    else {
        if (is_microos()) {
            trup_call('pkg install k3s-selinux');
            check_reboot_changes;
        }
        zypper_call('in apparmor-parser') if (is_sle('>=15-sp1'));
  # Apply additional options. For more information see https://rancher.com/docs/k3s/latest/en/installation/install-options/#options-for-installation-with-script
        my $k3s_version = get_var("CONTAINERS_K3S_VERSION");
        if ($k3s_version) {
            record_info('k3s forced version', $k3s_version);
            assert_script_run("export INSTALL_K3S_VERSION=$k3s_version");
        }
        assert_script_run("export INSTALL_K3S_SYMLINK=" . get_var('K3S_SYMLINK')) if (get_var('K3S_SYMLINK'));
        assert_script_run("export INSTALL_K3S_BIN_DIR=" . get_var('K3S_BIN_DIR')) if (get_var('K3S_BIN_DIR'));
        assert_script_run("export INSTALL_K3S_CHANNEL=" . get_var('K3S_CHANNEL')) if (get_var('K3S_CHANNEL'));
        # k3s doesn't like long hostnames like the ones being used in publiccloud
        assert_script_run("export K3S_NODE_NAME=k3s-node") if (is_public_cloud);

        # github.com/k3s-io/k3s#5946 - The kubectl delete namespace helm-ns-413 command freezes and does nothing
        # Note: The install script starts a k3s-server by default, unless INSTALL_K3S_SKIP_START is set to true
        script_retry("curl -sfL https://get.k3s.io  -o install_k3s.sh", timeout => 180, delay => 60, retry => 3);
        assert_script_run("INSTALL_K3S_SKIP_START=true sh install_k3s.sh --disable=metrics-server", timeout => 180);
        script_run("rm -f install_k3s.sh");
    }

    if (get_var('REGISTRY')) {
        script_run("mkdir -p /etc/rancher/k3s");
        my $registry = registry_url();
        assert_script_run "curl " . data_url('containers/registries.yaml') . " -o /etc/rancher/k3s/registries.yaml";
        file_content_replace("/etc/rancher/k3s/registries.yaml", REGISTRY => $registry);
    }
    systemctl('start k3s');
    script_retry("test -e /etc/rancher/k3s/k3s.yaml", delay => 20, retry => 10);
    systemctl('is-active k3s');
    assert_script_run('k3s -v');
    assert_script_run('uname -a');
    assert_script_run("k3s kubectl get node");
    validate_script_output_retry("k3s kubectl get node", qr/ Ready /, retry => 6, delay => 15, timeout => 90);
    script_run("mkdir -p ~/.kube");
    script_run("rm -f ~/.kube/config");
    assert_script_run("ln -s /etc/rancher/k3s/k3s.yaml ~/.kube/config");
    sleep 60;
    # Await k3s to be ready and exists the default service account
    script_retry("kubectl get serviceaccount default -o name", delay => 60, retry => 3);
    # Await k3s to be ready and the api is accessible
    script_retry("kubectl get namespaces", delay => 60, retry => 3);
    script_retry("kubectl get pods --all-namespaces | grep -E 'Running|Completed'", delay => 60, retry => 10);
    record_info("k3s api resources", script_output("kubectl api-resources"));
    assert_script_run("kubectl auth can-i 'create' 'pods'");
    assert_script_run("kubectl auth can-i 'create' 'deployments'");
    record_info('k3s', "k3s version " . script_output("k3s --version") . " installed");
    record_info('kubectl version', script_output('kubectl version --short'));
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
    if (script_run("which kubectl") != 0) {
        if (is_sle) {
            # kubectl is in the container module
            add_suseconnect_product(get_addon_fullname('contm'));
            # SLES-15SP2+ ships a specific kubernetes client version. Older versions hold a version-independent kubernetes-client package.
            if (is_sle(">=15-SP3")) {
                zypper_call("in kubernetes1.23-client");
            } elsif (is_sle("=15-SP2")) {
                zypper_call("in kubernetes1.18-client");
            } else {
                zypper_call("in kubernetes-client");
            }
        } else {
            zypper_call("in kubernetes-client");
        }
    } else {
        record_info('kubectl preinstalled', 'The kubectl package is already installed.');
    }
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
