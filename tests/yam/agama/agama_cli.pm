## Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Run installation through CLI with Agama
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::Agama::agama_base;
use testapi;
use power_action_utils qw(power_action);
use Utils::Architectures qw(is_s390x);
use Utils::Backends qw(is_svirt);

sub agama_config_edit {
    my $regex = @_;

    script_run('agama config edit', timeout => 0);
    wait_still_screen();
    type_string($regex);
    type_string(":wq\n");
    wait_still_screen();
}

sub run {
    my $self = shift;

    my product_id = get_var('AGAMA_PRODUCT_ID');
    my $agama_help = script_output('agama');
    diag($agama_help);
    die 'Agama Help not shown' unless $agama_help =~ "Agama's command-line interface";

    assert_script_run('agama config show | jq -C');

    assert_script_run("jq -n '.root.password = \"$testapi::password\"' | agama config load");
    assert_script_run("agama config show | grep $testapi::password");

    assert_script_run("jq -n '.product.id = \"$product_id\"' | agama config load");
    assert_script_run("agama config show | grep $product_id");

    assert_script_run('agama probe');

    assert_script_run('agama download https://github.com/os-autoinst/os-autoinst-distri-opensuse/raw/refs/heads/master/data/yam/agama/hello-world-0.1-1.1.noarch.rpm /tmp/hello-world.rpm');

    agama_config_edit(":\%s/bernhard/jose/g\n");
    assert_script_run('agama config show | grep jose');
    agama_config_edit(":\%s/jose/bernhard/g\n");

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
