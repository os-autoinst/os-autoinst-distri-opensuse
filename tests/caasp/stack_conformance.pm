# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run CNCF K8s Conformance tests
#   Maintain certified status of CaaSP under k8s certification
#   Project: https://github.com/cncf/k8s-conformance
# Maintainer: Martin Kravec <mkravec@suse.com>, Panagiotis Georgiadis <pgeorgiadis@suse.com>

use parent 'caasp_controller';
use caasp_controller;

use strict;
use utils;
use testapi;

sub run {
    switch_to 'xterm';

    # https://github.com/cncf/k8s-conformance/blob/master/instructions.md
    my $sb_yaml = 'https://raw.githubusercontent.com/cncf/k8s-conformance/master/sonobuoy-conformance.yaml';
    my $sb_exit = '"no-exit was specified, sonobuoy is now blocking"';
    my $sb_pass = '"SUCCESS! -- [1-9][0-9]\+ Passed | 0 Failed | 0 Pending.*PASS"';
    my $sb_test = '"Test Suite Passed"';

    # Run conformance tests and wait 90 minutes for result
    assert_script_run "curl -L $sb_yaml | kubectl apply -f -";
    for (1 .. 90) {
        last unless script_run "kubectl -n sonobuoy logs sonobuoy | grep $sb_exit";
        sleep 60;
    }

    # Results available at /tmp/sonobuoy/201801191307_sonobuoy_be1dbeae-f889-4735-9aa9-4cc04ad13cd5.tar.gz
    my $path = script_output "kubectl -n sonobuoy logs sonobuoy | grep -o 'Results.*tar.gz'  | cut -d' ' -f4";
    assert_script_run "kubectl cp sonobuoy/sonobuoy:$path sonobuoy.tgz";

    # Expect: SUCCESS! -- 123 Passed | 0 Failed | 0 Pending | 586 Skipped PASS
    script_run 'tar -xzf sonobuoy.tgz';
    upload_logs 'sonobuoy.tgz';
    upload_logs 'plugins/e2e/results/e2e.log';
    assert_script_run "tail -10 plugins/e2e/results/e2e.log | tee /dev/tty | grep $sb_pass";
    assert_script_run "tail -10 plugins/e2e/results/e2e.log | grep $sb_test";

    switch_to 'velum';
}

1;

