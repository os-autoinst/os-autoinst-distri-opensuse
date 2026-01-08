## Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Perform a default installation using only CLI while exercising various commands.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base Yam::Agama::agama_base;
use testapi;
use power_action_utils qw(power_action);
use Utils::Architectures qw(is_s390x);
use Utils::Backends qw(is_svirt);

sub agama_config_edit {
    my $regex = shift;

    script_run('agama config edit', timeout => 0);
    wait_still_screen();
    enter_cmd($regex);
    enter_cmd(":wq");
    wait_still_screen();
}

sub run {
    my $self = shift;

    validate_script_output('agama 2>&1 | tee', qr/Agama's command-line interface/, proceed_on_failure => 1,
        fail_message => 'Agama help not shown');

    assert_script_run('agama config show | jq -C');

    assert_script_run("jq -n '.root.password = \"$testapi::password\"' | agama config load");
    assert_script_run("agama config show | grep $testapi::password");

    my $product_id = get_var('AGAMA_PRODUCT_ID');
    assert_script_run("jq -n '.product.id = \"$product_id\"' | agama config load");
    assert_script_run("agama config show | grep $product_id");

    validate_script_output('agama probe', qr/Analyze/, fail_message => 'Agama probe returned bad state');

    my $rpm_url = data_url('yam/agama/hello-world-0.1-1.1.noarch.rpm');
    assert_script_run("agama download $rpm_url /tmp/hello-world.rpm");
    validate_script_output('stat /tmp/hello-world.rpm', qr/Size: 7019/,
        fail_message => 'Downloaded file does not match expected size');

    agama_config_edit(":\%s/bernhard/jose/g");
    assert_script_run('agama config show | grep jose');
    agama_config_edit(":\%s/jose/bernhard/g");

    script_run('agama events > /tmp/agama_events.log 2>&1 &', timeout => 0);
    validate_script_output('cat /tmp/agama_events.log', qr/ClientConnected/,
        fail_message => 'Agama connected event not shown');

    script_run('agama auth login', timeout => 0);
    enter_cmd("$testapi::password");
    my $regex = 'Not authenticated in localhost';
    validate_script_output('agama auth show', qr/(?!$regex)/,
        fail_message => 'Not authenticated in Agama');

    assert_script_run('agama install', timeout => 2400);
    $self->upload_agama_logs();

    # make sure we will boot from hard disk next time
    if (is_s390x() && is_svirt()) {
        select_console 'installation';
        my $svirt = console('svirt')->change_domain_element(os => boot => {dev => 'hd'});
        # reboot via console
        power_action('reboot', keepconsole => 1, first_reboot => 1);
    } else {
        script_run('agama finish', timeout => 0);
    }
}

1;
