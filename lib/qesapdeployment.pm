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
use constant PIP_INSTALL_LOG => '/tmp/pip_install.log';

# Terraform requirement
#  terraform/azure/infrastructure.tf  "azurerm_storage_account" "mytfstorageacc"
# stdiag<PREFID><JOB_ID> can only consist of lowercase letters and numbers,
# and must be between 3 and 24 characters long
use constant QESAPDEPLOY_PREFIX => 'qesapdep';

my @log_files = ();

our @EXPORT = qw(
  qesap_create_folder_tree
  qesap_pip_install
  qesap_upload_logs
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

=head3 qesap_pip_install

  Install all Python requirements of the qe-sap-deployment

=cut

sub qesap_pip_install {
    enter_cmd 'pip config --site set global.progress_bar off';
    my $pip_ints_cmd = 'pip install --no-color --no-cache-dir ';
    # Hack to fix an installation conflict. Someone install PyYAML 6.0 and awscli needs an older one
    push(@log_files, PIP_INSTALL_LOG);
    assert_script_run($pip_ints_cmd . 'awscli==1.19.48 | tee ' . PIP_INSTALL_LOG, 180);
    assert_script_run($pip_ints_cmd . '-r ' . DEPLOYMENT_DIR . '/requirements.txt | tee -a ' . PIP_INSTALL_LOG, 180);
}

=head3 qesap_upload_logs

    collect and upload logs (pip, qesap, tfvars, config.yaml)

=over 2

=item B<QESAPREPO> - String path of the local clone of qe-sap-deployment

=item B<FAILOK> - used as failok for the upload_logs

=back
=cut

sub qesap_upload_logs {
    my ($self, $failok) = @_;
    record_info("Uploading logfiles", join("\n", @log_files));
    for my $file (@log_files) {
        upload_logs($file, failok => $failok);
    }
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
