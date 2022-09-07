# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Functions to use qe-sap-deployment project
# Maintainer: QE-SAP <qe-sap@suse.de>

## no critic (RequireFilenameMatchesPackage);

=encoding utf8

=head1 NAME

qe-sap-deployment test lib

=head1 COPYRIGHT

Copyright 2022 SUSE LLC
SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE SAP <qe-sap@suse.de>

=cut

package qesapdeployment;

use strict;
use warnings;
use testapi;
use Exporter 'import';

# Constants
use constant DEPLOYMENT_DIR => get_var('DEPLOYMENT_DIR', '/root/qe-sap-deployment');
use constant QESAP_GIT_CLONE_LOG => '/tmp/git_clone.log';

my @log_files = ();

our @EXPORT = qw(
  qesap_create_folder_tree
  qesap_get_deployment_code
);


=head1 DESCRIPTION

Package with common methods and default or constant  values for qe-sap-deployment

=head2 Methods
=head3 qesap_create_folder_tree

Create all needed folders

=cut

sub qesap_create_folder_tree {
    assert_script_run('mkdir -p ' . DEPLOYMENT_DIR, quiet => 1);
}


=head3 qesap_get_deployment_code

Get the qe-sap-deployment code
=cut

sub qesap_get_deployment_code {
    record_info("QESAP repo", "Preparing qe-sap-deployment repository");

    my $git_repo = get_var(QESAPDEPLOY_GITHUB_REPO => 'github.com/SUSE/qe-sap-deployment');
    enter_cmd "cd " . DEPLOYMENT_DIR;

    # Script from a release
    if (get_var('QESAPDEPLOY_VER')) {
        my $ver_artifact = 'v' . get_var('QESAPDEPLOY_VER') . '.tar.gz';

        my $curl_cmd = "curl -v -L https://$git_repo/archive/refs/tags/$ver_artifact -o$ver_artifact";
        assert_script_run("set -o pipefail ; $curl_cmd | tee " . QESAP_GIT_CLONE_LOG, quiet => 1);

        my $tar_cmd = "tar xvf $ver_artifact --strip-components=1";
        assert_script_run($tar_cmd);
        enter_cmd 'ls -lai';
    }
    else {
        # Get the code for the qe-sap-deployment by cloning its repository
        assert_script_run('git config --global http.sslVerify false', quiet => 1) if get_var('QESAPDEPLOY_GIT_NO_VERIFY');
        my $git_branch = get_var('QESAPDEPLOY_GITHUB_BRANCH', 'main');

        my $git_clone_cmd = 'git clone --depth 1 --branch ' . $git_branch . ' https://' . $git_repo . ' ' . DEPLOYMENT_DIR;
        push(@log_files, QESAP_GIT_CLONE_LOG);
        assert_script_run("set -o pipefail ; $git_clone_cmd | tee " . QESAP_GIT_CLONE_LOG, quiet => 1);
    }
}


1;
