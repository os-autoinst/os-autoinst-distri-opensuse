# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Rancher container test using docker
# Maintainer: George Gkioulis <ggkioulis@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use containers::common;
use version_utils "get_os_release";
use containers::utils;
use rancher::utils;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my ($running_version, $sp, $host_distri) = get_os_release;
    install_docker_when_needed($host_distri);

    setup_rancher_container(runtime => "docker");
}

1;
