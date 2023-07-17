# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Test SUMA container images:
#   The scope of the testing is minimal and covers:
#   proxy-httpd
#   proxy-salt-broker
#   proxy-squid
#   proxy-ssh
#   proxy-tftpd
#
# Maintainer: Maurizio Galli <maurizio.galli@suse.com>

use Mojo::Base qw(consoletest);
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    select_serial_terminal;

    my $image = get_required_var('CONTAINER_IMAGE_TO_TEST');

    assert_script_run("podman pull $image");
}

sub test_flags {
    return {fatal => 1};
}

1;
