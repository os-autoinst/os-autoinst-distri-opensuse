# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Rancher container test using podman
# Maintainer: George Gkioulis <ggkioulis@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use containers::common;
use containers::utils;
use version_utils "get_os_release";
use rancher::utils;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    assert_script_run("whoami");

    my ($running_version, $sp, $host_distri) = get_os_release;
    install_podman_when_needed($host_distri);

    setup_rancher_container(runtime => "podman");
}

1;
