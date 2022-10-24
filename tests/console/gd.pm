# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gd
# Summary: gd regression test
#   * Convert gif image to a gd2 image
#   * Convert gif image to a compressed gd2 image
#   * Check if compressed image is smaller than original
#   * Convert gd2 image to various other formats
#   * Check the output of webpng
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>


use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';

sub run {
    select_serial_terminal;
    zypper_call('in gd');
    script_run('cd /var/tmp');
    assert_script_run 'curl -v -o giphy.gif ' . data_url('qam/giphy.gif');
    validate_script_output "md5sum /var/tmp/giphy.gif", sub { m/a2cf36e472e6c42b0bf114c79a87d392/ };
    # Convert the gif image to a gd2 image with chunk size:1 and format:raw
    assert_script_run('giftogd2 giphy.gif giphy.gd2 1 1');
    # Convert the gif image to a gd2 image with chunk size:1 and format:compressed
    assert_script_run('giftogd2 giphy.gif giphy_compressed.gd2 1 2');
    # Check if compressed is smaller than original picture
    validate_script_output 'if [[ `stat -c%s "giphy.gd2"` -le `stat -c%s "giphy_compressed.gd2"` ]]; then echo "FAIL"; else echo "OK"; fi', sub { m/OK/ };
    # Run a couple of convert commands, and check if the output is not empty
    assert_script_run('gd2togif giphy.gd2 convert.gif');
    validate_script_output 'if [[ -s convert.gif ]]; then echo "OK"; else echo "FAIL"; fi', sub { m/OK/ };
    assert_script_run('gd2topng giphy.gd2 convert.png');
    validate_script_output 'if [[ -s convert.png ]]; then echo "OK"; else echo "FAIL"; fi', sub { m/OK/ };
    assert_script_run('gdcmpgif convert.gif giphy.gif');
    validate_script_output 'if [[ -s giphy.gif ]]; then echo "OK"; else echo "FAIL"; fi', sub { m/OK/ };
    assert_script_run('pngtogd convert.png convert.gd');
    validate_script_output 'if [[ -s convert.gd ]]; then echo "OK"; else echo "FAIL"; fi', sub { m/OK/ };
    assert_script_run('gdtopng convert.gd convert2.png');
    validate_script_output('if [[ -s convert2.png ]]; then echo "OK"; else echo "FAIL"; fi', sub { m/OK/ });
    validate_script_output('webpng -l convert.png', sub { m/Index	Red	Green	Blue Alpha\n0	112	70	54	0\n/ });
    validate_script_output('webpng -d convert.png', sub { m/Width: 337 Height: 193 Colors: 69\nFirst 100% transparent index: none\nInterlaced: no/ });
    validate_script_output('webpng -a convert.png', sub { m/alpha channel information:\nNOT a true color image\n0 alpha channels/ });
}
1;

