# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Trento test the web interface
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use testapi;
use base 'trento';


sub run {
    my ($self) = @_;
    die "Only AZURE deployment supported for the moment" unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    $self->select_serial_terminal;

    my $cypress_test_dir = "/root/test/test";
    enter_cmd "cd " . $cypress_test_dir;

    trento::cypress_configs($cypress_test_dir);
    assert_script_run "mkdir " . $self->CYPRESS_LOG_DIR;

    #  Cypress verify: cypress.io self check about the framework installation
    $self->cypress_exec($cypress_test_dir, 'verify', 120, 'verify', 1);
    $self->cypress_log_upload(('.txt'));

    # test about first visit: login and eula
    $self->cypress_test_exec($cypress_test_dir, 'first_visit', 900);

    # all other cypress tests
    $self->cypress_test_exec($cypress_test_dir, 'all', 900);
}

sub post_fail_hook {
    my ($self) = @_;
    if (!get_var('TRENTO_EXT_DEPLOY_IP')) {
        $self->az_delete_group;
    }

    $self->cypress_log_upload(('.txt', '.mp4'));
    parse_extra_log("XUnit", $_) for split(/\n/, script_output('find ' . $self->CYPRESS_LOG_DIR . ' -type f -iname "*.xml"'));

    $self->destroy_qesap();

    $self->SUPER::post_fail_hook;
}

1;
