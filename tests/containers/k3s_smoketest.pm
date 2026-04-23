# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run a simple smoketest for k3s, deploying a simple nc server and checking it works
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use Utils::Architectures qw(is_ppc64le);
use containers::k8s qw(apply_manifest wait_for_pod_ready check_k3s dump_k3s_debug_info);

my $pod_name = 'simple-nc-server';
my $labels = [['app', $pod_name]];
my $labels_selector = join(',', map { "$_->[0]=$_->[1]" } @$labels);
my $labels_yaml = join('', map { "    $_->[0]: $_->[1]\n" } @$labels);
my $default_port = 8080;
my $expected_response = 'PONG';
my $content_length = length($expected_response);

my $manifest = <<"EOT";
apiVersion: v1
kind: Pod
metadata:
  name: $pod_name
  labels:
$labels_yaml
spec:
  containers:
    - name: nc-server
      image: registry.opensuse.org/opensuse/busybox:latest
      command:
        - /bin/sh
        - -c
        - |
          echo "$expected_response" > /tmp/response
          while true; do
            nc -l -p $default_port < /tmp/response
          done
      readinessProbe:
        exec:
          command:
            - /bin/sh
            - -c
            - |
              echo > /tmp/request
              nc 127.0.0.1 $default_port < /tmp/request > /tmp/check
              grep -qx "$expected_response" /tmp/check
        initialDelaySeconds: 5
        periodSeconds: 5
EOT

sub create_dummy {
    record_info('manifest', $manifest);
    apply_manifest($manifest);
}

sub delete_dummy {
    assert_script_run("kubectl delete pod -l $labels_selector");
}

sub verify_dummy {
    wait_for_pod_ready(labels => $labels_selector, timeout => 120);
}

sub run {
    select_serial_terminal;

    check_k3s();
    create_dummy();
    verify_dummy();
    delete_dummy();
}

sub post_fail_hook {
    my ($self) = @_;
    dump_k3s_debug_info();
    delete_dummy();
}

1;
