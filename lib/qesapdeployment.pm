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
use utils 'file_content_replace';
use testapi;
use Exporter 'import';


my @log_files = ();

# Terraform requirement
#  terraform/azure/infrastructure.tf  "azurerm_storage_account" "mytfstorageacc"
# stdiag<PREFID><JOB_ID> can only consist of lowercase letters and numbers,
# and must be between 3 and 24 characters long
use constant QESAPDEPLOY_PREFIX => 'qesapdep';

our @EXPORT = qw(
  qesap_create_folder_tree
  qesap_pip_install
  qesap_upload_logs
  qesap_get_deployment_code
  qesap_configure_tfvar
  qesap_configure_variables
  qesap_configure_hanamedia
  qesap_sh_deploy
  qesap_sh_destroy
  qesap_get_inventory
  qesap_prepare_env
  qesap_execute
  qesap_yaml_replace
);

=head1 DESCRIPTION

    Package with common methods and default or constant  values for qe-sap-deployment
=head2 Methods


=head3 qesap_get_file_paths

    Returns a hash containing file paths for config files
=cut

sub qesap_get_file_paths {
    my %paths;
    $paths{qesap_conf_filename} = get_required_var('QESAP_CONFIG_FILE');
    $paths{deployment_dir} = get_var('QESAP_DEPLOYMENT_DIR', get_var('DEPLOYMENT_DIR', '/root/qe-sap-deployment'));
    $paths{terraform_dir} = get_var('PUBLIC_CLOUD_TERRAFORM_DIR', $paths{deployment_dir} . '/terraform');
    $paths{qesap_conf_trgt} = $paths{deployment_dir} . "/scripts/qesap/" . $paths{qesap_conf_filename};
    return (%paths);
}

=head3 qesap_create_folder_tree

    Create all needed folders
=cut

sub qesap_create_folder_tree {
    my %paths = qesap_get_file_paths();
    assert_script_run("mkdir -p $paths{deployment_dir}", quiet => 1);
}

=head3 qesap_pip_install

  Install all Python requirements of the qe-sap-deployment
=cut

sub qesap_pip_install {
    enter_cmd 'pip config --site set global.progress_bar off';
    my $pip_ints_cmd = 'pip install --no-color --no-cache-dir ';
    my $pip_install_log = '/tmp/pip_install.txt';
    my %paths = qesap_get_file_paths();

    # Hack to fix an installation conflict. Someone install PyYAML 6.0 and awscli needs an older one
    push(@log_files, $pip_install_log);
    record_info("QESAP repo", "Installing pip requirements");
    assert_script_run(join(" ", $pip_ints_cmd, 'awscli==1.19.48 | tee', $pip_install_log), 240);
    assert_script_run(join(" ", $pip_ints_cmd, '-r', $paths{deployment_dir} . '/requirements.txt | tee -a', $pip_install_log), 240);
}

=head3 qesap_upload_logs

    qesap_upload_logs([failok=1])

    Collect and upload logs present in @log_files.

=over 1

=item B<FAILOK> - used as failok for the upload_logs. continue even in case upload fails

=back
=cut

sub qesap_upload_logs {
    my (%args) = @_;
    my $failok = $args{failok};
    record_info("Uploading logfiles", join("\n", @log_files));
    for my $file (@log_files) {
        upload_logs($file, failok => $failok);
    }
    # Remove already uploaded files from arrays
    @log_files = ();
}

=head3 qesap_get_deployment_code

    Get the qe-sap-deployment code
=cut

sub qesap_get_deployment_code {
    my $git_repo = get_var(QESAPDEPLOY_GITHUB_REPO => 'github.com/SUSE/qe-sap-deployment');
    my $qesap_git_clone_log = '/tmp/git_clone.txt';
    my %paths = qesap_get_file_paths();

    record_info("QESAP repo", "Preparing qe-sap-deployment repository");

    enter_cmd "cd " . $paths{deployment_dir};
    push(@log_files, $qesap_git_clone_log);

    # Script from a release
    if (get_var('QESAPDEPLOY_VER')) {
        my $ver_artifact = 'v' . get_var('QESAPDEPLOY_VER') . '.tar.gz';

        my $curl_cmd = "curl -v -L https://$git_repo/archive/refs/tags/$ver_artifact -o$ver_artifact";
        assert_script_run("set -o pipefail ; $curl_cmd | tee " . $qesap_git_clone_log, quiet => 1);

        my $tar_cmd = "tar xvf $ver_artifact --strip-components=1";
        assert_script_run($tar_cmd);
        enter_cmd 'ls -lai';
    }
    else {
        # Get the code for the qe-sap-deployment by cloning its repository
        assert_script_run('git config --global http.sslVerify false', quiet => 1) if get_var('QESAPDEPLOY_GIT_NO_VERIFY');
        my $git_branch = get_var('QESAPDEPLOY_GITHUB_BRANCH', 'main');

        my $git_clone_cmd = 'git clone --depth 1 --branch ' . $git_branch . ' https://' . $git_repo . ' ' . $paths{deployment_dir};
        assert_script_run("set -o pipefail ; $git_clone_cmd  2>&1 | tee $qesap_git_clone_log", quiet => 1);
    }
    # Add symlinks for different provider directory naming between OpenQA and qesap-deployment
    assert_script_run("ln -s " . $paths{terraform_dir} . "/aws " . $paths{terraform_dir} . "/ec2");
    assert_script_run("ln -s " . $paths{terraform_dir} . "/gcp " . $paths{terraform_dir} . "/gce");
}

=head3 qesap_yaml_replace

    Replaces yaml config file variables with parameters defined by OpenQA testode, yaml template or yaml schedule.
    Openqa variables need to be added as a hash with key/value pair inside %run_args{openqa_variables}.
    Example:
        my %variables;
        $variables{HANA_SAR} = get_required_var("HANA_SAR");
        $variables{HANA_CLIENT_SAR} = get_required_var("HANA_CLIENT_SAR");
        qesap_yaml_replace(openqa_variables=>\%variables);
=cut

sub qesap_yaml_replace {
    my (%args) = @_;
    my $variables = $args{openqa_variables};
    my %replaced_variables = ();
    my %paths = qesap_get_file_paths();
    push(@log_files, $paths{qesap_conf_trgt});

    for my $variable (keys %{$variables}) {
        $replaced_variables{"%" . $variable . "%"} = $variables->{$variable};
    }
    file_content_replace($paths{qesap_conf_trgt}, %replaced_variables);
    qesap_upload_logs();
}

=head3 qesap_configure_tfvar

Generate a terraform.tfvars from a template.

=over 5

=item B<PROVIDER> - cloud provider, used to select
                    the right folder in the qe-sap-deploy repo

=item B<REGION> - cloud region where to perform the deployment.
                  Used for %REGION%

=item B<RESOURCE_GROUP_POSTFIX> - used as deployment_name in tfvars

=item B<OS_VERSION> - string for the OS version to be used for the deployed machine.
                      Used for %OSVER%

=item B<SSH_KEY> - Public key needed in tfvars

=back
=cut

sub qesap_configure_tfvar {
    my ($provider, $region, $resource_group_postfix, $os_version, $ssh_key) = @_;
    my %paths = qesap_get_file_paths();
    record_info("QESAP TFVARS", join("\n", "provider:$provider", "region:$region", "resource_group_postfix:$resource_group_postfix", "os_version:$os_version", "ssh_key:$ssh_key"));
    my $tfvar = $paths{deployment_dir} . '/terraform/' . lc($provider) . '/terraform.tfvars';
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
    my %paths = qesap_get_file_paths();
    my $variables_sh = "$paths{deployment_dir}/variables.sh";

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
    my %paths = qesap_get_file_paths();
    my $media_var = "$paths{deployment_dir}/ansible/playbooks/vars/azure_hana_media.yaml";
    assert_script_run("cp $media_var.openqa $media_var");

    push(@log_files, $media_var);
    file_content_replace($media_var,
        q(%SAPCAR%) => $sapcar,
        q(%IMDB_SERVER%) => $imbd_server,
        q(%IMDB_CLIENT%) => $imbd_cient);
    upload_logs($media_var);
}

=head3 qesap_sh

Generic handler for any qe-sap-deployment .sh scripts: calls and publish all the logs

=cut

sub qesap_sh {
    my ($ssh_key, $script, $timeout_minutes) = @_;
    my %paths = qesap_get_file_paths();
    my $log = "$paths{deployment_dir}/$script" =~ s/.sh/.log.txt/r;
    enter_cmd "cd $paths{deployment_dir}";
    my $cmd = 'set -o pipefail ;' .
      " ./$script -q -k $ssh_key" .
      "| tee $log";
    push(@log_files, $log);
    assert_script_run($cmd, ($timeout_minutes * 60));

    upload_logs($log);
}

=head3 qesap_sh_deploy

Call build.sh and publish all the logs

=cut

sub qesap_sh_deploy {
    my ($ssh_key) = @_;
    record_info('build.sh');
    qesap_sh($ssh_key, 'build.sh', 45);
}

=head3 qesap_sh_destroy

Call destroy.sh and publish all the logs

=cut

sub qesap_sh_destroy {
    my ($ssh_key) = @_;
    record_info('destroy.sh');
    qesap_sh($ssh_key, 'destroy.sh', 15);
}

=head3 qesap_execute

    qesap_execute(cmd => $qesap_script_cmd [, verbose => 1, cmd_options => $cmd_options] );
    cmd_options - allows to append additional qesap.py commans arguments like "qesap.py terraform -d"
        Example:
        qesap_execute(cmd => 'terraform', cmd_options => '-d') will result in:
        qesap.py terraform -d

    Execute qesap glue script commands. Check project documentation for available options:
    https://github.com/SUSE/qe-sap-deployment
    Test only returns execution result, failure has to be handled by calling method.
=cut

sub qesap_execute {
    my (%args) = @_;
    die 'QESAP command to execute undefined' unless $args{cmd};

    my $verbose = $args{verbose} ? "--verbose" : "";
    my %paths = qesap_get_file_paths();
    my $exec_log = "/tmp/qesap_exec_$args{cmd}_$args{cmd_options}.log.txt";
    $exec_log =~ s/[-\s]+/_/g;
    my $qesap_cmd = join(" ", $paths{deployment_dir} . "/scripts/qesap/qesap.py",
        $verbose,
        "-c", $paths{qesap_conf_trgt},
        "-b", $paths{deployment_dir},
        $args{cmd},
        $args{cmd_options},
        "|& tee -a",
        $exec_log
    );

    push(@log_files, $exec_log);
    record_info('QESAP exec', "Executing: \n$qesap_cmd");
    my $exec_rc = script_run($qesap_cmd, timeout => $args{timeout});
    qesap_upload_logs();
    return $exec_rc;
}

=head3 qesap_get_inventory

    Return the path of the generated inventory
=cut

sub qesap_get_inventory {
    my ($provider) = @_;
    my %paths = qesap_get_file_paths();
    return "$paths{deployment_dir}/terraform/" . lc $provider . '/inventory.yaml';
}

=head3 qesap_prepare_env

    qesap_prepare_env(variables=>{dict with variables}, provider => 'aws');

    Prepare terraform environment.
    - creates file structures
    - pulls git repository
    - external config files
    - installs pip requirements and OS packages
    - generates config files with qesap script

    For variables example see 'qesap_yaml_replace'
    Returns only result, failure handling has to be done by calling method.
=cut

sub qesap_prepare_env {
    my (%args) = @_;
    my $variables = $args{openqa_variables};
    my $provider = $args{provider};
    my %paths = qesap_get_file_paths();
    my $tfvars_template = get_var('QESAP_TFVARS_TEMPLATE');
    my $qesap_conf_src = "sles4sap/qe_sap_deployment/" . $paths{qesap_conf_filename};

    qesap_create_folder_tree();
    qesap_get_deployment_code();
    qesap_pip_install();

    # Copy tfvars template file if defined in parameters
    if (get_var('QESAP_TFVARS_TEMPLATE')) {
        record_info("QESAP tfvars template", "Preparing terraform template: \n" . $tfvars_template);
        assert_script_run('cd ' . $paths{terraform_dir} . '/' . $provider, quiet => 1);
        assert_script_run('cp ' . $tfvars_template . ' terraform.tfvars.template');
    }

    record_info("QESAP yaml", "Preparing yaml config file");
    assert_script_run('curl -v -L ' . data_url($qesap_conf_src) . ' -o ' . $paths{qesap_conf_trgt});
    qesap_yaml_replace(openqa_variables => $variables);
    push(@log_files, $paths{qesap_conf_trgt});

    record_info("QESAP conf", "Generating tfvars file");
    push(@log_files, $paths{terraform_dir} . '/' . $provider . "/terraform.tfvars");
    my $exec_rc = qesap_execute(cmd => 'configure', verbose => 1);
    qesap_upload_logs();
    die if $exec_rc != 0;
    return;
}

1;
