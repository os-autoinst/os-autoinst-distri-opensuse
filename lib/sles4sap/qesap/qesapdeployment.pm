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

    Copyright 2025 SUSE LLC
    SPDX-License-Identifier: FSFAP

=head1 AUTHORS

    QE SAP <qe-sap@suse.de>

=cut

package sles4sap::qesap::qesapdeployment;

use strict;
use warnings;
use Carp qw(croak);
use Mojo::JSON qw(decode_json);
use YAML::PP;
use NetAddr::IP;
use Exporter 'import';
use Scalar::Util 'looks_like_number';
use File::Basename;
use utils qw(file_content_replace script_retry);
use version_utils 'is_sle';
use publiccloud::utils qw(get_credentials detect_worker_ip);
use sles4sap::qesap::aws;
use sles4sap::qesap::azure;
use sles4sap::qesap::utils;
use sles4sap::azure_cli;
use mmapi 'get_current_job_id';
use testapi;


my @log_files = ();

# Terraform requirement that constrain QESAPDEPLOY_PREFIX value
#  terraform/azure/infrastructure.tf  "azurerm_storage_account" "mytfstorageacc"
# stdiag<PREFIX><JOB_ID> can only consist of lowercase letters and numbers,
# and must be between 3 and 24 characters long
use constant QESAPDEPLOY_PREFIX => 'qesapdep';

use constant QESAPDEPLOY_VENV => '/tmp/exec_venv';
use constant QESAPDEPLOY_PY_DEFAULT_VER => '3.11';

our @EXPORT = qw(
  qesap_upload_logs
  qesap_get_deployment_code
  qesap_get_roles_code
  qesap_get_inventory
  qesap_get_nodes_number
  qesap_get_nodes_names
  qesap_get_terraform_dir
  qesap_ansible_get_roles_dir
  qesap_prepare_env
  qesap_execute
  qesap_terraform_conditional_retry
  qesap_ansible_softfail
  qesap_ansible_cmd
  qesap_ansible_script_output_file
  qesap_ansible_script_output
  qesap_ansible_fetch_file
  qesap_ansible_reg_module
  qesap_ansible_create_section
  qesap_remote_hana_public_ips
  qesap_wait_for_ssh
  qesap_cluster_logs
  qesap_upload_crm_report
  qesap_supportconfig_logs
  qesap_save_y2logs
  qesap_add_server_to_hosts
  qesap_calculate_deployment_name
  qesap_export_instances
  qesap_import_instances
  qesap_aws_delete_leftover_tgw_attachments
  qesap_terraform_ansible_deploy_retry
  qesap_create_cidr_from_ip
  qesap_ssh_intrusion_detection
);

=head1 DESCRIPTION

    Package with common methods and default or constant values for qe-sap-deployment

=head2 Methods


=head3 qesap_get_file_paths

    Returns a hash containing file paths for configuration files
=cut

sub qesap_get_file_paths {
    my %paths;
    $paths{qesap_conf_filename} = get_required_var('QESAP_CONFIG_FILE');
    $paths{deployment_dir} = get_var('QESAP_DEPLOYMENT_DIR', '/root/qe-sap-deployment');
    $paths{terraform_dir} = get_var('PUBLIC_CLOUD_TERRAFORM_DIR', $paths{deployment_dir} . '/terraform');
    $paths{qesap_conf_trgt} = $paths{deployment_dir} . '/scripts/qesap/' . $paths{qesap_conf_filename};
    $paths{qesap_conf_src} = data_url('sles4sap/qe_sap_deployment/' . $paths{qesap_conf_filename});
    $paths{roles_dir} = get_var('QESAP_ROLES_DIR', '/root/community.sles-for-sap');
    $paths{roles_dir_path} = $paths{roles_dir} . '/roles';
    return (%paths);
}

=head3 qesap_create_folder_tree

    Create all needed folders
=cut

sub qesap_create_folder_tree {
    my %paths = qesap_get_file_paths();
    die 'Missing deployment_dir in paths' unless $paths{deployment_dir};
    assert_script_run("mkdir -p $paths{deployment_dir}", quiet => 1);
    die 'Missing roles_dir in paths' unless $paths{roles_dir};
    assert_script_run("mkdir -p $paths{roles_dir}", quiet => 1);
}

=head3 qesap_get_variables

    Scans yaml configuration for '%OPENQA_VARIABLE%' placeholders and
    searches for values in OpenQA defined variables.
    Returns hash with openqa variable key/value pairs.
=cut

sub qesap_get_variables {
    my %paths = qesap_get_file_paths();
    die "Missing mandatory qesap_conf_src from qesap_get_file_paths()" unless $paths{'qesap_conf_src'};
    my $yaml_file = $paths{'qesap_conf_src'};
    my %variables;
    my $cmd = join(' ',
        'curl -s -fL', $yaml_file, '|',
        'grep -v', "'#'", '|',
        'grep -oE %[A-Z0-9_]*%', '|',
        'sed s/%//g');

    for my $variable (split(" ", script_output($cmd))) {
        $variables{$variable} = get_required_var($variable);
    }
    return \%variables;
}

=head3 qesap_ansible_create_section

    Writes "ansible" section into yaml configuration file.
    $args{ansible_section} defines section(key) name.
    $args{section_content} defines content of names section.

    Example:
        @playbook_list = ("pre-cluster.yaml", "cluster_sbd_prep.yaml");
        qesap_ansible_create_section(ansible_section=>'create', section_content=>\@playbook_list);

=over

=item B<ANSILE_SECTION> - name of the yaml section within the ansible section
                          usually it is 'create', 'destroy' or 'hana_vars'

=item B<SECTION_CONTENT> - content as a perl hash

=back
=cut

sub qesap_ansible_create_section {
    my (%args) = @_;
    foreach (qw(ansible_section section_content)) {
        croak "Missing mandatory $_ argument" unless $args{$_}; }

    my %paths = qesap_get_file_paths();
    my $yaml_config_path = $paths{qesap_conf_trgt};
    assert_script_run("test -e $yaml_config_path",
        fail_message => "Yaml config file '$yaml_config_path' does not exist.");

    my $ypp = YAML::PP->new;
    my $raw_file = script_output("cat $yaml_config_path");
    my $yaml_data = $ypp->load_string($raw_file);

    die "Missing ansible section in $yaml_config_path" unless $yaml_data->{ansible};
    if ($yaml_data->{apiver} && (int($yaml_data->{apiver}) >= 4) && (grep { $_ eq $args{ansible_section} } ('create', 'destroy', 'test'))) {
        $yaml_data->{ansible}{sequences}{$args{ansible_section}} = $args{section_content};
    } else {
        $yaml_data->{ansible}{$args{ansible_section}} = $args{section_content};
    }

    # write into file
    my $yaml_dumped = $ypp->dump_string($yaml_data);
    save_tmp_file($paths{qesap_conf_filename}, $yaml_dumped);
    my $cmd = join(' ', 'curl', '-v',
        '-fL', autoinst_url . "/files/" . $paths{qesap_conf_filename},
        '-o', $paths{qesap_conf_trgt});
    assert_script_run($cmd);
    return;
}

=head3 qesap_venv_cmd_exec

    Run a command within the Python virtualenv
    created by qesap_pip_install.

    This function never dies: it always returns an error to the caller.
    Timeout error is 124 (the one reported by timeout command line utility).

=over

=item B<CMD> - command to run within the .venv, usually it is a qesap.py based command

=item B<TIMEOUT> - default 90 secs, has to be an integer greater than 0

=item B<LOG_FILE> - optional argument that results in changing the command to redirect the output to a log file

=item B<RETRY> - number of retry attempts, default is 1

=back
=cut

sub qesap_venv_cmd_exec {
    my (%args) = @_;
    croak 'Missing mandatory cmd argument' unless $args{cmd};
    $args{timeout} //= bmwqemu::scale_timeout(90);
    croak "Invalid timeout value $args{timeout}" unless $args{timeout} > 0;
    my $retry = $args{retry} // 1;

    my $cmd = $args{cmd};
    # pipefail is needed as at the end of the command line there could be a pipe
    # to redirect all output to a log_file.
    # pipefail allow script_run always getting the exit code of the cmd command
    # and not only the one from tee
    if ($args{log_file}) {
        script_run 'set -o pipefail';
        # always use tee in append mode
        $cmd .= " |& tee -a $args{log_file}";
    }

    my $ret = script_run('source ' . QESAPDEPLOY_VENV . '/bin/activate');
    if ($ret) {
        record_info('qesap_venv_cmd_exec error', "source .venv ret:$ret");
        return $ret;
    }
    $ret = script_retry($cmd, timeout => $args{timeout}, retry => $retry, die => 0);

    # deactivate python virtual environment
    script_run('deactivate');

    return $ret;
}

=head3 qesap_py

  Return string of the python to use
=cut

sub qesap_py {
    return 'python' . get_var('QESAP_PYTHON_VERSION', QESAPDEPLOY_PY_DEFAULT_VER);
}

=head3 qesap_pip

  Return string of the pip to use
=cut

sub qesap_pip {
    return 'pip' . get_var('QESAP_PIP_VERSION', QESAPDEPLOY_PY_DEFAULT_VER);
}

=head3 qesap_pip_install

  Install all Python requirements of the qe-sap-deployment
  in a dedicated virtual environment.
  This function has no return code but it is expected to die
  if something internally fails.
=cut

sub qesap_pip_install {
    my %paths = qesap_get_file_paths();
    my $pip_install_log = '/tmp/pip_install.txt';
    my $pip_ints_cmd = join(' ', qesap_pip(), 'install --no-color --no-cache-dir',
        '-r', "$paths{deployment_dir}/requirements.txt");

    # Create a Python virtualenv
    assert_script_run(join(' ', qesap_py(), '-m venv', QESAPDEPLOY_VENV));

    # Configure pip in it, ignore the return value
    # and does not provide any timeout as it should be
    # instantaneous
    qesap_venv_cmd_exec(cmd => qesap_pip() . ' config --site set global.progress_bar off');

    push(@log_files, $pip_install_log);
    record_info('QESAP repo', 'Installing all qe-sap-deployment python requirements');
    my $ret = qesap_venv_cmd_exec(
        cmd => $pip_ints_cmd,
        timeout => 720,
        retry => 3,
        log_file => $pip_install_log);

    # here it is possible to retry in case of exit code 124
    die "cmd:$pip_ints_cmd  --> ret:$ret" if $ret;
}


=head3 qesap_galaxy_install

  Install all Ansible requirements of the qe-sap-deployment.
  This function has no return code but it is expected to die
  if something internally fails.
=cut

sub qesap_galaxy_install {
    my %paths = qesap_get_file_paths();
    my $galaxy_install_log = '/tmp/galaxy_install.txt';

    my $ans_req = "$paths{deployment_dir}/requirements.yml";
    my $ans_galaxy_cmd = join(' ',
        'ansible-galaxy install',
        '-r', $ans_req);

    push(@log_files, $galaxy_install_log);
    my $ret = qesap_venv_cmd_exec(
        cmd => $ans_galaxy_cmd,
        timeout => 720,
        retry => 3,
        log_file => $galaxy_install_log);

    # here it is possible to retry in case of exit code 124
    die "cmd:$ans_galaxy_cmd  --> ret:$ret" if $ret;
}

=head3 qesap_upload_logs

    qesap_upload_logs([failok=1])

    Collect and upload logs present in @log_files.
    This is about logs generated locally on the jumphost.

=over

=item B<FAILOK> - used as failok for the upload_logs. continue even in case upload fails

=back
=cut

sub qesap_upload_logs {
    my (%args) = @_;
    $args{failok} //= 0;
    record_info("Uploading logfiles failok:$args{failok}", join("\n", @log_files));
    while (my $file = pop @log_files) {
        upload_logs($file, failok => $args{failok});
    }
}

=head3 qesap_get_deployment_code

    Get the qe-sap-deployment code
=cut

sub qesap_get_deployment_code {
    my $official_repo = 'github.com/SUSE/qe-sap-deployment';
    my $qesap_git_clone_log = '/tmp/git_clone.txt';
    my %paths = qesap_get_file_paths();
    die "Missing mandatory terraform_dir from qesap_get_file_paths()" unless $paths{'terraform_dir'};

    record_info('QESAP repo', 'Preparing qe-sap-deployment repository');

    enter_cmd("cd " . $paths{deployment_dir});
    push(@log_files, $qesap_git_clone_log);

    # Script from a release
    if (get_var('QESAP_INSTALL_VERSION')) {
        record_info('WARNING', 'QESAP_INSTALL_GITHUB_REPO will be ignored') if (get_var('QESAP_INSTALL_GITHUB_REPO'));
        record_info('WARNING', 'QESAP_INSTALL_GITHUB_BRANCH will be ignored') if (get_var('QESAP_INSTALL_GITHUB_BRANCH'));
        my $ver_artifact;
        if (check_var('QESAP_INSTALL_VERSION', 'latest')) {
            my $latest_release_url = "https://$official_repo/releases/latest";
            my $redirect_url = script_output("curl -s -L -o /dev/null -w %{url_effective} $latest_release_url");
            die "Failed to parse the latest version from $redirect_url" if ($redirect_url !~ /\/tag\/v([0-9.]+)$/);
            my $version = $1;
            $ver_artifact = "v$version.tar.gz";
            record_info("Version latest", "Latest QE-SAP-DEPLOYMENT release used: $version");
        }
        else {
            $ver_artifact = 'v' . get_var('QESAP_INSTALL_VERSION') . '.tar.gz';
        }

        my $curl_cmd = "curl -v -fL https://$official_repo/archive/refs/tags/$ver_artifact -o$ver_artifact";
        assert_script_run("set -o pipefail ; $curl_cmd | tee " . $qesap_git_clone_log, quiet => 1);

        my $tar_cmd = "tar xvf $ver_artifact --strip-components=1";
        assert_script_run($tar_cmd);
    }
    else {
        # Get the code for the qe-sap-deployment by cloning its repository
        assert_script_run('git config --global http.sslVerify false', quiet => 1) if get_var('QESAP_INSTALL_GITHUB_NO_VERIFY');
        my $git_branch = get_var('QESAP_INSTALL_GITHUB_BRANCH', 'main');

        my $git_repo = get_var('QESAP_INSTALL_GITHUB_REPO', $official_repo);
        my $git_clone_cmd = 'git clone --depth 1 --branch ' . $git_branch . ' https://' . $git_repo . ' ' . $paths{deployment_dir};
        assert_script_run("set -o pipefail ; $git_clone_cmd  |& tee $qesap_git_clone_log", quiet => 1);
    }
    # Add symlinks for different provider directory naming between OpenQA and qesap-deployment
    assert_script_run("ln -s " . $paths{terraform_dir} . "/aws " . $paths{terraform_dir} . "/ec2");
    assert_script_run("ln -s " . $paths{terraform_dir} . "/gcp " . $paths{terraform_dir} . "/gce");
}


=head3 qesap_get_roles_code
    Get the Ansible roles code from github.com/sap-linuxlab/community.sles-for-sap

    Keep in mind that to allow qe-sap-deployment to use roles from this repo,
    your config.yaml has to have a specific setting ansible::roles_path.
=cut

sub qesap_get_roles_code {
    my $official_repo = 'github.com/sap-linuxlab/community.sles-for-sap';
    my $roles_git_clone_log = '/tmp/git_clone_roles.txt';
    my %paths = qesap_get_file_paths();

    record_info('SLES4SAP Roles repo', 'Preparing community.sles-for-sap repository');

    enter_cmd("cd " . $paths{roles_dir});
    push(@log_files, $roles_git_clone_log);

    # Script from a release
    if (get_var('QESAP_ROLES_INSTALL_VERSION')) {
        die('community.sles-for-sap does not implement releases yet.');
    }
    else {
        # Get the code for the community.sles-for-sap by cloning its repository
        assert_script_run('git config --global http.sslVerify false', quiet => 1) if get_var('QESAP_INSTALL_GITHUB_NO_VERIFY');
        my $git_branch = get_var('QESAP_ROLES_INSTALL_GITHUB_BRANCH', 'main');

        my $git_repo = get_var('QESAP_ROLES_INSTALL_GITHUB_REPO', $official_repo);
        my $git_clone_cmd = join(' ', 'git clone',
            '--depth 1',
            "--branch $git_branch",
            'https://' . $git_repo,
            $paths{roles_dir});
        assert_script_run("set -o pipefail ; $git_clone_cmd |& tee $roles_git_clone_log", quiet => 1);
    }
}

=head3 qesap_yaml_replace

    Replaces yaml configuration file variables with parameters
    defined by OpenQA test code, yaml template or yaml schedule.
    Openqa variables need to be added as a hash
    with key/value pair inside %run_args{openqa_variables}.
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

=head3 qesap_execute

    qesap_execute(
        cmd => '<configure|terraform,|ansible>',
        logname => '<SOMENAME>.log.txt'
        [, verbose => 1, cmd_options => <cmd_options>] );

    Example:
        qesap_execute(cmd => 'terraform', logname => 'terraform_destroy.log.txt', cmd_options => '-d')
    result in:
        qesap.py terraform -d

    Execute qesap glue script commands. Check project documentation for available options:
    https://github.com/SUSE/qe-sap-deployment
    Function returns a two element array:
      - first element is an integer representing the execution result
      - second element is the file path of the execution log
    This function is not expected to internally die, any failure has to be handled by the caller.

=over

=item B<CMD> - qesap.py subcommand to run

=item B<LOGNAME> - filename of the log file. This file will be saved in `/tmp` folder

=item B<CMD_OPTIONS> - set of arguments for the qesap.py subcommand

=item B<VERBOSE> - activate verbosity in qesap.py. 0 is no verbosity (default), 1 is to enable verbosity

=item B<TIMEOUT> - max expected execution time, default 90sec

=back
=cut

sub qesap_execute {
    my (%args) = @_;
    foreach (qw(cmd logname)) { croak "Missing mandatory $_ argument" unless $args{$_}; }

    my $verbose = $args{verbose} ? "--verbose" : "";
    $args{cmd_options} //= '';
    $args{timeout} //= bmwqemu::scale_timeout(90);

    my %paths = qesap_get_file_paths();
    my $exec_log = '/tmp/' . $args{logname};

    my $qesap_cmd = join(' ', qesap_py(), $paths{deployment_dir} . '/scripts/qesap/qesap.py',
        $verbose,
        '-c', $paths{qesap_conf_trgt},
        '-b', $paths{deployment_dir},
        $args{cmd},
        $args{cmd_options});

    push(@log_files, $exec_log);
    record_info("QESAP exec $args{cmd}", "Executing: \n$qesap_cmd \n\nlog to $exec_log");

    my $exec_rc = qesap_venv_cmd_exec(
        cmd => $qesap_cmd,
        timeout => $args{timeout},
        log_file => $exec_log);

    my @qesap_logs;

    # look for logs produced directly by the qesap.py
    my $qesap_log_find = 'find . -type f -name "*.log.txt"';
    foreach my $log (split(/\n/, script_output($qesap_log_find, proceed_on_failure => 1))) {
        push(@log_files, $log);
        # Also record them in a dedicated list
        # to be able to delete them as soon as they are uploaded.
        # It is needed to not create duplicated uploads
        # from different deployment stages (terraform, ansible, destroy, retry, ...)
        push(@qesap_logs, $log);
    }

    qesap_upload_logs();

    foreach (@qesap_logs) {
        enter_cmd("rm -f $_");
    }

    my @results = ($exec_rc, $exec_log);
    return @results;
}

=head3 qesap_terraform_conditional_retry

    qesap_terraform_conditional_retry(
        error_list => ['Fatal:'],
        logname => 'somefile.txt'
        [, verbose => 1, cmd_options => '--parallel 3', timeout => 1200, retries => 5, destroy => 1, delay_sec => 6, random_factor => 0.3] );

    Executes 'qesap.py ... terraform' and provides a robust retry mechanism for transient
    cloud provider errors. The primary motivation is to avoid a slow and brittle
    destroy-and-recreate cycle for sporadic issues, such as an Azure API timeout like
    "InternalExecutionError: An internal execution error occurred. Please retry later.".

    Upon detecting a recoverable error from the `error_list`, the function waits for a
    randomized backoff period and then re-executes the 'terraform plan' and 'apply'
    commands. This approach works because the 'plan' command implicitly refreshes the
    state from the cloud, detecting any drift or partially completed operations. This
    allows Terraform to intelligently correct the state on the next apply, rather than
    starting from scratch.

    The function returns its execution result in the same format as `qesap_execute`.

=over

=item B<ERROR_LIST> - list of error strings to search for in the log file. If any is found, it enables terraform retry

=item B<LOGNAME> - filename of the log file.

=item B<CMD_OPTIONS> - set of arguments for the qesap.py subcommand

=item B<TIMEOUT> - max expected execution time, default 90sec

=item B<RETRIES> - number of retries in case of expected error

=item B<VERBOSE> - activate verbosity in qesap.py. 0 is no verbosity (default), 1 is to enable verbosity

=item B<DESTROY> - destroy terraform before retrying terraform apply

=item B<DELAY_SEC> - seconds of delay before retry

=item B<RANDOM_FACTOR> - random factor for delay to avoid concurrent retries. 0 is no random factor, 1 is max random factor.

=back
=cut

sub qesap_terraform_conditional_retry {
    my (%args) = @_;
    foreach (qw(error_list logname)) { croak "Missing mandatory $_ argument" unless $args{$_}; }

    $args{timeout} //= bmwqemu::scale_timeout(90);
    $args{retries} //= 3;
    my $retries_count = $args{retries};
    $args{delay_sec} //= 60;
    $args{random_factor} //= 0.3;
    $args{random_factor} = 1 if $args{random_factor} > 1;
    $args{random_factor} = 0 if $args{random_factor} < 0;
    my %exec_args = (
        cmd => 'terraform',
        verbose => $args{verbose},
        timeout => $args{timeout},
        logname => $args{logname}
    );
    $exec_args{cmd_options} = $args{cmd_options} if $args{cmd_options};

    my @ret = qesap_execute(%exec_args);

    while ($retries_count > 0) {
        # Stop re-trying as soon as it PASS
        return @ret if ($ret[0] == 0);

        # Immediately fails if the output does not have one of the errors indicated by the caller
        return @ret if (!qesap_file_find_strings(file => $ret[1], search_strings => $args{error_list}));
        record_info('DETECTED ERROR', "Retrying (left: $retries_count)");

        # Wait and retry terraform apply
        my $base = $args{delay_sec};
        my $fractional_diff = int($base * $args{random_factor});
        my $rand_delay = $fractional_diff ? (int(rand(2 * $fractional_diff + 1)) - $fractional_diff) : 0;
        my $sleep_sec = $base + $rand_delay;
        $sleep_sec = 0 if $sleep_sec < 0;
        record_info('BACKOFF', "Sleeping ${sleep_sec}s before retry");
        sleep $sleep_sec if $sleep_sec > 0;

        # Optionally destroy before retry
        if ($args{destroy}) {
            my @destroy_ret = qesap_execute(
                cmd => 'terraform',
                cmd_options => '-d',
                logname => "qesap_exec_terraform_destroy_before_retry$retries_count.log.txt",
                verbose => 1,
                timeout => 1200
            );
            return @destroy_ret if ($destroy_ret[0] != 0);
        }

        $exec_args{logname} = 'qesap_terraform_retry_' . ($args{retries} - $retries_count) . '.log.txt';
        @ret = qesap_execute(%exec_args);

        $retries_count--;
    }

    return @ret;
}

=head3 qesap_file_find_strings

    Search for a list of strings in the Ansible log file.
    Returns 1 if any of the strings are found in the log file, 0 otherwise.

=over

=item B<FILE> - Path to the Ansible log file. (Required)

=item B<SEARCH_STRINGS> - Array of strings to search for in the log file. (Required)

=back
=cut

sub qesap_file_find_strings {
    my (%args) = @_;
    foreach (qw(file search_strings)) {
        croak "Missing mandatory $_ argument" unless $args{$_};
    }

    for my $s (@{$args{search_strings}}) {
        my $ret = script_run("grep \"$s\" $args{file}");
        return 1 if $ret == 0;
    }
    return 0;
}

=head3 qesap_get_inventory

    Return the path of the generated inventory

=over

=item B<PROVIDER> - Cloud provider name using same format of PUBLIC_CLOUD_PROVIDER setting

=back
=cut

sub qesap_get_inventory {
    my (%args) = @_;
    croak "Missing mandatory argument 'provider'" unless $args{provider};
    my %paths = qesap_get_file_paths();
    return join('/', qesap_get_terraform_dir(provider => $args{provider}), 'inventory.yaml');
}

=head3 qesap_get_nodes_number

Get the number of cluster nodes from the inventory.yaml

=over

=item B<PROVIDER> - Cloud provider name using same format of PUBLIC_CLOUD_PROVIDER setting

=back
=cut

sub qesap_get_nodes_number {
    my (%args) = @_;
    croak "Missing mandatory argument 'provider'" unless $args{provider};
    my $inventory = qesap_get_inventory(provider => $args{provider});
    my $yp = YAML::PP->new();

    my $inventory_content = script_output("cat $inventory");
    my $parsed_inventory = $yp->load_string($inventory_content);
    my $num_hosts = 0;
    while ((my $key, my $value) = each(%{$parsed_inventory->{all}->{children}})) {
        $num_hosts += keys %{$value->{hosts}};
    }
    return $num_hosts;
}

=head3 qesap_get_nodes_names

Get the cluster nodes' names from the inventory.yaml

=over

=item B<PROVIDER> - Cloud provider name using same format of PUBLIC_CLOUD_PROVIDER setting

=back
=cut

sub qesap_get_nodes_names {
    my (%args) = @_;
    croak "Missing mandatory argument 'provider'" unless $args{provider};
    my $inventory = qesap_get_inventory(provider => $args{provider});
    my $yp = YAML::PP->new();

    my $inventory_content = script_output("cat $inventory");
    my $parsed_inventory = $yp->load_string($inventory_content);
    my @hosts;
    while ((my $key, my $value) = each(%{$parsed_inventory->{all}->{children}})) {
        if (exists $value->{hosts}) {
            push @hosts, keys %{$value->{hosts}};
        }
    }
    return @hosts;
}

=head3 qesap_get_terraform_dir

    Return the path used by the qesap script as -chdir argument for terraform
    It is useful if test would like to call terraform

=over

=item B<PROVIDER> - Cloud provider name using same format of PUBLIC_CLOUD_PROVIDER setting

=back
=cut

sub qesap_get_terraform_dir {
    my (%args) = @_;
    croak "Missing mandatory argument 'provider'" unless $args{provider};
    my %paths = qesap_get_file_paths();
    return join('/', $paths{terraform_dir}, lc $args{provider});
}

=head3 qesap_ansible_get_roles_dir

    Return the path where sap-linuxlab/community.sles-for-sap
    has been installed
=cut

sub qesap_ansible_get_roles_dir {
    my %paths = qesap_get_file_paths();
    return $paths{roles_dir_path};
}

=head3 qesap_prepare_env

    qesap_prepare_env(variables=>{dict with variables}, provider => 'aws');

    Prepare terraform environment.
    - creates file structures
    - pulls git repository
    - external configuration files
    - installs pip requirements and OS packages
    - generates configuration files with qesap script

    For variables example see 'qesap_yaml_replace'
    Returns only result, failure handling has to be done by calling method.

=over

=item B<PROVIDER> - Cloud provider name, used to optionally activate AWS credential code

=item B<REGION> - only needed when provider value is EC2

=item B<OPENQA_VARIABLES> -

=item B<ONLY_CONFIGURE> -

=back
=cut

sub qesap_prepare_env {
    my (%args) = @_;
    croak "Missing mandatory argument 'provider'" unless $args{provider};
    croak "Missing mandatory argument 'region' when 'provider' is EC2" if (($args{provider} eq 'EC2') && !$args{region});

    my $variables = $args{openqa_variables} ? $args{openqa_variables} : qesap_get_variables();
    my $provider_folder = lc $args{provider};
    my %paths = qesap_get_file_paths();
    die "Missing mandatory deployment_dir from qesap_get_file_paths()" unless $paths{'deployment_dir'};
    die "Missing mandatory qesap_conf_trgt from qesap_get_file_paths()" unless $paths{'qesap_conf_trgt'};

    # Option to skip straight to configuration
    unless ($args{only_configure}) {
        die "Missing mandatory qesap_conf_src from qesap_get_file_paths()" unless $paths{'qesap_conf_src'};
        qesap_create_folder_tree();
        qesap_get_deployment_code();
        qesap_get_roles_code();
        qesap_pip_install();
        # for the moment run it only conditionally
        # to allow this test code also to work with older
        # qe-sap-deployment versions
        qesap_galaxy_install() if (script_run("test -e $paths{deployment_dir}/requirements.yml") == 0);

        record_info('QESAP yaml', 'Preparing yaml config file');
        assert_script_run('curl -v -fL ' . $paths{qesap_conf_src} . ' -o ' . $paths{qesap_conf_trgt});
    }

    qesap_yaml_replace(openqa_variables => $variables);
    push(@log_files, $paths{qesap_conf_trgt});

    record_info('QESAP conf', 'Generating all terraform and Ansible configuration files');
    my $terraform_tfvars = join('/',
        qesap_get_terraform_dir(provider => $args{provider}),
        'terraform.tfvars');
    push(@log_files, $terraform_tfvars);
    my $hana_media = "$paths{deployment_dir}/ansible/playbooks/vars/hana_media.yaml";
    my $hana_vars = "$paths{deployment_dir}/ansible/playbooks/vars/hana_vars.yaml";
    my @exec_rc = qesap_execute(cmd => 'configure', logname => 'qesap_configure.log.txt', verbose => 1);

    if ($args{provider} eq 'EC2') {
        my $data = get_credentials(url_suffix => 'aws.json');
        qesap_aws_create_config(region => $args{region});
        qesap_aws_create_credentials(
            conf_trgt => $paths{qesap_conf_trgt},
            key => $data->{access_key_id},
            secret => $data->{secret_access_key});
    }

    push(@log_files, $hana_media) if (script_run("test -e $hana_media") == 0);
    push(@log_files, $hana_vars) if (script_run("test -e $hana_vars") == 0);
    qesap_upload_logs(failok => 1);
    die("Qesap deployment returned non zero value during 'configure' phase.") if $exec_rc[0];
}

=head3 qesap_ansible_softfail

    qesap_ansible_softfail(logfile => '/tmp/ansible.log.txt' )

    Call record_soft_failure if a conventional message is detected in the ansible log
    from qe-sap-deployment (check the README of it).
    This function does not return anything.

=over

=item B<LOGFILE> - Filename of the log produced by 'qesap.py ansible'

=back
=cut

sub qesap_ansible_softfail {
    my (%args) = @_;
    croak 'Missing mandatory logfile argument' unless $args{logfile};
    # use grep as the log is huge
    my $ansible_output = script_output(
        'grep -E "\[OSADO\]\[softfail\] ([a-zA-Z]+#\S+) (.*)" ' . $args{logfile},
        proceed_on_failure => 1);
    my $reference;
    foreach my $ansible_line (split /\n/, $ansible_output) {
        chomp $ansible_line;
        if ($ansible_line =~ qr/\[OSADO\]\[softfail\] ([a-zA-Z]+#\S+) (.*)/) {
            # Using a variable named $reference is needed to pass test-soft_failure-no-reference.
            # Refer to CONTRIBUTING.md
            $reference = $1;
            record_soft_failure("$reference - $2");
        }
    }
}

=head3 qesap_ansible_get_playbook

    Download the playbook from the test code repo
    that is on the worker within the running JompHost.

=cut

sub qesap_ansible_get_playbook {
    my (%args) = @_;
    croak 'Missing mandatory playbook argument' unless $args{playbook};
    if (script_run("test -e $args{playbook}")) {
        my $cmd = join(' ',
            'curl', '-v', '-fL',
            data_url("sles4sap/$args{playbook}"),
            '-o', $args{playbook});
        assert_script_run($cmd);
    }
}

=head3 qesap_ansible_cmd

    Use Ansible to run a command remotely on some or all
    the hosts from the inventory.yaml

=over

=item B<PROVIDER> - Cloud provider name, used to find the inventory

=item B<CMD> - command to run remotely

=item B<USER> - user on remote host, default to 'cloudadmin'

=item B<FILTER> - filter hosts in the inventory

=item B<FAILOK> - if not set, Ansible failure result in die

=item B<HOST_KEYS_CHECK> - if set, add some extra argument to the Ansible call
                           to allow contacting hosts not in the  KnownHost list yet.
                           This enables the use of this api before the call to qesap.py ansible

=item B<TIMEOUT> - default 90 secs

=item B<VERBOSE> - enable verbosity, default is OFF

=back
=cut

sub qesap_ansible_cmd {
    my (%args) = @_;
    foreach (qw(provider cmd)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{user} //= 'cloudadmin';
    $args{filter} //= 'all';
    $args{timeout} //= bmwqemu::scale_timeout(90);
    $args{failok} //= 0;
    my $verbose = $args{verbose} ? ' -vv' : '';

    my $inventory = qesap_get_inventory(provider => $args{provider});
    record_info('Ansible cmd:', "Run on '$args{filter}' node\ncmd: '$args{cmd}'");

    my $ansible_cmd = join(' ',
        'ansible' . $verbose,
        $args{filter},
        '-i', $inventory,
        '-u', $args{user},
        '-b', '--become-user=root',
        '-a', "\"$args{cmd}\"");

    $ansible_cmd = $args{host_keys_check} ?
      join(' ', $ansible_cmd,
        '-e',
        "'ansible_ssh_common_args=\"-o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new\"'") :
      $ansible_cmd;

    my $ret = qesap_venv_cmd_exec(cmd => $ansible_cmd, timeout => $args{timeout});

    die "cmd: $ansible_cmd ret: $ret" if ($ret && !$args{failok});
}

=head3 qesap_ansible_script_output_file

    Use Ansible to run a command remotely and get the stdout.
    Command could be executed with elevated privileges

    qesap_ansible_script_output_file(cmd => 'crm status', provider => 'aws', host => 'vmhana01', root => 1);

    It uses playbook data/sles4sap/script_output.yaml

    1. ansible-playbook runs the playbook
    2. the playbook executes the command remotely and redirects the output to file, both remotely
    3. qesap_ansible_fetch_file downloads the file locally
    4. the file is read and stored to be returned to the caller

    Return is the local full path of the file containing the output of the
    remotely executed command.

=over

=item B<PROVIDER> - Cloud provider name, used to find the inventory

=item B<CMD> - command to run remotely

=item B<HOST> - filter hosts in the inventory

=item B<FILE> - result file name

=item B<REMOTE_PATH> - Path to save file in the remote (without file name)

=item B<OUT_PATH> - path to save result file locally (without file name)

=item B<USER> - user on remote host, default to 'cloudadmin'

=item B<ROOT> - 1 to enable remote execution with elevated user, default to 0

=item B<FAILOK> - if not set, Ansible failure result in die

=item B<VERBOSE> - 1 result in ansible-playbook to be called with '-vv', default is 0.

=item B<TIMEOUT> - max expected execution time, default 180sec.
    Same timeout is used both for the execution of script_output.yaml and for the fetch_file.
    Timeout of the same amount is started two times.

=back
=cut

sub qesap_ansible_script_output_file {
    my (%args) = @_;
    foreach (qw(provider cmd host)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{user} //= 'cloudadmin';
    $args{root} //= 0;
    $args{failok} //= 0;
    $args{timeout} //= bmwqemu::scale_timeout(180);
    $args{verbose} //= 0;
    my $verbose = $args{verbose} ? '-vv' : '';
    $args{remote_path} //= '/tmp/';
    $args{out_path} //= '/tmp/ansible_script_output/';
    $args{file} //= 'testout.txt';

    my $inventory = qesap_get_inventory(provider => $args{provider});
    my $playbook = 'script_output.yaml';
    qesap_ansible_get_playbook(playbook => $playbook);

    my @ansible_cmd = ('ansible-playbook', $verbose, $playbook);
    push @ansible_cmd, ('-l', $args{host}, '-i', $inventory, '-u', $args{user});
    push @ansible_cmd, ('-b', '--become-user', 'root') if ($args{root});
    push @ansible_cmd, ('-e', qq("cmd='$args{cmd}'"),
        '-e', "out_file='$args{file}'", '-e', "remote_path='$args{remote_path}'");
    push @ansible_cmd, ('-e', "failok=yes") if ($args{failok});

    my $ret = qesap_venv_cmd_exec(cmd => join(' ', @ansible_cmd),
        timeout => $args{timeout});
    die "ret: $ret" if ($ret && !$args{failok});

    # Grab the file from the remote
    return qesap_ansible_fetch_file(provider => $args{provider},
        host => $args{host},
        failok => $args{failok},
        user => $args{user},
        root => $args{root},
        remote_path => $args{remote_path},
        out_path => $args{out_path},
        file => $args{file},
        timeout => $args{timeout},
        verbose => $args{verbose});
}

=head3 qesap_ansible_script_output

    Return the output of a command executed on the remote machine via Ansible.

=over

=item B<PROVIDER> - Cloud provider name, used to find the inventory

=item B<CMD> - command to run remotely

=item B<HOST> - filter hosts in the inventory

=item B<USER> - user on remote host, default to 'cloudadmin'

=item B<ROOT> - 1 to enable remote execution with elevated user, default to 0

=item B<FAILOK> - if not set, Ansible failure result in die

=item B<TIMEOUT> - max expected execution time

=item B<FILE> - result file name

=item B<OUT_PATH> - path to save result file locally (without file name)

=item B<REMOTE_PATH> - Path to save file in the remote (without file name)

=back
=cut

sub qesap_ansible_script_output {
    my (%args) = @_;
    foreach (qw(provider cmd host)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{user} //= 'cloudadmin';
    $args{root} //= 0;
    $args{failok} //= 0;
    $args{remote_path} //= '/tmp/';
    $args{out_path} //= '/tmp/ansible_script_output/';
    $args{file} //= 'testout.txt';

    # Grab command output as file
    my $local_tmp = qesap_ansible_script_output_file(cmd => $args{cmd},
        provider => $args{provider},
        host => $args{host},
        failok => $args{failok},
        user => $args{user},
        root => $args{root},
        remote_path => $args{remote_path},
        out_path => $args{out_path},
        file => $args{file},
        timeout => $args{timeout});
    # Print output and delete output file
    my $output = script_output("cat $local_tmp");
    enter_cmd("rm $local_tmp || echo 'Nothing to delete'");
    return $output;
}

=head3 qesap_ansible_fetch_file

    Use Ansible to fetch a file from remote.
    Command could be executed with elevated privileges

    qesap_ansible_fetch_file(provider => 'aws', host => 'vmhana01', root => 1);

    It uses playbook data/sles4sap/fetch_file.yaml

    1. ansible-playbook run the playbook
    3. the playbook download the file locally
    4. the file is read and stored to be returned to the caller

    Return the local path of the downloaded file.

=over

=item B<PROVIDER> - Cloud provider name, used to find the inventory

=item B<HOST> - filter hosts in the inventory

=item B<REMOTE_PATH> - path to find file in the remote (without file name)

=item B<USER> - user on remote host, default to 'cloudadmin'

=item B<ROOT> - 1 to enable remote execution with elevated user, default to 0

=item B<FAILOK> - if not set, Ansible failure result in die

=item B<TIMEOUT> - max expected execution time, default 180sec

=item B<FILE> - file name of the local copy of the file

=item B<OUT_PATH> - path to save file locally (without file name)

=item B<VERBOSE> - 1 result in ansible-playbook to be called with '-vv', default is 0.

=back
=cut

sub qesap_ansible_fetch_file {
    my (%args) = @_;
    foreach (qw(provider host remote_path)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{user} //= 'cloudadmin';
    $args{root} //= 0;
    $args{failok} //= 0;
    $args{timeout} //= bmwqemu::scale_timeout(180);
    $args{out_path} //= '/tmp/ansible_script_output/';
    $args{file} //= 'testout.txt';
    $args{verbose} //= 0;
    my $verbose = $args{verbose} ? '-vv' : '';

    my $inventory = qesap_get_inventory(provider => $args{provider});
    my $fetch_playbook = 'fetch_file.yaml';

    qesap_ansible_get_playbook(playbook => $fetch_playbook);

    my @ansible_fetch_cmd = ('ansible-playbook', $verbose, $fetch_playbook);
    push @ansible_fetch_cmd, ('-l', $args{host}, '-i', $inventory);
    push @ansible_fetch_cmd, ('-u', $args{user});
    push @ansible_fetch_cmd, ('-b', '--become-user', 'root') if ($args{root});
    push @ansible_fetch_cmd, ('-e', "local_path='$args{out_path}'",
        '-e', "remote_path='$args{remote_path}'",
        '-e', "file='$args{file}'");
    push @ansible_fetch_cmd, ('-e', "failok=yes") if ($args{failok});

    my $ret = qesap_venv_cmd_exec(
        cmd => join(' ', @ansible_fetch_cmd),
        timeout => $args{timeout});
    die "ret: $ret" if ($ret && !$args{failok});

    # reflect the same logic implement in the playbook
    return $args{out_path} . $args{file};
}

=head3 qesap_ansible_reg_module

    Compose the ansible-playbook argument for the registration.yaml playbook,
    about an additional module registration

    -e sles_modules='[{"key":"SLES-LTSS-Extended-Security/12.5/x86_64","value":"*******"}]'

    Known limitation is that registration.yaml supports multiple modules to be registered,
    this code only supports one.

=over
=item B<reg> - name and reg_code for the additional extension to register.
                This argument is a two element comma separated list string.
                Like: 'SLES-LTSS-Extended-Security/12.5/x86_64,123456789'
                First string before the comma has to be a valid SCC extension name, later used by Ansible
                as argument for SUSEConnect or registercloudguest argument.
                Second string has to be valid registration code for the particular extension.

=back
=cut

sub qesap_ansible_reg_module {
    my (%args) = @_;
    croak 'Missing mandatory "reg" argument' unless $args{reg};
    my @reg_args = split(/,/, $args{reg});
    die "Missing reg_code for '$reg_args[0]'" if (@reg_args != 2);
    return "-e sles_modules='[{" .
      "\"key\":\"$reg_args[0]\"," .
      "\"value\":\"$reg_args[1]\"}]'";
}

=head3 qesap_remote_hana_public_ips

    Return a list of the public IP addresses of the systems
    deployed by qe-sap-deployment, as reported by C<terraform output>.
    Needs to run after C<qesap_execute(cmd => 'terraform');> call.

=cut

sub qesap_remote_hana_public_ips {
    my $tfdir = qesap_get_terraform_dir(provider => get_required_var('PUBLIC_CLOUD_PROVIDER'));
    my $data = decode_json(script_output "terraform -chdir=$tfdir output -json");
    return @{$data->{hana_public_ip}->{value}};
}

=head3 qesap_wait_for_ssh

  Probe specified port on the remote host each 5sec till response.
  Return -1 in case of timeout
  Return total time of retry loop in case of pass.

=over

=item B<HOST> - IP of the host to probe

=item B<TIMEOUT> - time to wait before to give up, default is 10mins

=item B<PORT> - port to probe, default is 22

=back
=cut

sub qesap_wait_for_ssh {
    my (%args) = @_;
    croak 'Missing mandatory host argument' unless $args{host};
    $args{timeout} //= bmwqemu::scale_timeout(600);
    $args{port} //= 22;

    my $start_time = time();
    my $check_port = 1;

    # Looping until reaching timeout or passing two conditions :
    # - SSH port 22 is reachable
    # - journalctl got message about reaching one of certain targets
    my $cmd = join(' ', 'nc', '-vz', '-w', '1', $args{host}, $args{port});
    while ((my $duration = time() - $start_time) < $args{timeout}) {
        return $duration if (script_run($cmd, quiet => 1) == 0);
        sleep 5;
    }

    return -1;
}

=head3 qesap_upload_crm_report

    Run crm report on a host and upload the resulting tarball to openqa

=over

=item B<HOST> - host to get the report from

=item B<PROVIDER> - Cloud provider name, used to find the inventory

=item B<FAILOK> - if not set, Ansible failure result in die

=back
=cut

sub qesap_upload_crm_report {
    my (%args) = @_;
    foreach (qw(provider host)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{failok} //= 0;

    my $log_filename = "$args{host}-crm_report";

    if ($log_filename =~ /hana\[(\d+)\]/) {
        my $number = $1 + 1;
        $log_filename = "vmhana0${number}-crm_report";
    }
    $log_filename =~ s/[\[\]"]//g;

    my $crm_log = "/var/log/$log_filename";
    my $crm_log_postfix = is_sle('15+') ? 'tar.gz' : 'tar.bz2';
    my $report_opt = !is_sle('12-sp4+') ? '-f0' : '';
    qesap_ansible_cmd(cmd => "crm report $report_opt -E /var/log/ha-cluster-bootstrap.log $crm_log",
        provider => $args{provider},
        filter => "\"$args{host}\"",
        host_keys_check => 1,
        verbose => 1,
        timeout => bmwqemu::scale_timeout(180),
        failok => $args{failok});
    my $local_path = qesap_ansible_fetch_file(provider => $args{provider},
        host => $args{host},
        failok => $args{failok},
        root => 1,
        remote_path => '/var/log/',
        out_path => '/tmp/ansible_script_output/',
        file => "$log_filename" . '.' . "$crm_log_postfix",
        verbose => 1);
    upload_logs($local_path, failok => 1);
}

=head3 qesap_upload_supportconfig_logs

    Generate supportconfig log on a host and upload the resulting tarball to openqa

=over

=item B<HOST> - host to get the report from

=item B<PROVIDER> - Cloud provider name, used to find the inventory

=item B<FAILOK> - if not set, Ansible failure result in die

=back
=cut

sub qesap_upload_supportconfig_logs {
    my (%args) = @_;
    foreach (qw(provider host)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{failok} //= 0;

    my $log_filename = "$args{host}-supportconfig_log";

    if ($log_filename =~ /hana\[(\d+)\]/) {
        my $number = $1 + 1;
        $log_filename = "vmhana0${number}-supportconfig_log";
    }
    $log_filename =~ s/[\[\]"]//g;

    qesap_ansible_cmd(cmd => "sudo supportconfig -R /var/tmp -B $log_filename -x AUDIT",
        provider => $args{provider},
        filter => "\"$args{host}\"",
        host_keys_check => 1,
        verbose => 1,
        timeout => bmwqemu::scale_timeout(600),
        failok => $args{failok});
    qesap_ansible_cmd(cmd => "sudo chmod 755 /var/tmp/scc_$log_filename.txz",
        provider => $args{provider},
        filter => "\"$args{host}\"",
        host_keys_check => 1,
        verbose => 1,
        timeout => bmwqemu::scale_timeout(60),
        failok => $args{failok});
    my $local_path = qesap_ansible_fetch_file(provider => $args{provider},
        host => $args{host},
        failok => $args{failok},
        root => 1,
        remote_path => '/var/tmp/',
        out_path => '/tmp/ansible_script_output/',
        file => "scc_$log_filename.txz",
        verbose => 1);
    upload_logs($local_path, failok => 1);
}

=head3 qesap_cluster_log_cmds

  List of commands to collect logs from a deployed cluster

=over

=item B<PROVIDER> - Cloud provider name, used to find the inventory

=back
=cut

sub qesap_cluster_log_cmds {
    my (%args) = @_;
    croak "Missing mandatory 'provider' argument" unless $args{provider};
    # Many logs does not need to be in this list as collected with `crm report` as:
    # `crm status`, `crm configure show`, `journalctl -b`,
    # `systemctl status sbd`, `corosync.conf` and `csync2`
    my @log_list = (
        {
            Cmd => 'lsblk -i -a',
            Output => 'lsblk.txt',
        },
        {
            Cmd => 'lsscsi -i',
            Output => 'lsscsi.txt',
        },
        {
            Cmd => 'cat /var/tmp/hdbinst.log',
            Output => 'hdbinst.log.txt',
        },
        {
            Cmd => '(cd /var/tmp ; tar -zcf - hdb_* *.trc)',
            Output => 'hdb_hdblcm_install.tar.gz',
        },
        {
            Cmd => 'cat /var/tmp/hdblcm.log',
            Output => 'hdblcm.log.txt',
        },
        {
            Cmd => 'cat /var/log/zypper.log',
            Output => 'zypper.log.txt',
        },
        {
            Cmd => 'cat /var/log/zypp/history',
            Output => 'zypp.history.txt',
        },
        {
            Cmd => 'cat /var/log/cloudregister',
            Output => 'cloudregister.txt',
        },
        {
            Cmd => 'rpm -qa',
            Output => 'rpm-qa.txt',
        }
    );
    if ($args{provider} eq 'EC2') {
        push @log_list, {
            Cmd => 'cat ~/.aws/config > aws_config.txt',
            Output => 'aws_config.txt',
        };
    }
    elsif ($args{provider} eq 'AZURE') {
        push @log_list, {
            Cmd => 'cat /var/log/cloud-init.log > azure_cloud_init_log.txt',
            Output => 'azure_cloud_init_log.txt',
        };
    }
    return @log_list;
}

=head3 qesap_cluster_logs

  Collect logs from a deployed cluster.
  This is about logs generated remotely on the two HANA nodes,
  `crm report` collection is part of this function.
=cut

sub qesap_cluster_logs {
    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my $inventory = qesap_get_inventory(provider => $provider);

    # return != 0 means no inventory
    return if (script_run("test -e $inventory", 60));
    foreach my $host ('hana[0]', 'hana[1]') {
        foreach my $cmd (qesap_cluster_log_cmds(provider => $provider)) {
            my $log_filename = "$host-$cmd->{Output}";
            $log_filename =~ s/[\[\]"]//g;
            my $out = qesap_ansible_script_output_file(cmd => $cmd->{Cmd},
                provider => $provider,
                host => $host,
                failok => 1,
                root => 1,
                remote_path => '/tmp/',
                out_path => '/tmp/ansible_script_output/',
                file => $log_filename);
            upload_logs($out, failok => 1);
        }
        # Upload crm report
        qesap_upload_crm_report(host => $host, provider => $provider, failok => 1);
    }

    # Collect logs in iscsi service node if there is.
    qesap_save_y2logs(provider => $provider, host => 'iscsi[0]', failok => 1) if (script_run("grep -q 'iscsi' $inventory") == 0);

    if ($provider eq 'AZURE') {
        my @diagnostic_logs = qesap_az_diagnostic_log();
        push(@log_files, $_) foreach (@diagnostic_logs);
        qesap_upload_logs();
    }
}

=head3 qesap_save_y2logs

  Collect y2logs from nodes of a deployed cluster

=over

=item B<PROVIDER> - Cloud provider name using same format of PUBLIC_CLOUD_PROVIDER setting

=item B<HOST> - node of a deployed cluster

=back
=cut

sub qesap_save_y2logs {
    my (%args) = @_;
    foreach (qw(provider host)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{failok} //= 0;

    my $log_filename = "$args{host}-y2logs.tar.gz";

    $log_filename =~ s/[\[\]"]//g;

    qesap_ansible_cmd(cmd => "sudo save_y2logs /tmp/$log_filename",
        provider => $args{provider},
        filter => "\"$args{host}\"",
        host_keys_check => 1,
        verbose => 1,
        timeout => bmwqemu::scale_timeout(7200),
        failok => $args{failok});
    qesap_ansible_cmd(cmd => "sudo chmod 755 /tmp/$log_filename",
        provider => $args{provider},
        filter => "\"$args{host}\"",
        host_keys_check => 1,
        verbose => 1,
        timeout => bmwqemu::scale_timeout(7200),
        failok => $args{failok});
    my $local_path = qesap_ansible_fetch_file(provider => $args{provider},
        host => $args{host},
        failok => $args{failok},
        root => 1,
        remote_path => '/tmp/',
        out_path => '/tmp/ansible_script_output/',
        file => "$log_filename",
        verbose => 1);
    upload_logs($local_path, failok => 1);
}

=head3 qesap_supportconfig_logs

  Collect supportconfig logs from all HANA nodes of a deployed cluster

=over

=item B<PROVIDER> - Cloud provider name using same format of PUBLIC_CLOUD_PROVIDER setting

=back
=cut

sub qesap_supportconfig_logs {
    my (%args) = @_;
    croak "Missing mandatory argument 'provider'" unless $args{provider};
    my $inventory = qesap_get_inventory(provider => $args{provider});

    # return != 0 means no inventory
    return if (script_run("test -e $inventory", 60));
    foreach my $host ('hana[0]', 'hana[1]') {
        qesap_upload_supportconfig_logs(host => $host, provider => $args{provider}, failok => 1);
    }
}

=head3 qesap_calculate_deployment_name

Compose the deployment name. It always has the JobId

=over

=item B<PREFIX> - optional substring prepend in front of the job id

=back
=cut

sub qesap_calculate_deployment_name {
    my ($prefix) = @_;
    my $id = get_current_job_id();
    return $prefix ? $prefix . $id : $id;
}

=head3 qesap_aws_filter_query

    Generic function to compose a aws cli command with:
      - `aws ec2` something
      - use both `filter` and `query`
      - has text output

=cut

sub qesap_aws_filter_query {
    my (%args) = @_;
    foreach (qw(cmd filter query)) { croak "Missing mandatory $_ argument" unless $args{$_}; }

    my $cmd = join(' ', 'aws ec2', $args{cmd},
        '--filters', $args{filter},
        '--query', $args{query},
        '--output text');
    return script_output($cmd);
}

=head3 qesap_add_server_to_hosts

    Adds a 'ip -> name' pair in the end of /etc/hosts in the hosts

=over

=item B<IP> - ip of server to add to hosts

=item B<NAME> - name of server to add to hosts

=back
=cut

sub qesap_add_server_to_hosts {
    my (%args) = @_;
    foreach (qw(ip name)) { croak "Missing mandatory $_ argument" unless $args{$_}; }

    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    qesap_ansible_cmd(cmd => "sed -i '\\\$a $args{ip} $args{name}' /etc/hosts",
        provider => $provider,
        host_keys_check => 1,
        verbose => 1);
    qesap_ansible_cmd(cmd => "cat /etc/hosts",
        provider => $provider,
        verbose => 1);
}

=head3 qesap_import_instances

    Downloads assets required for re-using infrastructure from previously exported test.
    qesap_import_instances(<$test_id>)

=over

=item B<$test_id> - OpenQA test ID from a test previously run with "QESAP_DEPLOYMENT_IMPORT=1" and
                    infrastructure still being up and running

=back
=cut

sub qesap_import_instances {
    my ($test_id) = @_;
    die("OpenQA test ID must be a number. Parameter 'QESAP_DEPLOYMENT_IMPORT' must contain ID of previously exported test")
      unless looks_like_number($test_id);

    my $inventory_file = qesap_get_inventory(provider => get_required_var('PUBLIC_CLOUD_PROVIDER'));
    my %files = ('id_rsa' => '/root/.ssh/',
        'id_rsa.pub' => '/root/.ssh/',
        basename($inventory_file) => dirname($inventory_file) . '/');
    my $test_url = join('', 'http://', get_required_var('OPENQA_URL'), '/tests/', $test_id);

    assert_script_run('mkdir -m700 /root/.ssh');
    assert_script_run('mkdir -p ' . dirname($inventory_file));

    foreach my $key (keys %files) {
        assert_script_run(join(' ', 'curl -v -fL', $test_url . '/file/' . $key, '-o', $files{$key} . $key),
            fail_message => "Failed to download file log data '$key' from test '$test_url'");
        record_info('IMPORT', "File '$key' imported from test '$test_url'");
    }
    assert_script_run('chmod -R 600 /root/.ssh/');
}

=head3 qesap_export_instances

    Downloads assets required for re-using infrastructure from previously exported test.
    qesap_export_instances()

=cut

sub qesap_export_instances {
    my @upload_files = (
        qesap_get_inventory(provider => get_required_var('PUBLIC_CLOUD_PROVIDER')),
        '/root/.ssh/id_rsa',
        '/root/.ssh/id_rsa.pub');

    upload_logs($_, log_name => basename($_)) for @upload_files;
    record_info('EXPORT',
        "SSH keys and instances data uploaded to test results:\n" . join("\n", @upload_files));
}

=head2 qesap_aws_delete_leftover_tgw_attachments

    Delete leftover peering resources for AWS jobs that finished without cleaning up.
    This only works for resources created by jobs that run on the same openqa server 
    that the current job is running on.

=over

=item B<MIRROR_TAG> - tag of the IBS Mirror

=back
=cut

sub qesap_aws_delete_leftover_tgw_attachments {
    my (%args) = @_;
    return 0 unless $args{mirror_tag};

    my $available_attachments = qesap_aws_get_tgw_attachments(%args);

    return 1 unless ref($available_attachments) eq 'ARRAY' && @$available_attachments;
    record_info('AWS PEERING CLEANUP', 'Starting leftover peering cleanup (AWS)');

    foreach my $att (@$available_attachments) {
        # The name is set by Terraform during the attachment creation
        # The name includes the id of the openqa job that created the resources.
        my $name = $att->{Name} // '';
        # This is the tgw-attachment id
        my $id = $att->{Id} // next;

        # Here the openqa job id is extracted from the name
        next unless $name =~ /(\d+)-tgw-attach$/;
        my $job_id = $1;
        # If the job is finished, the resources are leftovers and must be purged.
        next unless qesap_is_job_finished(job_id => $job_id);

        record_info('LEFTOVER TGW ATTACHMENT', "Attachment " . $name . "'s job has finished, deleting");

        qesap_aws_delete_transit_gateway_vpc_attachment(
            id => $id,
            wait => 0
        );
    }
    return 1;
}

=head2 qesap_terraform_ansible_deploy_retry

    qesap_terraform_ansible_deploy_retry( error_log=>$error_log )
        error_log - ansible error log file name

    Retry to deploy terraform + ansible. This function is only expected to be called if a previous `qesap.py`
    execution returns a non zero exit code. If this function is called after a successful execution,
    the qesap_ansible_error_detection will not find anything wrong in the log, wrongly concluding that
    an unknown error is in the log and skipping the retry and this function will return 1..
    Return 0: this function manage the failure properly, perform a retry and retry was a successful deployment
    Return 1: something went wrong or this function does not know what to do with the failure

=over

=item B<ERROR_LOG> - error log filename

=item B<PROVIDER> - cloud provider name as from PUBLIC_CLOUD_PROVIDER setting

=back
=cut

sub qesap_terraform_ansible_deploy_retry {
    my (%args) = @_;
    foreach (qw(error_log provider)) { croak "Missing mandatory $_ argument" unless $args{$_}; }

    my $detected_error = qesap_ansible_error_detection(error_log => $args{error_log});
    record_info('qesap_terraform_ansible_deploy_retry', "detected error:$detected_error");
    my @ret;
    # 3: no sudo password
    if ($detected_error eq 3) {
        @ret = qesap_execute(cmd => 'ansible',
            logname => 'qesap_ansible_retry.log.txt',
            timeout => 3600);
        die "'qesap.py ansible' return: $ret[0]" if ($ret[0]);
        record_info('ANSIBLE RETRY PASS');
        $detected_error = 0;
    }
    # 2: reboot timeout
    elsif ($detected_error eq 2) {
        if ($args{provider} eq 'AZURE') {
            my @diagnostic_logs = qesap_az_diagnostic_log();
            foreach (@diagnostic_logs) {
                push(@log_files, $_);
                qesap_upload_logs();
            }
        }

        # Do cleanup before redeploy: perform terraform destroy, catch and ignore any error.
        # This is useful when doing cleanup before retry in case of
        # Ansible failed on 'Timed out waiting for last boot time check'
        # Do not attempt a 'ansible' cleanup after a 'Timed out waiting for last boot time check':
        # the SSH will be disconnected. For example, ansible SSH reports '"msg": "Timeout (12s) waiting for privilege escalation prompt: "'.
        # Terraform destroy can be executed in any case
        @ret = qesap_execute(
            cmd => 'terraform',
            cmd_options => '-d',
            timeout => 1200,
            logname => 'qesap_terraform_destroy_retry.log.txt');
        if ($ret[0] == 0) {
            diag("Terraform cleanup attempt #  PASSED.");
            record_info("Clean Terraform", 'Terraform cleanup PASSED.');
        }
        else {
            diag("Terraform cleanup attempt #  FAILED.");
            record_info('Cleanup FAILED', "Cleanup terraform FAILED", result => 'fail');
        }

        # Re-deploy from scratch
        @ret = qesap_execute(
            cmd => 'terraform',
            verbose => 1,
            logname => 'qesap_terraform_retry.log.txt',
            timeout => 1800
        );
        die "'qesap.py terraform' return: $ret[0]" if ($ret[0]);
        @ret = qesap_execute(
            cmd => 'ansible',
            verbose => 1,
            logname => 'qesap_ansible_retry.log.txt',
            timeout => 3600
        );
        if ($ret[0]) {
            die "'qesap.py ansible' return: $ret[0]";
        }
        record_info('ANSIBLE RETRY PASS');
        $detected_error = 0;
    }
    else {
        # qesap_ansible_error_detection return:
        # - 0 (unknown error),
        # - 1 (generic fatal, not something we can solve by retry) or something else...
        # Mark both as a failure in the retry, allowing error to be propagated.
        $detected_error = 1;
    }
    return $detected_error;
}

=head2 qesap_ansible_error_detection

    qesap_ansible_error_detection( error_log=>$error_log )

    Inspect the provided Ansible log and search for known issue in the log
    Also provide a nice record_info to summarize the error
    Return:
     - 0: unable to detect errors
     - 1: generic fatal error
     - 2: reboot timeout
     - 3: no sudo password

=over

=item B<ERROR_LOG> - error log filename

=back
=cut

sub qesap_ansible_error_detection {
    my (%args) = @_;
    croak 'Missing mandatory error_log argument' unless $args{error_log};
    my $error_message = '';
    my $ret_code = 0;

    if (qesap_file_find_strings(file => $args{error_log},
            search_strings => ['Missing sudo password'])) {
        $error_message = 'MISSING SUDO PASSWORD';
        $ret_code = 3;
    }
    elsif (qesap_file_find_strings(file => $args{error_log},
            search_strings => ['Timed out waiting for last boot time check'])) {
        $error_message = 'REBOOT TIMEOUT';
        $ret_code = 2;
    }
    else {
        my $ansible_fatal = script_output("grep -A30 'fatal:' $args{error_log} | cut -c-200",
            proceed_on_failure => 1);
        my $ansible_failed = script_output("grep -A30 'failed: \\[' $args{error_log} | cut -c-200",
            proceed_on_failure => 1);
        $error_message .= "Ansible fatal: $ansible_fatal\n" unless ($ansible_fatal eq "");
        $error_message .= "Ansible failed: $ansible_failed\n" unless ($ansible_failed eq "");
        $ret_code = 1 unless ($error_message eq "");
    }
    record_info('ANSIBLE ISSUE', $error_message) unless $ret_code eq 0;
    return $ret_code;
}

=head2 qesap_create_cidr_from_ip

    qesap_create_cidr_from_ip( proceed_on_failure )

    Takes an IP as argument and returns the CIDR string that
    denotes this specific ip (adds /32 mask for ipv4, /128 for ipv6).
    Return:
     - CIDR notation for the provided IP
     - undef if IP can't be validated and proceed_on_failure is true

=over

=item B<IP> - The ip to convert to CIDR

=back
=cut

sub qesap_create_cidr_from_ip {
    my (%args) = @_;
    my $ip = $args{ip} // '';
    $ip =~ s/^\s+|\s+$//g;
    $ip =~ s{/\d+\s*$}{};

    # NetAddr objects add the appropriate v4 or v6 mask automatically
    my $ret = NetAddr::IP->new($ip);

    return $ret->cidr if ($ret);
    return undef if $args{proceed_on_failure};
    die "The provided IP could not be validated: $ip";
}

=head3 qesap_ssh_intrusion_detection

  Search and report relevant messages from the journal.

=over

=item B<PROVIDER> - cloud provider name as from PUBLIC_CLOUD_PROVIDER setting

=back
=cut

sub qesap_ssh_intrusion_detection {
    my (%args) = @_;
    croak "Missing mandatory 'provider' argument" unless $args{provider};
    my $inventory = qesap_get_inventory(provider => $args{provider});
    my $attempts;
    my %users;
    my %ips;
    my %report;
    my $log_filename;

    # return != 0 means no inventory
    return if (script_run("test -e $inventory", 60));
    foreach my $host ('hana[0]', 'hana[1]') {
        $log_filename = "$host-intrusion-log.txt";
        $log_filename =~ s/[\[\]"]//g;
        my $out_file = qesap_ansible_script_output_file(
            cmd => 'journalctl -u sshd | grep \"Connection closed by\"',
            provider => $args{provider},
            host => $host,
            failok => 1,
            root => 1,
            verbose => 1,
            remote_path => '/tmp/',
            out_path => '/tmp/ansible_script_output/',
            file => $log_filename);
        unless (script_run("test -e $out_file")) {
            upload_logs($out_file, failok => 1);
            my $output = script_output("cat $out_file");
            $attempts = 0;
            %users = ();
            %ips = ();

            next if $attempts == 0;

            foreach my $line (split /\n/, $output) {
                # Regular expression to capture user and IP for both 'authenticating user' and 'invalid user'
                if ($line =~ /Connection closed by (?:authenticating|invalid) user (\S+) (\S+)/) {
                    my ($user, $ip) = ($1, $2);
                    $users{$user}++;
                    $ips{$ip}++;
                    $attempts++;
                }
            }

            $report{$host}{attempts} = $attempts;
            $report{$host}{users} = [keys %users];
            $report{$host}{ips} = [keys %ips];
            record_info("SSHD Log Analysis for $host",
                "Found $report{$host}{attempts} login attempts. Users: @{$report{$host}{users}}. IPs: @{$report{$host}{ips}}");
        }
    }
}

1;
