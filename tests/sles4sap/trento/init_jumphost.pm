# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Trento test
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use strict;
use testapi;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    # Get the code for the Trento deployment
    enter_cmd 'cd ${HOME}/test';
    my $git_branch = get_var('TRENTO_GITLAB_BRANCH', 'master');
    assert_script_run("git checkout " . $git_branch);
    assert_script_run("git pull origin " . $git_branch);

    # az login
    die "Only AZURE deployment supported for the moment" unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    my $provider = $self->provider_factory();
}

1;
