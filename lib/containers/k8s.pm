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
use utils qw(zypper_call script_retry file_content_replace validate_script_output_retry);
use Utils::Systemd qw(systemctl);
use containers::utils 'registry_url';
use version_utils qw(is_sle);
use registration qw(add_suseconnect_product get_addon_fullname);

our @EXPORT = qw(install_k3s uninstall_k3s install_kubectl install_helm install_oc);

sub install_k3s {
    zypper_call('in apparmor-parser') if (is_sle('>=15-sp1'));
  # Apply additional options. For more information see https://rancher.com/docs/k3s/latest/en/installation/install-options/#options-for-installation-with-script
    my $k3s_version = get_var("CONTAINERS_K3S_VERSION");
    if ($k3s_version) {
        record_info('k3s', $k3s_version);
        assert_script_run("export INSTALL_K3S_VERSION=$k3s_version");
    }
    assert_script_run("export INSTALL_K3S_SYMLINK=" . get_var('K3S_SYMLINK')) if (get_var('K3S_SYMLINK'));
    assert_script_run("export INSTALL_K3S_BIN_DIR=" . get_var('K3S_BIN_DIR')) if (get_var('K3S_BIN_DIR'));
    assert_script_run("export INSTALL_K3S_CHANNEL=" . get_var('K3S_CHANNEL')) if (get_var('K3S_CHANNEL'));
    # github.com/k3s-io/k3s#5946 - The kubectl delete namespace helm-ns-413 command freezes and does nothing
    # Note: The install script starts a k3s-server by default, unless INSTALL_K3S_SKIP_START is set to true
    assert_script_run("curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true sh -s - --disable=metrics-server");
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
}

sub uninstall_k3s {
    assert_script_run("rm -f ~/.kube/config");
    assert_script_run("/usr/local/bin/k3s-uninstall.sh");
}

sub install_kubectl {
    if (script_run("which kubectl") != 0) {
        if (is_sle) {
            # kubectl is in the container module
            add_suseconnect_product(get_addon_fullname('contm'));
            # SLES-15SP2+ ships a specific kubernetes client version. Older versions hold a version-independent kubernetes-client package.
            if (is_sle(">15-SP1")) {
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

sub install_helm {
    zypper_call("in helm");
    record_info('helm', script_output("helm version"));
}

sub install_oc {
    my $url = get_required_var('CONTAINER_OC_BINARY_URL');
    assert_script_run("wget --no-check-certificate $url");
    $url =~ m|([^/]+)/?$|;
    assert_script_run("tar zxvf $1");
    assert_script_run('mv oc /usr/local/bin');
    assert_script_run('oc');
}
1;
