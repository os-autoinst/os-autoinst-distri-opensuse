# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Rancher container test using docker
# Maintainer: George Gkioulis <ggkioulis@suse.com>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use containers::common;
use containers::utils;
use rancher::utils;

sub run {
    select_serial_terminal;

    install_docker_when_needed();

    setup_rancher_container(runtime => "docker");
}

1;
