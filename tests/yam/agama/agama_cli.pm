## Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Run installation through CLI with Agama
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::Agama::agama_base;
use testapi;
use power_action_utils qw(power_action);
use Utils::Architectures qw(is_s390x);
use Utils::Backends qw(is_svirt);

sub run {
    my $self = shift;

    script_run('agama config edit', timeout => 0);
    assert_screen('agama-config-edit');
    send_key(':');
    send_key('q');
    send_key('ret');
    assert_script_run('agama install', timeout => 2400);
    $self->upload_agama_logs();

    # make sure we will boot from hard disk next time
    if (is_s390x() && is_svirt()) {
        select_console 'installation';
        my $svirt = console('svirt')->change_domain_element(os => boot => {dev => 'hd'});
    }
    assert_script_run('agama finish');
}

1;
