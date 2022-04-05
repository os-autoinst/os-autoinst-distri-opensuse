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

our @EXPORT = qw(install_k3s uninstall_k3s install_kubectl install_helm);

sub install_k3s {
    my $k3s_dowload_url = get_required_var("K3S_DOWNLOAD_URL");
    assert_script_run("curl -LO $k3s_dowload_url");
    assert_script_run("install -c -m 744 ./k3s /usr/local/bin/k3s");
    enter_cmd("k3s server 2>&1 | tee k3s.log &");
    script_retry("grep 'Wrote kubeconfig /etc/rancher/k3s/k3s.yaml' k3s.log", delay => 20, retry => 10);
    assert_script_run("k3s kubectl get node");
    script_run("mkdir \$HOME/.kube");
    script_run("rm \$HOME/.kube/config");
    assert_script_run("ln -s /etc/rancher/k3s/k3s.yaml \$HOME/.kube/config");
}

sub uninstall_k3s {
    my $pid = script_output("ps | grep k3s-server | head -n 1 | cut -d ' ' -f1");
    script_run("kill $pid");
    script_run("rm \$HOME/.kube/config");
    script_run("rm /usr/local/bin/k3s");
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
    add_suseconnect_product(get_addon_fullname('phub')) if is_sle('15-sp3+');
    zypper_call("in helm");
}

1;
