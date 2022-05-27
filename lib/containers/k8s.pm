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
use utils qw(zypper_call script_retry);
use version_utils qw(is_sle);
use registration qw(add_suseconnect_product get_addon_fullname);

our @EXPORT = qw(install_k3s uninstall_k3s install_kubectl install_helm install_oc);

sub install_k3s {
    assert_script_run("curl -sfL https://get.k3s.io | sh -");
    enter_cmd("k3s server &");
    script_retry("test -e /etc/rancher/k3s/k3s.yaml", delay => 20, retry => 10);
    assert_script_run("k3s kubectl get node");
    script_run("mkdir \$HOME/.kube");
    script_run("rm \$HOME/.kube/config");
    assert_script_run("ln -s /etc/rancher/k3s/k3s.yaml \$HOME/.kube/config");
}

sub uninstall_k3s {
    assert_script_run("rm \$HOME/.kube/config");
    assert_script_run("/usr/local/bin/k3s-uninstall.sh");
}

sub install_kubectl {
    if (is_sle) {
        zypper_call("in kubernetes1.18-client");
    }
    else {
        zypper_call("in kubernetes-client");
    }
}

sub install_helm {
    zypper_call("in helm");
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
