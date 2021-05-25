# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic functionality for testing rancher container
# Maintainer: George Gkioulis <ggkioulis@suse.com>

package rancher::utils;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use utils;
use mm_network;
use version_utils;
use Utils::Systemd 'disable_and_stop_service';

our @EXPORT = qw(setup_rancher_container kubectl_basic_test prepare_mm_network);

sub setup_rancher_container {
    my %args    = @_;
    my $runtime = $args{runtime};
    die "You must define the runtime!" unless $runtime;

    assert_script_run("$runtime pull docker.io/rancher/rancher:latest", timeout => 600);
    assert_script_run("$runtime run --name rancher_webui --privileged -d --restart=unless-stopped -p 80:80 -p 443:443 rancher/rancher");

    # Check every 30 seconds that the cluster is setup. Times out after 20 minutes
    script_retry("$runtime logs rancher_webui 2>&1 |grep 'Starting networking.k8s.io'", delay => 30, retry => 40);

    assert_script_run("curl -k https://localhost");
    record_info("Rancher UI ready");
}

sub kubectl_basic_test {
    assert_script_run "kubectl get pod --all-namespaces -o wide";
    assert_script_run "kubectl get service --all-namespaces -o wide";
    assert_script_run "kubectl get namespaces --all-namespaces -o wide";
    assert_script_run "kubectl get endpoints --all-namespaces -o wide";
    assert_script_run "kubectl get deployments --all-namespaces -o wide";
    assert_script_run "kubectl get replicasets --all-namespaces -o wide";
    assert_script_run "kubectl get ingresses --all-namespaces -o wide";
    assert_script_run "kubectl cluster-info";
}

sub prepare_mm_network {
    systemctl('start sshd.service');
    disable_and_stop_service('firewalld');

    configure_hostname(get_required_var('HOSTNAME'));
    configure_dhcp();

    assert_script_run "ssh-keygen -t rsa -P '' -C '`whoami`@`hostname`' -f ~/.ssh/id_rsa";

    # Check that we have default route
    script_retry("ip r s | grep default", delay => 15, retry => 12);

    # Check that we have nameserver to use
    script_retry("cat /etc/resolv.conf | grep nameserver", delay => 15, retry => 12);

    # Check that DNS works
    script_retry("nslookup opensuse.org", delay => 15, retry => 12);
}

1;
