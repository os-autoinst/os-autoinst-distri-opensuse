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
  qesap_configure_tfvar
  qesap_configure_variables
  qesap_configure_hanamedia
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


=head3 qesap_configure_tfvar

Generate a terraform.tfvars from a template.

=over 4

=item B<PROVIDER> - cloud provider, used to select
                    the right folder in the qe-sap-deploy repo

=item B<REGION> - cloud region where to perform the deployment.
                  Used for %REGION%

=item B<RESOURCE_GROUP_POSTFIX> - used as deployment_name in tfvars

=item B<OS_VERSION> - string for the OS version to be used for the deployed machine.
                      Used for %OSVER%

=back
=cut

sub qesap_configure_tfvar {
    my ($provider, $region, $resource_group_postfix, $os_version, $ssh_key) = @_;
    record_info("QESAP TFVARS", "provider:$provider region:$region resource_group_postfix:$resource_group_postfix os_version:$os_version ssh_key:$ssh_key");
    my $tfvar = DEPLOYMENT_DIR . '/terraform/' . lc($provider) . '/terraform.tfvars';
    assert_script_run("cp $tfvar.openqa $tfvar");
    push(@log_files, $tfvar);
    file_content_replace($tfvar,
        q(%REGION%) => $region,
        q(%DEPLOYMENTNAME%) => $resource_group_postfix,
        q(%OSVER%) => $os_version,
        q(%SSHKEY%) => $ssh_key
    );
    upload_logs($tfvar);
}

=head3 qesap_configure_variables

Generate the variables.sh loaded by build.sh and destroy.sh

=over 1

=item B<PROVIDER> - cloud provider, used to select
                    the right folder in the qe-sap-deploy repo

=item B<SAP_REGCODE> - SCC code

=back
=cut

sub qesap_configure_variables {
    my ($provider, $sap_regcode) = @_;

    my $variables_sh = DEPLOYMENT_DIR . '/variables.sh';

    # is it a good idea to save variables.sh? as it has the SCC code.
    push(@log_files, $variables_sh);

    # variables.sh file
    enter_cmd 'echo "PROVIDER=' . lc($provider) . '" > ' . $variables_sh;
    enter_cmd "echo \"REG_CODE='$sap_regcode'\" >> $variables_sh";
    enter_cmd "echo \"EMAIL='testing\@suse.com'\" >> $variables_sh";
    enter_cmd "echo \"SAPCONF='true'\" >> $variables_sh";
    enter_cmd "echo \"export REG_CODE EMAIL SAPCONF\" >> $variables_sh";
    upload_logs($variables_sh);
}

=head3 qesap_configure_hanamedia

Generate the hana_media.yaml for Ansible

=over 3

=item B<SAPCAR> - blob server url for the SAPCAR

=item B<IMDB_SERVER> - blob server url for the IMDB_SERVER

=item B<IMDB_CLIENT> - blob server url for the IMDB_CLIENT

=back
=cut

sub qesap_configure_hanamedia {
    my ($sapcar, $imbd_server, $imbd_cient) = @_;
    my $media_var = DEPLOYMENT_DIR . '/ansible/playbooks/vars/azure_hana_media.yaml';
    assert_script_run("cp $media_var.openqa $media_var");

    push(@log_files, $media_var);
    file_content_replace($media_var,
        q(%SAPCAR%) => $sapcar,
        q(%IMDB_SERVER%) => $imbd_server,
        q(%IMDB_CLIENT%) => $imbd_cient);
    upload_logs($media_var);
}
1;
