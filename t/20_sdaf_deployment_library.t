use strict;
use warnings;
use Test::Mock::Time;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use List::MoreUtils qw(uniq);
use List::Util qw(any none);
use Data::Dumper;
use testapi;
use sles4sap::sap_deployment_automation_framework::deployment;

sub undef_variables {
    my @openqa_variables = qw(
      _SECRET_AZURE_SDAF_APP_ID
      _SECRET_AZURE_SDAF_APP_PASSWORD
      _SECRET_AZURE_SDAF_TENANT_ID
      PUBLIC_CLOUD_AZURE_SUBSCRIPTION_ID
      SDAF_GIT_AUTOMATION_REPO
      SDAF_GIT_TEMPLATES_REPO
      SDAF_DEPLOYMENT_ID
    );
    set_var($_, '') foreach @openqa_variables;
}

subtest '[prepare_sdaf_project]' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my %arguments = (
        sap_sid => 'QAS',
        sdaf_region_code => 'SECE',
        env_code => 'LAB',
        deployer_vnet_code => 'DEP05',
        workload_vnet_code => 'SAP04'
    );

    my @git_commands;
    my %vnet_checks;
    $ms_sdaf->noop(qw(record_info git_clone));
    $ms_sdaf->redefine(get_workload_vnet_code => sub { return 'SAP04'; });
    $ms_sdaf->redefine(log_dir => sub { return '/tmp/openqa_logs'; });
    $ms_sdaf->redefine(script_output => sub { return "v4\nv5"; });
    $ms_sdaf->redefine(assert_script_run => sub {
            push(@git_commands, join('', $_[0])) if grep(/git/, $_[0]);
            return 1; });
    $ms_sdaf->redefine(deployment_dir => sub { return '/root/SDAF/'; });
    # this is to check if internal logic picks correct vnet code for deployment type
    $ms_sdaf->redefine(get_tfvars_path => sub {
            my (%args) = @_;
            $vnet_checks{$args{deployment_type}} = $args{vnet_code};
            return '/some/useless/path'; });
    set_var('SDAF_GIT_AUTOMATION_REPO', 'https://github.com/Azure/sap-automation.git');
    set_var('SDAF_GIT_TEMPLATES_REPO', 'https://github.com/Azure/sap-automation-samples.git');
    set_var('SDAF_GIT_AUTOMATION_BRANCH', 'latest');

    prepare_sdaf_project(%arguments);

    # Check correct vnet codes
    is $vnet_checks{library}, '', 'Return library without vnet code';
    is $vnet_checks{deployer}, $arguments{deployer_vnet_code}, 'Return correct vnet code for deployer';
    is $vnet_checks{workload_zone}, $arguments{workload_vnet_code}, 'Return correct vnet code for workload zone';
    is $vnet_checks{sap_system}, $arguments{workload_vnet_code}, 'Return correct vnet code for sap SUT';
    undef_variables();
};

subtest '[prepare_sdaf_project] Check directory creation' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my %arguments = (
        sap_sid => 'QAS',
        sdaf_region_code => 'SECE',
        env_code => 'LAB',
        deployer_vnet_code => 'DEP05',
        workload_vnet_code => 'SAP04',
        deployment_type => 'workload_zone'
    );
    my $tfvars_file = 'Azure_SAP_Automated_Deployment/WORKSPACES/DEPLOYER/LAB-SECE-DEP05-INFRASTRUCTURE/LAB-SECE-DEP05-INFRASTRUCTURE.tfvars';
    my @mkdir_commands;

    $ms_sdaf->noop(qw(record_info git_clone));
    $ms_sdaf->redefine(script_output => sub { return "v4\nv5"; });
    $ms_sdaf->redefine(assert_script_run => sub { push(@mkdir_commands, $_[0]) if grep(/mkdir/, @_); return 1; });
    $ms_sdaf->redefine(deployment_dir => sub { return '/tmp/SDAF'; });
    $ms_sdaf->redefine(get_tfvars_path => sub { return $tfvars_file; });
    $ms_sdaf->redefine(log_dir => sub { return '/tmp/openqa_logs'; });
    $ms_sdaf->redefine(get_workload_vnet_code => sub { return 'SAP04'; });

    set_var('SDAF_GIT_AUTOMATION_REPO', 'https://github.com/Azure/sap-automation/tree/main');
    set_var('SDAF_GIT_TEMPLATES_REPO', 'https://github.com/Azure/SAP-automation-samples/tree/main');
    set_var('SDAF_GIT_AUTOMATION_BRANCH', 'latest');

    prepare_sdaf_project(%arguments);
    is $mkdir_commands[0], 'mkdir -p /tmp/openqa_logs', 'Create logging directory';
    is $mkdir_commands[1], 'mkdir -p Azure_SAP_Automated_Deployment/WORKSPACES/DEPLOYER/LAB-SECE-DEP05-INFRASTRUCTURE',
      'Create workspace directory';
    undef_variables;
};

subtest '[serial_console_diag_banner] ' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my @printed_lines;
    $ms_sdaf->noop(qw(wait_serial));
    $ms_sdaf->redefine(enter_cmd => sub { push(@printed_lines, $_[0]); return 1; });
    serial_console_diag_banner('Module: deploy_sdaf.pm');
    note("Banner:\n" . join("\n", @printed_lines));
    ok(grep(/Module: deploy_sdaf.pm/, @printed_lines), 'Banner must include message');
    dies_ok { serial_console_diag_banner() } 'Fail with missing test to be printed';
    dies_ok { serial_console_diag_banner('exeCuTing deploYment' x 6) } 'Fail with string exceeds max number of characters';
};

subtest '[set_common_sdaf_os_env]' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my %arguments = (
        sap_sid => 'RGM-79',
        deployer_vnet_code => 'RX-77-2',
        workload_vnet_code => 'RX-77D',
        sdaf_region_code => 'RX-78-1',
        env_code => 'RX-75',
        sdaf_tfstate_storage_account => 'RMV-1',
        sdaf_key_vault => 'RGT-76',
        subscription_id => 'RX-78-2',
    );
    my @file_content;
    $ms_sdaf->redefine(create_sdaf_os_var_file => sub { @file_content = @{$_[0]}; });
    $ms_sdaf->redefine(get_tfvars_path => sub { return 'RB-79'; });
    $ms_sdaf->redefine(deployment_dir => sub { return 'FF-4'; });
    $ms_sdaf->redefine(get_workload_vnet_code => sub { return 'RX-77D'; });


    my @required_variables = (
        'env_code',
        'deployer_vnet_code',
        'workload_vnet_code',
        'sap_env_code',
        'deployer_env_code',
        'sdaf_region_code',
        'SID',
        'ARM_SUBSCRIPTION_ID',
        'SAP_AUTOMATION_REPO_PATH',
        'DEPLOYMENT_REPO_PATH',
        'CONFIG_REPO_PATH',
        'deployer_parameter_file',
        'library_parameter_file',
        'sap_system_parameter_file',
        'workload_zone_parameter_file',
        'tfstate_storage_account',
        'deployerState',
        'key_vault'
    );

    set_common_sdaf_os_env(%arguments);
    note("\n  File content:\n  -->  " . join("\n  -->  ", @file_content));

    for my $variable (@required_variables) {
        ok(grep(/export $variable=*./, @file_content), "File contains defined variable: $variable");
    }
};

subtest '[az_login] Get credentials from server' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my $env_variable_file_content;
    my %credentrials = (client_id => 'Potato', client_secret => 'Patata', tenant_id => 'Zemiak', subscription_id => 'Batata');

    $ms_sdaf->noop(qw(record_info assert_script_run script_output));
    $ms_sdaf->redefine(get_credentials => sub { return \%credentrials; });
    $ms_sdaf->redefine(write_sut_file => sub { $env_variable_file_content = $_[1]; });

    az_login();
    ok($env_variable_file_content =~ /export ARM_SUBSCRIPTION_ID=Batata/, 'File contains subscription id');
    ok($env_variable_file_content =~ /export ARM_CLIENT_SECRET=Patata/, 'File contains client secret');
    ok($env_variable_file_content =~ /export ARM_TENANT_ID=Zemiak/, 'File contains tenant id');
    ok($env_variable_file_content =~ /export ARM_CLIENT_ID=Potato/, 'File contains client id');
};

subtest '[az_login] Get credentials from OpenQA settings' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    set_var('_SECRET_AZURE_SDAF_APP_ID', 'Potato');
    set_var('_SECRET_AZURE_SDAF_APP_PASSWORD', 'Patata');
    set_var('_SECRET_AZURE_SDAF_TENANT_ID', 'Zemiak');
    set_var('PUBLIC_CLOUD_AZURE_SUBSCRIPTION_ID', 'Peruna');

    my $env_variable_file_content;
    $ms_sdaf->noop(qw(record_info assert_script_run script_output));
    $ms_sdaf->redefine(write_sut_file => sub { $env_variable_file_content = $_[1]; });

    az_login();
    ok($env_variable_file_content =~ /export ARM_SUBSCRIPTION_ID=Peruna/, 'File contains subscription id');
    ok($env_variable_file_content =~ /export ARM_CLIENT_SECRET=Patata/, 'File contains client secret');
    ok($env_variable_file_content =~ /export ARM_TENANT_ID=Zemiak/, 'File contains tenant id');
    ok($env_variable_file_content =~ /export ARM_CLIENT_ID=Potato/, 'File contains client id');

    undef_variables;
};


subtest '[sdaf_cleanup] Test correct usage' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    $ms_sdaf->noop(qw(record_info
          script_output
          deployment_dir
          resource_group_exists));
    $ms_sdaf->redefine(generate_resource_group_name => sub { return 'ResourceGroup'; });
    $ms_sdaf->redefine(sdaf_execute_remover => sub { return 0; });
    $ms_sdaf->redefine(script_run => sub { return 0; });

    my %cleanup_results = %{sdaf_cleanup()};
    ok(!$cleanup_results{remover_failed}, 'Remover passes with correct usage');
    is($cleanup_results{file_cleanup}, 'pass', 'File cleanup passes with correct usage');
};

subtest '[sdaf_cleanup] Test remover script failures' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my $force_group_delete;
    $ms_sdaf->noop(qw( record_info script_output deployment_dir generate_resource_group_name ));
    $ms_sdaf->redefine(resource_group_exists => sub { return 'yes'; });
    $ms_sdaf->redefine(sdaf_destroy_resources => sub { $force_group_delete = 1; });
    $ms_sdaf->redefine(sdaf_execute_remover => sub { return 1; });
    $ms_sdaf->redefine(script_run => sub { return 0; });
    $ms_sdaf->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', $_[0], ':', $_[1])); });

    my %cleanup_results = %{sdaf_cleanup()};
    ok($cleanup_results{remover_failed}, 'Remover passes with correct usage');
    ok($force_group_delete, 'Function must delete resource groups after remover failure');
    is($cleanup_results{file_cleanup}, 'pass', 'File cleanup must run even after remover failure');
};

subtest '[sdaf_execute_remover] Check command line arguments' => sub {
    # Tested indirectly via sdaf_cleanup()

    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my @script_run_calls;

    $ms_sdaf->noop(qw(
          record_info
          upload_logs
          assert_script_run
          resource_group_exists
          log_dir
          deployment_dir
          sdaf_scripts_dir
          generate_resource_group_name)
    );
    $ms_sdaf->redefine(script_run => sub { push @script_run_calls, $_[0] if grep /remover/, $_[0]; return 0; });
    $ms_sdaf->redefine(get_os_variable => sub {
            return '/some/path/LAB-SECE-SAP04-INFRASTRUCTURE-6453.tfvars' if $_[0] eq 'workload_zone_parameter_file';
            return '/some/path/LAB-SECE-SAP04-QES-6453.tfvars' if $_[0] eq 'sap_system_parameter_file';
    });

    sdaf_cleanup();
    for my $cmd (@script_run_calls) {
        note("\n  CMD: $cmd");
        ok(grep(/^.*\/remover.sh/, split(' ', $cmd)), 'Script "remover.sh called"');
        ok(grep(/--parameterfile/, split(' ', $cmd)), 'Argument "--parameterfile" defined');
        ok(grep(/--type/, split(' ', $cmd)), 'Argument "--type" defined');
        ok(grep(/--auto-approve/, split(' ', $cmd)), 'Disable user interaction');
        ok(grep(/| tee .*\.log/, split(' ', $cmd)), 'Log command output');
        ok(grep(/\$\{PIPESTATUS\[0]}/, split(' ', $cmd)), 'Return command RC instead of tee');
    }

    # Test remover retry
    $ms_sdaf->redefine(script_run => sub { return 1; });
    dies_ok { sdaf_cleanup() } 'Test failing remover script: retried 3 times and failed';
};


subtest '[sdaf_execute_deployment] Test expected failures' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    $ms_sdaf->noop(
        qw(upload_logs
          assert_script_run
          log_dir
          script_run
          record_info
          export_credentials
          get_sdaf_deployment_command
          log_command_output
        )
    );

    my @invalid_deployment_types = ('sap_sys', 'orkload', 'workload', 'zone', 'system', 'sap_system ', ' sap_system', '', ' ');
    dies_ok { sdaf_execute_deployment(deployment_type => $_) } "Fail with incorrect deployment type: '$_'" foreach @invalid_deployment_types;

    # Function must not fail with croak if command fails.
    my $croak_executed = 0;
    $ms_sdaf->redefine(croak => sub { $croak_executed = 1; die(); });
    dies_ok { sdaf_execute_deployment(deployment_type => 'sap_system') } 'Function dies with executed SDAF command RC!=0';
    is $croak_executed, 0, 'Ensure function failing because of correct reason';
};

subtest '[sdaf_execute_deployment] Test generated SDAF deployment command' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my $sdaf_command_no_log;

    $ms_sdaf->redefine(script_run => sub { return 0; });
    $ms_sdaf->redefine(sdaf_scripts_dir => sub { return '/tmp/deployment'; });
    $ms_sdaf->redefine(get_os_variable => sub { return '/some/path/LAB-SECE-SAP04-INFRASTRUCTURE-6453.tfvars' });

    # Capture command without logging part
    $ms_sdaf->redefine(log_command_output => sub { $sdaf_command_no_log = $_[1]; return; });

    $ms_sdaf->noop(qw(assert_script_run export_credentials record_info upload_logs log_dir set_os_variable));
    # Check if all required parameters are present including any form of value if required
    my @workload_zone_cmdline = ('^/tmp/deployment/install_workloadzone.sh\s',
        '\s--parameterfile\s.*(\s|$)',
        '\s--deployer_environment\s.*(\s|$)',
        '\s--deployer_tfstate_key\s.*(\s|$)',
        '\s--keyvault\s.*(\s|$)',
        '\s--storageaccountname\s.*(\s|$)',
        '\s--subscription\s.*(\s|$)',
        '\s--tenant_id\s.*(\s|$)',
        '\s--spn_id\s\$\{ARM_CLIENT_ID}(\s|$)',
        '\s--spn_secret\s\$\{ARM_CLIENT_SECRET}(\s|$)',
        '\s--auto-approve(\s|$)'
    );

    my @sap_system_cmdline = ('^/tmp/deployment/installer.sh',
        '\s--parameterfile\s.*(\s|$)',
        '\s--type\ssap_system(\s|$)',
        '\s--storageaccountname\s.*(\s|$)',
        '\s--state_subscription\s.*(\s|$)',
        '\s--auto-approve(\s|$)'
    );

    sdaf_execute_deployment(deployment_type => 'workload_zone');
    ok $sdaf_command_no_log =~ m/$_/, "Command for deploying workload zone must contain cmd option: '$_'" foreach @workload_zone_cmdline;
    sdaf_execute_deployment(deployment_type => 'sap_system');
    ok $sdaf_command_no_log =~ m/$_/, "Command for deploying sap systems must contain cmd option: '$_'" foreach @sap_system_cmdline;
};

subtest '[sdaf_execute_deployment] Test "retry" functionality' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    $ms_sdaf->redefine(get_os_variable => sub { return '/some/path/LAB-SECE-SAP04-INFRASTRUCTURE-6453.tfvars' });
    $ms_sdaf->redefine(get_sdaf_deployment_command => sub { return 'dd if=/dev/zero of=/dev/sda'; });
    my $retry = 0;
    $ms_sdaf->redefine(script_run => sub { $retry++; print $retry; return 0 if $retry == 3; return 1 });

    $ms_sdaf->noop(
        qw(assert_script_run
          record_info
          upload_logs
          export_credentials
          log_dir
          sdaf_scripts_dir
          set_os_variable
          log_command_output
        )
    );
    ok sdaf_execute_deployment(deployment_type => 'workload_zone', retries => 3);
};

subtest '[sdaf_execute_playbook] Fail with missing mandatory arguments' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my $croak_message;
    $ms_sdaf->redefine(croak => sub { $croak_message = $_[0]; die(); });

    set_var('PUBLIC_CLOUD_REGION', 'swedencentral');
    set_var('SAP_SID', 'QES');

    dies_ok { sdaf_execute_playbook(sdaf_config_root_dir => '/love/and/peace') } 'Croak with missing mandatory argument "playbook_filename"';
    ok $croak_message =~ m/playbook_filename/, 'Verify failure reason.';

    dies_ok { sdaf_execute_playbook(playbook_filename => '00_world_domination.yaml') } 'Croak with missing mandatory argument "sdaf_config_root_dir"';
    ok $croak_message =~ m/sdaf_config_root_dir/, 'Verify failure reason.';

    undef_variables();
};

subtest '[sdaf_execute_playbook] Command execution' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my @calls;
    $ms_sdaf->redefine(script_run => sub { push(@calls, $_[0]); return 0; });
    $ms_sdaf->noop(qw(assert_script_run record_info log_dir upload_logs deployment_dir));
    set_var('SAP_SID', 'QES');
    set_var('SDAF_ANSIBLE_VERBOSITY_LEVEL', undef);

    sdaf_execute_playbook(playbook_filename => 'playbook_01_os_base_config.yaml', sdaf_config_root_dir => '/tmp/SDAF/WORKSPACES/SYSTEM/LAB-SECE-SAP04-QAS');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /ansible-playbook/ } @calls), 'Execute main command');
    ok((any { /--inventory-file="QES_hosts.yaml"/ } @calls), 'Command contains "--inventory-file" parameter');
    ok((any { /--private-key=\/tmp\/SDAF\/WORKSPACES\/SYSTEM\/LAB-SECE-SAP04-QAS\/sshkey/ } @calls),
        'Command contains "--private-key" parameter');
    ok((any { /--extra-vars=\'_workspace_directory=\/tmp\/SDAF\/WORKSPACES\/SYSTEM\/LAB-SECE-SAP04-QAS\'/ } @calls),
        'Command contains extra variable: "_workspace_directory"');
    ok((any { /--extra-vars="\@sap-parameters.yaml"/ } @calls), 'Command contains extra variable with SDAF sap-parameters');
    ok((any { /--ssh-common-args=/ } @calls), 'Command contains "--ssh-common-args" parameter');

    undef_variables();
};

subtest '[sdaf_execute_playbook] Command verbosity' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my @calls;

    $ms_sdaf->redefine(script_run => sub { return; });
    $ms_sdaf->redefine(log_command_output => sub { push(@calls, $_[1]); return 0; });
    $ms_sdaf->noop(qw(assert_script_run record_info log_dir upload_logs deployment_dir));
    set_var('SAP_SID', 'QES');

    my %verbosity_levels = (
        '1' => '-v',
        '2' => '-vv',
        '6' => '-vvvvvv',
        'somethingtrue' => '-vvvv'
    );

    for my $level (keys(%verbosity_levels)) {
        set_var('SDAF_ANSIBLE_VERBOSITY_LEVEL', $level);
        sdaf_execute_playbook(playbook_filename => 'playbook_01_os_base_config.yaml', sdaf_config_root_dir => '/tmp/SDAF/WORKSPACES/SYSTEM/LAB-SECE-SAP04-QAS');
        ok(grep(/$verbosity_levels{$level}/, @calls), "Append '$verbosity_levels{$level}' with verbosity parameter: '$level'");
    }

    undef_variables();
};

subtest '[sdaf_ssh_key_from_keyvault] Test exceptions' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my $croak_message;
    $ms_sdaf->redefine(croak => sub { $croak_message = $_[0]; note("\n  -->  $_[0]"); die; });
    $ms_sdaf->noop(qw(assert_script_run homedir record_info az_keyvault_secret_show script_run));

    # Exception is handled by 'az_keyvault_secret_list'
    dies_ok { sdaf_ssh_key_from_keyvault() } 'Croak with missing $args{key_vault}';
    ok($croak_message =~ /key_vault/, 'Check if croak message is correct');

    $ms_sdaf->redefine(az_keyvault_secret_list => sub { return ['Amuro', 'Ray']; });
    dies_ok { sdaf_ssh_key_from_keyvault(key_vault => 'SCV-70 White Base') } 'Croak with az cli returning multiple key vaults';
    ok($croak_message =~ /Multiple/, 'Check if croak message is correct');

    $ms_sdaf->redefine(az_keyvault_secret_list => sub { return ['Amuro']; });

    dies_ok { sdaf_ssh_key_from_keyvault(key_vault => 'SCV-70 White Base') } 'Croak with invalid private key returned';
    ok($croak_message =~ /Failed/, 'Check if croak message is correct');
};

subtest '[sdaf_ssh_key_from_keyvault] Verify executed commands' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my @assert_script_run;
    my @script_run;
    $ms_sdaf->redefine(az_keyvault_secret_list => sub { return ['Amuro']; });
    $ms_sdaf->redefine(assert_script_run => sub { push @assert_script_run, $_[0]; return; });
    $ms_sdaf->redefine(script_run => sub { push @script_run, $_[0]; return; });

    $ms_sdaf->noop(qw(homedir record_info az_keyvault_secret_show));

    sdaf_ssh_key_from_keyvault(key_vault => 'SCV-70 White Base');
    note("\n --> " . join("\n --> ", @assert_script_run));
    ok(grep(/mkdir -p/, @assert_script_run), 'Create ssh directory');
    ok(grep(/touch/, @assert_script_run), 'Create ssh file');
    ok(grep(/chmod 700/, @assert_script_run), 'Set ssh directory permissions');
    ok(grep(/chmod 600/, @assert_script_run), 'Set public key permissions');

    note("\n --> " . join("\n --> ", @script_run));
    ok(grep(//, @assert_script_run), 'Validate ssh key');
};

subtest '[playbook_settings] Verify playbook order' => sub {
    my @components = ('db_install', 'db_ha', 'nw_pas', 'nw_aas', 'nw_ensa');
    my @playbook_list = map { $_->{playbook_filename} } @{playbook_settings(components => \@components)};

    is $playbook_list[0], 'pb_get-sshkey.yaml', 'Playbook #1 must be: pb_get-sshkey.yaml';
    is $playbook_list[1], 'playbook_00_validate_parameters.yaml', 'Playbook #2 must be: playbook_00_validate_parameters.yaml';
    is $playbook_list[2], 'playbook_01_os_base_config.yaml', 'Playbook #3 must be: playbook_01_os_base_config.yaml';
    is $playbook_list[3], 'playbook_02_os_sap_specific_config.yaml', 'Playbook #4 must be: playbook_02_os_sap_specific_config.yaml';
    is $playbook_list[4], 'playbook_03_bom_processing.yaml', 'Playbook #5 must be: playbook_03_bom_processing.yaml';
    is $playbook_list[5], 'playbook_04_00_00_db_install.yaml', 'Playbook #6 must be: playbook_04_00_00_db_install.yaml';
    is $playbook_list[6], 'playbook_05_00_00_sap_scs_install.yaml', 'Playbook #7 must be: playbook_05_00_00_sap_scs_install.yaml';
    is $playbook_list[7], 'playbook_05_01_sap_dbload.yaml', 'Playbook #8 must be: playbook_05_01_sap_dbload.yaml';
    is $playbook_list[8], 'playbook_04_00_01_db_ha.yaml', 'Playbook #9 must be: playbook_04_00_01_db_ha.yaml';
    is $playbook_list[9], 'playbook_05_02_sap_pas_install.yaml', 'Playbook #10 must be: playbook_05_02_sap_pas_install.yaml';
    is $playbook_list[10], 'playbook_05_03_sap_app_install.yaml', 'Playbook #11 must be: playbook_05_03_sap_app_install.yaml';
};

subtest '[register_byos] Test exceptions' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    $ms_sdaf->redefine(ansible_execute_command => sub { return; });
    $ms_sdaf->redefine(assert_script_run => sub { return; });
    $ms_sdaf->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', $_[0], ':', $_[1])); });
    $ms_sdaf->noop(qw(ansible_execute_command assert_script_run));

    my %mandatory_args = (sdaf_config_root_dir => '/fun/', scc_reg_code => 'HAHA', sap_sid => 'LOL');

    for my $arg (keys %mandatory_args) {
        my $orig_value = $mandatory_args{$arg};
        $mandatory_args{$arg} = undef;
        dies_ok { sdaf_register_byos(%mandatory_args) } "Croak with missing \$args{$arg}";
        $mandatory_args{$arg} = $orig_value;
    }
};

subtest '[register_byos] Command check' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my @commands;
    $ms_sdaf->redefine(ansible_execute_command => sub { @commands = @_; return; });
    $ms_sdaf->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $ms_sdaf->noop(qw(assert_script_run));

    my %mandatory_args = (sdaf_config_root_dir => '/fun/', scc_reg_code => 'HAHA', sap_sid => 'LOL');
    sdaf_register_byos(%mandatory_args);

    note('CMD: ' . join(' ', @commands));
    ok(grep(/sudo/, @commands), 'Execute command under "sudo"');
    ok(grep(/registercloudguest/, @commands), 'Execute command "registercloudguest"');
    ok(grep(/-r HAHA/, @commands), 'Include regcode');
};

subtest '[sdaf_deployment_reused]' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my $record_info_flag;
    $ms_sdaf->redefine(record_info => sub { $record_info_flag = 1; note(join(' ', 'RECORD_INFO -->', @_)); });


    set_var('SDAF_DEPLOYMENT_ID', undef);
    is sdaf_deployment_reused, undef, 'Return "undef" if "SDAF_DEPLOYMENT_ID" is not set.';
    set_var('SDAF_DEPLOYMENT_ID', '42');
    is sdaf_deployment_reused, '42', 'Return deployment ID if "SDAF_DEPLOYMENT_ID" is set.';
    ok($record_info_flag, 'Show record info message by default');
    $record_info_flag = undef;
    sdaf_deployment_reused(quiet => '1');
    ok(!$record_info_flag, 'Do not show "record_info" message with "quiet=>1"');
};

subtest '[validate_components]' => sub {
    ok validate_components(components => ['db_install']), "Pass with 'db_install' argument";
    ok validate_components(components => ['db_ha']), "Pass with 'db_ha' argument";
    ok validate_components(components => ['nw_pas']), "Pass with 'nw_pas' argument";
    ok validate_components(components => ['nw_aas']), "Pass with 'nw_aas' argument";
    ok validate_components(components => ['nw_ensa']), "Pass with 'nw_ensa' argument";
};

subtest '[validate_components] Exceptions' => sub {
    my @incorrect_values = ('db', 'pas', 'nw', 'ensa', 'aas', 'ha');

    foreach (@incorrect_values) {
        dies_ok { validate_components(components => [$_]) } "Fail with unsupported value: '$_'";
    }
};

subtest '[get_fencing_mechanism] Check value mapping' => sub {

    # OpenQA settinf => SDAF name
    my %value_mapping = (msi => 'AFA', sbd => 'ISCSI', asd => 'ASD');

    for my $openqa_value (keys %value_mapping) {
        set_var('SDAF_FENCING_MECHANISM', $openqa_value);
        is get_fencing_mechanism(), $value_mapping{$openqa_value},
          "OpenQA setting '$openqa_value' converts to '$value_mapping{$openqa_value}'.";
        set_var('SDAF_FENCING_MECHANISM', undef);
    }
};

subtest '[get_fencing_mechanism] Mandatory Settings' => sub {
    set_var('SDAF_FENCING_MECHANISM', undef);
    dies_ok { get_fencing_mechanism() } 'Croak with "SDAF_FENCING_MECHANISM" not being set';
};

subtest '[get_fencing_mechanism] Unsupported values' => sub {
    for my $bad_value ('msii', 'amsi', 'iscsi', 'sbdf', '', ' ') {
        set_var('SDAF_FENCING_MECHANISM', $bad_value);
        dies_ok { get_fencing_mechanism() } "Croak with unsupported 'SDAF_FENCING_MECHANISM' value: '$bad_value'";
        set_var('SDAF_FENCING_MECHANISM', undef);
    }
};

subtest '[sdaf_upload_logs]' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my %arguments = (
        hostname => 'QAS-hostname',
        sap_sid => 'QAS'
    );
    $ms_sdaf->noop(qw(record_info script_run script_output upload_logs));

    Test::MockModule->new('basetest');
    $autotest::current_test = new basetest;

    set_var('SUPPORTCONFIG', undef);
    ok sdaf_upload_logs(hostname => $arguments{hostname}, sap_sid => $arguments{sap_sid});

    set_var('SUPPORTCONFIG', '1');
    ok sdaf_upload_logs(hostname => $arguments{hostname}, sap_sid => $arguments{sap_sid});
};

subtest '[get_workload_resource_group]' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    $ms_sdaf->noop('record_info');
    $ms_sdaf->redefine(az_group_name_get => sub { return ['Resource_group']; });

    is get_workload_resource_group(deployment_id => '123'), 'Resource_group', 'Return exactly one RG';
};

subtest '[get_workload_resource_group]' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    $ms_sdaf->noop('record_info');
    $ms_sdaf->redefine(az_group_name_get => sub { return []; });
    dies_ok { get_workload_resource_group(deployment_id => '123') } 'Fail with empty result';

    $ms_sdaf->redefine(az_group_name_get => sub { return ['First_result', 'Oh_no-second_one']; });
    dies_ok { get_workload_resource_group(deployment_id => '123') } 'Fail with more than one results';
};

done_testing;
