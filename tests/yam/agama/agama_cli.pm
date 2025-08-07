## Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Run installation through CLI with Agama
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::Agama::agama_base;
use strict;
use warnings;
use testapi;
use JSON qw(decode_json to_json);
use power_action_utils 'power_action';
use Utils::Architectures qw(is_s390x);
use Utils::Backends qw(is_svirt);

sub run {
    my $self = shift;

    assert_script_run("agama config show -o profile.json");
    my $json = decode_json(script_output("cat profile.json"));
    $json->{'product'}->{'id'} = 'SLES';
    $json->{'product'}->{'registrationCode'} = get_var('SCC_REGCODE');
    $json->{'root'} = {
        'hashedPassword' => \1,
        'password' => '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
    };
    $json->{'user'} = {
        'fullName' => 'Bernhard M. Wiedemann',
        'hashedPassword' => \1,
        'password' => '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
        'userName' => 'bernhard'
    };

    my $json_pretty = to_json($json, {pretty => 1});
    assert_script_run("echo '$json_pretty' > /tmp/profile.json");
    assert_script_run("agama config load file:///tmp/profile.json");
    assert_script_run("agama install", timeout => 2400);

    $self->upload_agama_logs();

    # make sure we will boot from hard disk next time
    if (is_s390x() && is_svirt()) {
        select_console 'installation';
        my $svirt = console('svirt')->change_domain_element(os => boot => {dev => 'hd'});
    }
    power_action('reboot', keepconsole => 1, first_reboot => 1)
}

1;
