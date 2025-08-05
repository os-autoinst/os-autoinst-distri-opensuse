## Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Run installation through CLI with Agama
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::Agama::agama_base;
use strict;
use warnings;
use testapi;
use JSON qw(decode_json to_json);

sub run {
    my $self = shift;

    assert_script_run("agama config show -o profile.json");
    my $json = decode_json(script_output("cat profile.json"));
    $json->{'product'}->{'id'} = 'SLES';
    $json->{'product'}->{'registrationCode'} = get_var('SCC_REGCODE');
    $json->{'root'} = {
        'password' => 'nots3cr3t'
    };

    open my $fh, '>', '/tmp/profile.json' or die "Cannot open /tmp/profile.json file to write JSON";
    my $json_pretty = to_json($json, {pretty => 1});
    print $fh $json_pretty;
    close $fh;
    assert_script_run("agama config load file:///tmp/profile.json");
    assert_script_run("agama install");

    $self->upload_agama_logs();
}

1;
