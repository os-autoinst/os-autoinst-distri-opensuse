# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Rancher container test using podman
# Maintainer: George Gkioulis <ggkioulis@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use containers::common;
use containers::utils;
use version_utils "get_os_release";
use rancher::utils;

sub run {
    select_serial_terminal;

    my ($running_version, $sp, $host_distri) = get_os_release;
    install_podman_when_needed($host_distri);

    setup_rancher_container(runtime => "podman");
}

1;
