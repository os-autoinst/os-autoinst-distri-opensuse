# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Deploy CAP and run test app
# Maintainer: Martin Kravec <mkravec@suse.com>

use parent 'caasp_controller';
use caasp_controller;

use strict;
use warnings;
use testapi;
use caasp 'script_retry';
use utils qw(zypper_call systemctl);

sub run {
    switch_to 'xterm';

    my $mip = script_output q#host -cIN master-api.openqa.test | awk '{print $NF}'#;
    my $xip = "$mip.xip.io";

    become_root;
    systemctl 'stop SuSEfirewall2';
    # Download tools
    zypper_call 'ar -fG https://download.opensuse.org/repositories/Cloud:/Tools/SLE_12_SP3/Cloud:Tools.repo';
    zypper_call 'ar -fG https://download.opensuse.org/repositories/openSUSE:/Backports:/SLE-12-SP3/standard/openSUSE:Backports:SLE-12-SP3.repo';
    zypper_call 'in helm cf-cli';
    # Setup NFS server
    assert_script_run 'mkdir /nfs';
    assert_script_run 'chmod a+w /nfs';
    assert_script_run 'echo "/nfs *(rw,no_root_squash,sync,no_subtree_check)" >> /etc/exports';
    systemctl 'start nfs-server';
    send_key 'ctrl-d';

    # Prepare files & tools
    assert_script_run 'helm init --client-only';
    assert_script_run 'helm repo add suse https://kubernetes-charts.suse.com/';
    assert_script_run 'curl -O ' . data_url('caasp/cap/cap-namespaces.yaml');
    assert_script_run 'curl -O ' . data_url('caasp/cap/cap-psp-rbac.yaml');
    assert_script_run 'curl -O ' . data_url('caasp/cap/scf-config.yaml');
    assert_script_run "sed -i 's/10.161.59.61/$mip/g' scf-config.yaml";

    # Create namespaces & allow Pod Security Policies escalation
    assert_script_run 'kubectl create -f cap-namespaces.yaml';
    assert_script_run 'kubectl create -f cap-psp-rbac.yaml';

    # NFS storage class - is controller always 10.0.2.1 ?
    record_info 'Deploy NFS';
    assert_script_run 'helm install stable/nfs-client-provisioner --set nfs.server=10.0.2.1 --set nfs.path=/nfs';
    script_retry 'kubectl get pods | egrep -q "0/|1/2|No resources"', expect => 1;
    assert_script_run 'kubectl get pods';

    # UAA
    record_info 'Deploy UAA', 'Takes 7-25+ minutes until ready';
    assert_script_run 'helm install suse/uaa --name susecf-uaa --namespace uaa --values scf-config.yaml';
    script_retry 'kubectl get pods -nuaa | egrep -q "0/|1/2|No resources"', expect => 1, retry => 30, delay => 60;
    assert_script_run 'kubectl get pods -nuaa';

    # SCF
    record_info 'Deploy SCF', 'Takes 25+ minutes until ready';
    type_string q#SECRET=$(kubectl get pods --namespace uaa -o jsonpath='{.items[?(.metadata.name=="uaa-0")].spec.containers[?(.name=="uaa")].env[?(.name=="INTERNAL_CA_CERT")].valueFrom.secretKeyRef.name}')# . "\n";
    type_string q#CA_CERT="$(kubectl get secret $SECRET --namespace uaa -o jsonpath="{.data['internal-ca-cert']}" | base64 --decode -)"# . "\n";
    assert_script_run q#helm install suse/cf --name susecf-scf --namespace scf --values scf-config.yaml --set "secrets.UAA_CA_CERT=${CA_CERT}"#;
    script_retry 'kubectl get pods -nscf | egrep -q "0/|1/2|No resources"', expect => 1, retry => 60, delay => 60;
    assert_script_run 'kubectl get pods -nscf';

    # STRATOS - optional, product is not ready
    # assert_script_run 'helm install suse/console --name susecf-console --namespace stratos --values scf-config.yaml --set storageClass=nfs-client';
    # firefox https://$xip:8443/login - admin/password

    # CF login & space setup
    record_info 'Test CF', 'Login & Push go app & Check in firefox';
    assert_script_run "cf login -u admin -p password --skip-ssl-validation -a https://api.$xip";
    assert_script_run 'cf create-space qaspace';
    assert_script_run 'cf target -o system -s qaspace';

    # Deploy application
    assert_script_run 'curl -O ' . data_url('caasp/cap/goapp.tgz');
    assert_script_run 'tar -xzf goapp.tgz';
    assert_script_run 'cf push -p goapp -f goapp/manifest.yaml', 300;

    # Check application
    type_string "firefox goapp.$xip\n";
    assert_screen 'go-pik-pik';
    send_key 'ctrl-w';
}

1;
