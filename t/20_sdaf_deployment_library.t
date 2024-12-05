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
      SDAF_GIT_AUTOMATION_REPO
      SDAF_GIT_TEMPLATES_REPO
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

    # Workaround for SDAF bug https://github.com/Azure/sap-automation/issues/617
    $ms_sdaf->redefine(file_content_replace => sub { return; });
    $ms_sdaf->redefine(record_soft_failure => sub { return; });

    $ms_sdaf->redefine(record_info => sub { return; });
    $ms_sdaf->redefine(git_clone => sub { return; });
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

    # Workaround for SDAF bug https://github.com/Azure/sap-automation/issues/617
    $ms_sdaf->redefine(file_content_replace => sub { return; });
    $ms_sdaf->redefine(record_soft_failure => sub { return; });

    $ms_sdaf->redefine(record_info => sub { return; });
    $ms_sdaf->redefine(script_output => sub { return "v4\nv5"; });
    $ms_sdaf->redefine(assert_script_run => sub { push(@mkdir_commands, $_[0]) if grep(/mkdir/, @_); return 1; });
    $ms_sdaf->redefine(deployment_dir => sub { return '/tmp/SDAF'; });
    $ms_sdaf->redefine(get_tfvars_path => sub { return $tfvars_file; });
    $ms_sdaf->redefine(log_dir => sub { return '/tmp/openqa_logs'; });
    $ms_sdaf->redefine(git_clone => sub { return; });
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
    $ms_sdaf->redefine(enter_cmd => sub { push(@printed_lines, $_[0]); return 1; });
    $ms_sdaf->redefine(wait_serial => sub { return 1; });

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

subtest '[az_login]' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    set_var('_SECRET_AZURE_SDAF_APP_ID', 'some-id');
    set_var('_SECRET_AZURE_SDAF_APP_PASSWORD', '$0me_paSSw0rdt');
    set_var('_SECRET_AZURE_SDAF_TENANT_ID', 'some-tenant-id');

    my $env_variable_file_content;

    $ms_sdaf->redefine(record_info => sub { return; });
    $ms_sdaf->redefine(write_sut_file => sub { $env_variable_file_content = $_[1]; });
    $ms_sdaf->redefine(assert_script_run => sub { return 0; });
    $ms_sdaf->redefine(script_output => sub { return 'some-subscription-id'; });

    az_login();
    is $env_variable_file_content,
      join("\n", 'export ARM_CLIENT_ID=some-id', 'export ARM_CLIENT_SECRET=$0me_paSSw0rdt', 'export ARM_TENANT_ID=some-tenant-id'),
      'Create temporary file correctly';
    undef_variables();
};

subtest '[sdaf_cleanup] Test correct usage' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my $files_deleted;

    $ms_sdaf->redefine(generate_resource_group_name => sub { return 'ResourceGroup'; });
    $ms_sdaf->redefine(resource_group_exists => sub { return 'yes it does'; });
    $ms_sdaf->redefine(record_info => sub { return 1; });
    $ms_sdaf->redefine(sdaf_execute_remover => sub { return 0; });
    $ms_sdaf->redefine(assert_script_run => sub { $files_deleted = 1; return 1; });
    $ms_sdaf->redefine(deployment_dir => sub { return '/tmp/deployment'; });

    ok sdaf_cleanup(), 'Pass with correct usage';
    is $files_deleted, 1, 'Function must delete files at the end';
};

subtest '[sdaf_cleanup] Test remover script failures' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my $files_deleted;

    $ms_sdaf->redefine(generate_resource_group_name => sub { return 'ResourceGroup'; });
    $ms_sdaf->redefine(resource_group_exists => sub { return 'yes it does'; });
    $ms_sdaf->redefine(sdaf_execute_remover => sub { return '0'; });
    $ms_sdaf->redefine(record_info => sub { return 1; });
    $ms_sdaf->redefine(assert_script_run => sub { $files_deleted = 1; return; });
    $ms_sdaf->redefine(deployment_dir => sub { return '/tmp/deployment'; });

    $ms_sdaf->redefine(sdaf_execute_remover => sub { return 1; });
    dies_ok { sdaf_cleanup() } 'Test failing remover script';
    is $files_deleted, 1, 'Function must delete files after remover failure';
};

subtest '[sdaf_execute_remover] Check command line arguments' => sub {
    # Tested indirectly via sdaf_cleanup()

    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my @script_run_calls;
    $ms_sdaf->redefine(upload_logs => sub { return; });
    $ms_sdaf->redefine(resource_group_exists => sub { return 'yes'; });
    $ms_sdaf->redefine(generate_resource_group_name => sub { return 'WhiteBase'; });
    $ms_sdaf->redefine(log_dir => sub { return '/Principality/of'; });
    $ms_sdaf->redefine(deployment_dir => sub { return '/Principality/of/Zeon'; });
    $ms_sdaf->redefine(sdaf_scripts_dir => sub { return '/Earth/Federation'; });
    $ms_sdaf->redefine(assert_script_run => sub { return 0; });
    $ms_sdaf->redefine(record_info => sub { return 0; });
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
    $ms_sdaf->redefine(assert_script_run => sub { return 0; });
    $ms_sdaf->redefine(script_run => sub { return 0; });
    $ms_sdaf->redefine(record_info => sub { return 1; });
    $ms_sdaf->redefine(upload_logs => sub { return 1; });
    $ms_sdaf->redefine(log_dir => sub { return '/tmp/openqa_logs'; });
    $ms_sdaf->redefine(get_sdaf_deployment_command => sub { return '/execute/some/script.sh --important-option NotReallyImportant'; });
    $ms_sdaf->redefine(log_command_output => sub { return '/execute/some/script.sh --important-option NotReallyImportant >> log.file'; });

    my @invalid_deployment_types = ('sap_sys', 'orkload', 'workload', 'zone', 'system', 'sap_system ', ' sap_system', '', ' ');
    dies_ok { sdaf_execute_deployment(deployment_type => $_) } "Fail with incorrect deployment type: '$_'" foreach @invalid_deployment_types;

    $ms_sdaf->redefine(script_run => sub { return 1; });
    # Function must not fail with croak if command fails.
    my $croak_executed = 0;
    $ms_sdaf->redefine(croak => sub { $croak_executed = 1; die(); });
    dies_ok { sdaf_execute_deployment(deployment_type => 'sap_system') } 'Function dies with executed SDAF command RC!=0';
    is $croak_executed, 0, 'Ensure function failing because of correct reason';
};

subtest '[sdaf_execute_deployment] Test generated SDAF deployment command' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my $sdaf_command_no_log;

    $ms_sdaf->redefine(assert_script_run => sub { return 0; });
    $ms_sdaf->redefine(script_run => sub { return 0; });
    $ms_sdaf->redefine(record_info => sub { return 0; });
    $ms_sdaf->redefine(upload_logs => sub { return 0; });
    $ms_sdaf->redefine(log_dir => sub { return '/tmp/openqa_logs'; });
    $ms_sdaf->redefine(sdaf_scripts_dir => sub { return '/tmp/deployment'; });
    $ms_sdaf->redefine(get_os_variable => sub { return '/some/path/LAB-SECE-SAP04-INFRASTRUCTURE-6453.tfvars' });
    $ms_sdaf->redefine(set_os_variable => sub { return 1 });

    # Capture command without logging part
    $ms_sdaf->redefine(log_command_output => sub { $sdaf_command_no_log = $_[1]; return; });

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
    $ms_sdaf->redefine(assert_script_run => sub { return 0; });
    $ms_sdaf->redefine(record_info => sub { return 1; });
    $ms_sdaf->redefine(upload_logs => sub { return 0; });
    $ms_sdaf->redefine(log_dir => sub { return '/tmp/openqa_logs'; });
    $ms_sdaf->redefine(sdaf_scripts_dir => sub { return '/tmp/deployment'; });
    $ms_sdaf->redefine(get_os_variable => sub { return '/some/path/LAB-SECE-SAP04-INFRASTRUCTURE-6453.tfvars' });
    $ms_sdaf->redefine(set_os_variable => sub { return 1 });
    $ms_sdaf->redefine(log_command_output => sub { return; });
    $ms_sdaf->redefine(get_sdaf_deployment_command => sub { return 'dd if=/dev/zero of=/dev/sda'; });
    my $retry = 0;
    $ms_sdaf->redefine(script_run => sub { $retry++; print $retry; return 0 if $retry == 3; return 1 });

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

    $ms_sdaf->redefine(upload_logs => sub { return; });
    $ms_sdaf->redefine(log_dir => sub { return '/tmp/openqa_logs'; });
    $ms_sdaf->redefine(assert_script_run => sub { return 0; });
    $ms_sdaf->redefine(deployment_dir => sub { return '/tmp/SDAF'; });
    $ms_sdaf->redefine(record_info => sub { return; });
    $ms_sdaf->redefine(script_run => sub { push(@calls, $_[0]); return 0; });

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

    $ms_sdaf->redefine(upload_logs => sub { return; });
    $ms_sdaf->redefine(log_dir => sub { return '/tmp/openqa_logs'; });
    $ms_sdaf->redefine(assert_script_run => sub { return 0; });
    $ms_sdaf->redefine(deployment_dir => sub { return '/tmp/SDAF'; });
    $ms_sdaf->redefine(record_info => sub { return; });
    $ms_sdaf->redefine(script_run => sub { return; });
    $ms_sdaf->redefine(log_command_output => sub { push(@calls, $_[1]); return 0; });

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

subtest '[ansible_hanasr_show_status]' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my %calls;
    $ms_sdaf->redefine(record_info => sub { return });
    $ms_sdaf->redefine(script_output => sub {
            $calls{crm_status} = $_[0] if grep /crm status/, @_;
            $calls{saphanasr_showattr} = $_[0] if grep /SAPHanaSR-showAttr/, @_;
            return; });

    ansible_hanasr_show_status(sap_sid => 'CAT', sdaf_config_root_dir => '/cat/house');
    note("crm status command:\n\t $calls{crm_status}");
    ok(grep(/ansible QES_DB/, $calls{crm_status}), 'Execute main command');
    ok(grep(/--private-key=\/cat\/house\/sshkey/, $calls{crm_status}), 'Check for "--private-key" argument');
    ok(grep(/--inventory=CAT_hosts.yaml/, $calls{crm_status}), 'Check for "--inventory" argument');
    ok(grep(/--module-name=shell/, $calls{crm_status}), 'Check for "--module-name" argument');
    ok(grep(/--args="sudo crm status full"/, $calls{crm_status}), 'Check for executed "crm status" command');

    note("SAPHanaSR-showAttr command:\n\t $calls{saphanasr_showattr}");
    ok(grep(/--args="sudo SAPHanaSR-showAttr"/, $calls{saphanasr_showattr}), 'Check for executed "SAPHanaSR-showAttr" command');
};

subtest '[sdaf_ssh_key_from_keyvault] Test exceptions' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    $ms_sdaf->redefine(homedir => sub { return '/home/Amuro'; });
    my $croak_message;
    $ms_sdaf->redefine(croak => sub { $croak_message = $_[0]; note("\n  -->  $_[0]"); die; });
    $ms_sdaf->redefine(assert_script_run => sub { return; });
    $ms_sdaf->redefine(script_run => sub { return 1; });
    $ms_sdaf->redefine(record_info => sub { return });
    $ms_sdaf->redefine(az_keyvault_secret_show => sub { return 'lol'; });

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
    $ms_sdaf->redefine(homedir => sub { return '/home/Amuro'; });
    $ms_sdaf->redefine(az_keyvault_secret_list => sub { return ['Amuro']; });
    $ms_sdaf->redefine(az_keyvault_secret_show => sub { return; });
    $ms_sdaf->redefine(assert_script_run => sub { push @assert_script_run, $_[0]; return; });
    $ms_sdaf->redefine(script_run => sub { push @script_run, $_[0]; return; });
    $ms_sdaf->redefine(record_info => sub { return });

    sdaf_ssh_key_from_keyvault(key_vault => 'SCV-70 White Base');
    note("\n --> " . join("\n --> ", @assert_script_run));
    ok(grep(/mkdir -p/, @assert_script_run), 'Create ssh directory');
    ok(grep(/touch/, @assert_script_run), 'Create ssh file');
    ok(grep(/chmod 700/, @assert_script_run), 'Set ssh directory permissions');
    ok(grep(/chmod 600/, @assert_script_run), 'Set public key permissions');

    note("\n --> " . join("\n --> ", @script_run));
    ok(grep(//, @assert_script_run), 'Validate ssh key');
};

done_testing;
