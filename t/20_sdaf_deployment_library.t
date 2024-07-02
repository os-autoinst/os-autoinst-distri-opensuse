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
    $ms_sdaf->redefine(record_info => sub { return; });
    $ms_sdaf->redefine(git_clone => sub { return; });
    $ms_sdaf->redefine(log_dir => sub { return '/tmp/openqa_logs'; });
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
    $ms_sdaf->redefine(record_info => sub { return; });
    $ms_sdaf->redefine(assert_script_run => sub { push(@mkdir_commands, $_[0]) if grep(/mkdir/, @_); return 1; });
    $ms_sdaf->redefine(deployment_dir => sub { return '/tmp/SDAF'; });
    $ms_sdaf->redefine(get_tfvars_path => sub { return $tfvars_file; });
    $ms_sdaf->redefine(log_dir => sub { return '/tmp/openqa_logs'; });
    $ms_sdaf->redefine(git_clone => sub { return; });

    set_var('SDAF_GIT_AUTOMATION_REPO', 'https://github.com/Azure/sap-automation/tree/main');
    set_var('SDAF_GIT_TEMPLATES_REPO', 'https://github.com/Azure/SAP-automation-samples/tree/main');

    prepare_sdaf_project(%arguments);
    is $mkdir_commands[0], 'mkdir -p /tmp/openqa_logs', 'Create logging directory';
    is $mkdir_commands[1], 'mkdir -p Azure_SAP_Automated_Deployment/WORKSPACES/DEPLOYER/LAB-SECE-DEP05-INFRASTRUCTURE',
      'Create workspace directory';
    undef_variables;
};

subtest '[prepare_tfvars_file] Test missing or incorrect args' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    $ms_sdaf->redefine(data_url => sub { return 'openqa.suse.de/data/' . join('', @_); });
    my @incorrect_deployment_types = qw(funny_library eployer sap_ workload _zone);

    dies_ok { prepare_tfvars_file(); } 'Fail without specifying "$deployment_type"';
    dies_ok { prepare_tfvars_file(deployment_type => $_); } "Fail with incorrect deployment type: $_" foreach @incorrect_deployment_types;

};

subtest '[prepare_tfvars_file] Test curl commands' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my $curl_cmd;
    $ms_sdaf->redefine(assert_script_run => sub { $curl_cmd = $_[0] if grep(/curl/, $_[0]); return 1; });
    $ms_sdaf->redefine(upload_logs => sub { return 1; });
    $ms_sdaf->redefine(replace_tfvars_variables => sub { return 1; });
    $ms_sdaf->redefine(get_os_variable => sub { return $_[0]; });
    $ms_sdaf->redefine(data_url => sub { return 'http://openqa.suse.de/data/' . join('', @_); });

    # '-o' is only for checking if correct parameter gets picked from %tfvars_os_variable
    my %expected_results = (
        deployer => 'curl -v -fL http://openqa.suse.de/data/sles4sap/sdaf/DEPLOYER.tfvars -o deployer_parameter_file',
        sap_system => 'curl -v -fL http://openqa.suse.de/data/sles4sap/sdaf/SAP_SYSTEM.tfvars -o sap_system_parameter_file',
        workload_zone => 'curl -v -fL http://openqa.suse.de/data/sles4sap/sdaf/WORKLOAD_ZONE.tfvars -o workload_zone_parameter_file',
        library => 'curl -v -fL http://openqa.suse.de/data/sles4sap/sdaf/LIBRARY.tfvars -o library_parameter_file'
    );

    for my $type (keys %expected_results) {
        prepare_tfvars_file(deployment_type => $type);
        is $curl_cmd, $expected_results{$type}, "Return correct url and tfvars variable";
    }
};

subtest '[replace_tfvars_variables] Test correct variable replacement' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    $ms_sdaf->redefine(assert_script_run => sub { return 1; });
    $ms_sdaf->redefine(script_output => sub { return '/somewhere/in/the/Shire'; });
    $ms_sdaf->redefine(upload_logs => sub { return 1; });
    $ms_sdaf->redefine(data_url => sub { return 'openqa.suse.de/data/' . join('', @_); });
    $ms_sdaf->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my %replaced_variables;
    $ms_sdaf->redefine(file_content_replace => sub { %replaced_variables = @_[1 .. $#_]; return 1; });

    my %expected_variables = (
        SDAF_ENV_CODE => 'Balbo',
        PUBLIC_CLOUD_REGION => 'Mungo',
        SDAF_RESOURCE_GROUP => 'Bungo',
        SDAF_VNET_CODE => 'Bilbo',
        SAP_SID => 'Frodo'
    );

    for my $var_name (keys %expected_variables) {
        set_var($var_name, $expected_variables{$var_name});
    }
    prepare_tfvars_file(deployment_type => 'workload_zone');

    for my $var_name (keys(%expected_variables)) {
        is $replaced_variables{'%' . $var_name . '%'}, $expected_variables{$var_name},
          "Pass with %$var_name% replaced by '$expected_variables{$var_name}'";
    }
    undef_variables();
};

subtest '[serial_console_diag_banner] ' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my $printed_output;
    $ms_sdaf->redefine(script_run => sub { $printed_output = $_[0]; return 1; });
    my $correct_output = "#########################    Module: deploy_sdaf.pm    #########################";

    serial_console_diag_banner('Module: deploy_sdaf.pm');
    is $printed_output, $correct_output, "Print banner correctly in uppercase:\n$correct_output";
    dies_ok { serial_console_diag_banner() } 'Fail with missing test to be printed';
    dies_ok { serial_console_diag_banner('exeCuTing deploYment' x 6) } 'Fail with string exceeds max number of characters';
};

subtest '[sdaf_prepare_ssh_keys]' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my $get_ssh_command;
    my %private_key;
    my %pubkey;
    $ms_sdaf->redefine(script_run => sub { return 0; });
    $ms_sdaf->redefine(homedir => sub { return '/home/dir/'; });
    $ms_sdaf->redefine(assert_script_run => sub { return 0; });
    $ms_sdaf->redefine(script_output => sub {
            $get_ssh_command = $_[0] if grep /keyvault/, @_;
            return "
LAB-SECE-DEP05-sshkey
LAB-SECE-DEP05-sshkey-pub
LAB-SECE-DEP05-ssh
"
    });
    $ms_sdaf->redefine(az_get_ssh_key => sub {
            %private_key = @_ if grep /sshkey$/, @_;
            %pubkey = @_ if grep /sshkey-pub$/, @_;
    });

    sdaf_prepare_ssh_keys(deployer_key_vault => 'LABSECEDEP05userDDF');
    is $get_ssh_command, 'az keyvault secret list --vault-name LABSECEDEP05userDDF --query [].name --output tsv | grep sshkey',
      'Return correct command for retrieving private key';
    is $pubkey{ssh_key_name}, 'LAB-SECE-DEP05-sshkey-pub', 'Public key';
    is $private_key{ssh_key_name}, 'LAB-SECE-DEP05-sshkey', 'Private key';

    dies_ok { sdaf_prepare_ssh_keys() } 'Fail with missing deployer key vault argument';

    $ms_sdaf->redefine(script_output => sub { return 1 });
    dies_ok { sdaf_prepare_ssh_keys(deployer_key_vault => 'LABSECEDEP05userDDF') } 'Fail with not keyfile being found';
};

subtest '[sdaf_get_deployer_ip] Test passing behavior' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    my @script_output_commands;
    $ms_sdaf->redefine(record_info => sub { return; });
    $ms_sdaf->redefine(script_output => sub {
            push @script_output_commands, $_[0];
            return 'vmhana01' if grep /vm\slist\s/, @_;
            return '192.168.0.1'; });

    my $ip_addr = sdaf_get_deployer_ip(deployer_resource_group => 'OpenQA_SDAF_0079');
    is $script_output_commands[0], 'az vm list --resource-group OpenQA_SDAF_0079 --query [].name --output tsv',
      'Pass using correct command for retrieving vm list';
    is $script_output_commands[1],
      'az vm list-ip-addresses --resource-group OpenQA_SDAF_0079 --name vmhana01 --query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" -o tsv',
      'Pass using correct command for retrieving public IP addr';
    is $ip_addr, '192.168.0.1', 'Pass returning correct IP addr';

    dies_ok { sdaf_get_deployer_ip() } 'Fail with missing deployer resource group argument';
    $ms_sdaf->redefine(script_output => sub { return '192.168.0.1'; });
};

subtest '[sdaf_get_deployer_ip] Test expected failures' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment', no_auto => 1);
    $ms_sdaf->redefine(record_info => sub { return; });
    my @incorrect_ip_addresses = (
        '192.168.0.500',
        '192.168.o.5',
        '192.168.0.',
        '2001:db8:85a3::8a2e:370:7334'
    );

    dies_ok { sdaf_get_deployer_ip() } 'Fail with missing deployer resource group argument';
    for my $ip_input (@incorrect_ip_addresses) {
        $ms_sdaf->redefine(script_output => sub { return $ip_input; });
        dies_ok { sdaf_get_deployer_ip(deployer_resource_group => 'Open_QA_DEPLOYER') } "Detect incorrect IP addr pattern: $ip_input";
    }
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

    $ms_sdaf->redefine(get_current_job_id => sub { return '0097'; });
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

done_testing;
