# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Trento test
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use strict;
use testapi;
use base 'trento';


sub run {
    my ($self) = @_;
    die "Only AZURE deployment supported for the moment" unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    $self->select_serial_terminal;

    my $machine_ip = $self->az_get_vm_ip;

    my $trento_web_password_cmd = $self->az_vm_ssh_cmd(
        'kubectl get secret trento-server-web-secret' .
          " -o jsonpath='{.data.ADMIN_PASSWORD}'" .
          '|base64 --decode', $machine_ip);
    my $trento_web_password = script_output($trento_web_password_cmd);

    my $cypress_test_dir = "/root/test/test";
    enter_cmd "cd " . $cypress_test_dir;
    assert_script_run("./cypress.env.py -u http://" . $machine_ip . " -p " . $trento_web_password . " -f Premium");
    assert_script_run('cat cypress.env.json');

    assert_script_run "mkdir " . $self->CYPRESS_LOG_DIR;

    #  Cypress verify: cypress.io self check about the framework installation
    $self->cypress_exec($cypress_test_dir, 'verify', 120, 'verify', 1);
    $self->cypress_log_upload(('.txt'));

    # test about first visit: login and eula
    $self->cypress_test_exec($cypress_test_dir, 'first_visit', 900, 0);

    # all other cypress tests
    $self->cypress_test_exec($cypress_test_dir, 'all', 900, 0);
}

sub post_fail_hook {
    my ($self) = @_;
    $self->az_delete_group;

    $self->cypress_log_upload(('.txt', '.mp4'));
    parse_extra_log("XUnit", $_) for split(/\n/, script_output('find ' . $self->CYPRESS_LOG_DIR . ' -type f -iname "*.xml"'));

    $self->SUPER::post_fail_hook;
}

1;
