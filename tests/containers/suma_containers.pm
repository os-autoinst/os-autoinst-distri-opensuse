
# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Test SUMA container images:
#   The scope of the testing is minimal and covers pulling and running
#   container images from the internal registry.suse.de
#
# The container images tested are:
#   - proxy-httpd
#   - proxy-salt-broker
#   - proxy-squid
#   - proxy-ssh
#   - proxy-tftpd
#
# The testing of proxy-charts is limited to pulling the tar from the registry to
# and inspect the content to ensure Charts is available.
# Install or deployment is not covered in this scenario.
#
# In depth testing of all the images  is already done by the SUMA QE team
#
# Maintainer: Maurizio Galli <maurizio.galli@suse.com>

use Mojo::Base qw(consoletest);
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    select_serial_terminal;

    my $image = get_required_var('CONTAINER_IMAGE_TO_TEST');

    if (check_var('CONTAINER_SUMA', 'image')) {
        my $runtimes = get_required_var('CONTAINER_RUNTIMES');
        my @runtimes = split /,/, $runtimes;
        for my $runtime (@runtimes) {
            script_retry("$runtime pull $image", timeout => 300, delay => 60, retry => 3);
            assert_script_run("$runtime run --rm $image true");
        }
    }
    elsif (check_var('CONTAINER_SUMA', 'chart')) {
        script_retry("helm pull $image", timeout => 300, delay => 60, retry => 3);
        assert_script_run("tar -tf proxy-*.tgz && rm proxy-*.tgz");
    } else {
        die "Unsupported CONTAINER_SUMA setting";
    }
}

1;
