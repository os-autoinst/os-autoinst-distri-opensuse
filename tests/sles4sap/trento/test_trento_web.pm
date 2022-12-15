# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Trento test the web interface
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use qesapdeployment 'qesap_upload_logs';
use trento;


sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $cypress_test_dir = "/root/test/test";
    enter_cmd "cd " . $cypress_test_dir;

    cypress_configs($cypress_test_dir);
    assert_script_run "mkdir " . CYPRESS_LOG_DIR;

    #  Cypress verify: cypress.io self check about the framework installation
    cypress_exec($cypress_test_dir, 'verify', 120, 'verify', 1);
    cypress_log_upload(('.txt'));

    # test about first visit: login and eula
    cypress_test_exec($cypress_test_dir, 'first_visit', 900);

    # all other cypress tests
    cypress_test_exec($cypress_test_dir, 'all', 900);

    trento_support('test_trento_web');
}

sub post_fail_hook {
    my ($self) = @_;
    if (!get_var('TRENTO_EXT_DEPLOY_IP')) {
        k8s_logs(qw(web runner));
        trento_support('test_trento_web');
        az_delete_group();
    }

    cypress_log_upload(('.txt', '.mp4'));
    parse_extra_log("XUnit", $_) for split(/\n/, script_output('find ' . CYPRESS_LOG_DIR . ' -type f -iname "*.xml"'));

    qesap_upload_logs();
    cluster_destroy();

    $self->SUPER::post_fail_hook;
}

1;
