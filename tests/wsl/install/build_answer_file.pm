# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Build the Windows answer file image and publish it as an asset
# Maintainer: qa-c <qa-c@suse.de>
#
# Variables:
# ANSWER_FILE_XML - path of the answer file in the data directory
# PUBLISH_ANSWER_FILE - name of the .raw image to publish

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils 'zypper_call';

sub run {
    my $xml = get_required_var('ANSWER_FILE_XML');
    my $raw = get_required_var('PUBLISH_ANSWER_FILE');

    select_serial_terminal;
    zypper_call('in mtools');
    assert_script_run('curl -fsSL -o Autounattend.xml ' . data_url($xml));
    assert_script_run("mformat -C -t 512 -h 2 -s 32 -c 4 -R 4 -m 248 -i $raw ::");
    assert_script_run("mcopy -i $raw Autounattend.xml ::Autounattend.xml");
    assert_script_run("mdir -i $raw ::");
    upload_asset($raw, 1);
}

1;
