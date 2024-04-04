use strict;
use warnings;
use Test::Mock::Time;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use List::MoreUtils qw(uniq);
use Data::Dumper;
use testapi;
use sles4sap::sdaf_library;


sub undef_variables {
    my @openqa_variables = qw(
      _SECRET_AZURE_SDAF_APP_ID
      _SECRET_AZURE_SDAF_APP_PASSWORD
      _SECRET_AZURE_SDAF_TENANT_ID
    );
    set_var($_, '') foreach @openqa_variables;
}

subtest '[get_tfvars_path] Test passing scenarios - test using prepare_sdaf_repo()' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sdaf_library', no_auto => 1);
    my %arguments = (
        sap_sid => 'QAS',
        deployer_vnet_code => 'DEP05',
        workload_vnet_code => 'SAP04',
        region_code => 'SECE',
        env_code => 'LAB'
    );
    my %expected_results = (
        workload_zone => '/tmp/Azure_SAP_Automated_Deployment_0079/WORKSPACES/LANDSCAPE/LAB-SECE-SAP04-INFRASTRUCTURE/LAB-SECE-SAP04-INFRASTRUCTURE-0079.tfvars',
        sap_system => '/tmp/Azure_SAP_Automated_Deployment_0079/WORKSPACES/SYSTEM/LAB-SECE-SAP04-QAS/LAB-SECE-SAP04-QAS-0079.tfvars',
        library => '/tmp/Azure_SAP_Automated_Deployment_0079/WORKSPACES/LIBRARY/LAB-SECE-SAP_LIBRARY/LAB-SECE-SAP_LIBRARY.tfvars',
        deployer => '/tmp/Azure_SAP_Automated_Deployment_0079/WORKSPACES/DEPLOYER/LAB-SECE-DEP05-INFRASTRUCTURE/LAB-SECE-DEP05-INFRASTRUCTURE.tfvars'
    );
    my %get_tfvars_results;
    $ms_sdaf->redefine(record_info => sub { return; });
    $ms_sdaf->redefine(assert_script_run => sub { return 1; });
    $ms_sdaf->redefine(get_current_job_id => sub { return '0079'; });
    $ms_sdaf->redefine(dirname => sub {
            $get_tfvars_results{workload_zone} = $_[0] if grep(/LANDSCAPE/, @_);
            $get_tfvars_results{sap_system} = $_[0] if grep(/SYSTEM/, @_);
            $get_tfvars_results{library} = $_[0] if grep(/LIBRARY/, @_);
            $get_tfvars_results{deployer} = $_[0] if grep(/DEPLOYER/, @_);
            return @_;
    });

    prepare_sdaf_repo(%arguments);
    foreach (keys(%expected_results)) {
        is $get_tfvars_results{$_}, $expected_results{$_}, "Pass with corrct tfvars path generated for: $_";
    }

};

subtest '[get_tfvars_path] Test unsupported deployment types - test using set_common_sdaf_os_env()' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sdaf_library', no_auto => 1);
    my %arguments = (
        sap_sid => 'QAS',
        deployer_vnet_code => 'DEP05',
        workload_vnet_code => 'SAP04',
        region_code => 'SECE',
        env_code => 'LAB',
        sdaf_tfstate_storage_account => 'labsecetfstate300',
        sdaf_key_vault => 'LABSECEDEP05userDDF',
        subscription_id => 'RX-78',
    );
    my @unexpected_failures;

    $ms_sdaf->redefine(record_info => sub { return; });
    $ms_sdaf->redefine(assert_script_run => sub { return 1; });
    $ms_sdaf->redefine(get_current_job_id => sub { return '0079'; });
    $ms_sdaf->redefine(deployment_dir => sub { return '/tmp/'; });
    $ms_sdaf->redefine(serial_console_diag_banner => sub { return; });
    $ms_sdaf->redefine(create_sdaf_os_var_file => sub { return; });
    # This prevents get_required_var() to fail, creating false positive
    $ms_sdaf->redefine(get_required_var => sub { return undef });
    # Search for correct fail message, weeding out false positives
    $ms_sdaf->redefine(croak => sub {
            croak() if grep(/^Invalid/, @_);
            # record unexpected fail message
            push(@unexpected_failures, $_[0]) unless grep(/^Invalid/, @_);
    });

    my @unsupported_types = ('workload', 'sut', 'funky stuff', '');
    foreach (@unsupported_types) {
        my $orig_value = $arguments{deployment_type};
        $arguments{deployment_type} = $_;
        dies_ok { set_common_sdaf_os_env(%arguments) } "Dies with invalid deployment type: $_";
        $arguments{deployment_type} = $orig_value;
    }
    is @unexpected_failures, 0,
      "Check for unexpected failures within unit test.\n\t Unexpected messages found:" . join("\n", @unexpected_failures);
};

subtest '[prepare_sdaf_repo]' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sdaf_library', no_auto => 1);
    my %arguments = (
        sap_sid => 'QAS',
        region_code => 'SECE',
        env_code => 'LAB',
        deployer_vnet_code => 'DEP05',
        workload_vnet_code => 'SAP04'
    );

    my @git_commands;
    my %vnet_checks;
    $ms_sdaf->redefine(record_info => sub { return; });
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

    prepare_sdaf_repo(%arguments);


    is $git_commands[0], 'git clone https://github.com/Azure/sap-automation.git sap-automation --quiet', 'Clone SDAF automation code repo';
    is $git_commands[1], 'git clone https://github.com/Azure/sap-automation-samples.git samples --quiet', 'Clone SDAF automation samples repo';

    # Check correct vnet codes
    is $vnet_checks{library}, '', 'Return library without vnet code';
    is $vnet_checks{deployer}, $arguments{deployer_vnet_code}, 'Return correct vnet code for deployer';
    is $vnet_checks{workload_zone}, $arguments{workload_vnet_code}, 'Return correct vnet code for workload zone';
    is $vnet_checks{sap_system}, $arguments{workload_vnet_code}, 'Return correct vnet code for sap SUT';

};

subtest '[prepare_sdaf_repo] Check directory creation' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sdaf_library', no_auto => 1);
    my %arguments = (
        sap_sid => 'QAS',
        region_code => 'SECE',
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

    prepare_sdaf_repo(%arguments);
    is $mkdir_commands[0], 'mkdir -p /tmp/openqa_logs', 'Create logging directory';
    is $mkdir_commands[1], 'mkdir -p Azure_SAP_Automated_Deployment/WORKSPACES/DEPLOYER/LAB-SECE-DEP05-INFRASTRUCTURE',
      'Create workspace directory';
};

subtest '[prepare_tfvars_file] Test missing or incorrect args' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sdaf_library', no_auto => 1);
    $ms_sdaf->redefine(data_url => sub { return 'openqa.suse.de/data/' . join('', @_); });
    my @incorrect_deployment_types = qw(funny_library eployer sap_ workload _zone);

    dies_ok { prepare_tfvars_file(); } 'Fail without specifying "$deployment_type"';
    dies_ok { prepare_tfvars_file($_); } "Fail with incorrect deployment type: $_" foreach @incorrect_deployment_types;

};

subtest '[serial_console_diag_banner] ' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sdaf_library', no_auto => 1);
    my $printed_output;
    $ms_sdaf->redefine(script_run => sub { $printed_output = $_[0]; return 1; });
    my $correct_output = "##########################    EXECUTING DEPLOYMENT    ##########################";

    serial_console_diag_banner('exeCuTing deploYment');
    is $printed_output, $correct_output, "Print banner correctly in uppercase:\n$correct_output";
    dies_ok { serial_console_diag_banner() } 'Fail with missing test to be printed';
    dies_ok { serial_console_diag_banner('exeCuTing deploYment' x 6) } 'Fail with string exceeds max number of characters';
};

subtest '[sdaf_prepare_ssh_keys]' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sdaf_library', no_auto => 1);
    my $get_ssh_command;
    my %private_key;
    my %pubkey;
    $ms_sdaf->redefine(script_run => sub { return 0; });
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
    my $ms_sdaf = Test::MockModule->new('sles4sap::sdaf_library', no_auto => 1);
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
    is $ip_addr, '192.168.0.1', 'Pass returing correct IP addr';

    dies_ok { sdaf_get_deployer_ip() } 'Fail with missing deployer resource group argument';
    $ms_sdaf->redefine(script_output => sub { return '192.168.0.1'; });
};

subtest '[sdaf_get_deployer_ip] Test expected failures' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sdaf_library', no_auto => 1);
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

subtest '[create_sdaf_os_var_file]' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sdaf_library', no_auto => 1);
    my %arguments = (
        sap_sid => 'QAS',
        deployer_vnet_code => 'DEP05',
        workload_vnet_code => 'SAP04',
        region_code => 'SECE',
        env_code => 'LAB',
        sdaf_tfstate_storage_account => 'labsecetfstate300',
        sdaf_key_vault => 'LABSECEDEP05userDDF',
        subscription_id => 'RX-78',
    );
    my $file_content;
    $ms_sdaf->redefine(write_sut_file => sub { $file_content = $_[1]; });
    $ms_sdaf->redefine(assert_script_run => sub { return 0; });
    $ms_sdaf->redefine(get_tfvars_path => sub { return '/some/path'; });
    $ms_sdaf->redefine(deployment_dir => sub { return '/deployment'; });

    my $expected_result = join("\n",
        'export env_code=LAB',
        'export deployer_vnet_code=DEP05',
        'export workload_vnet_code=SAP04',
        'export sap_env_code=LAB',
        'export deployer_env_code=LAB',
        'export region_code=SECE',
        'export SID=QAS',
        'export ARM_SUBSCRIPTION_ID=RX-78',
        'export SAP_AUTOMATION_REPO_PATH=/deployment/sap-automation/',
        'export DEPLOYMENT_REPO_PATH=${SAP_AUTOMATION_REPO_PATH}',
        'export CONFIG_REPO_PATH=/deployment/WORKSPACES',
        'export deployer_parameter_file=/some/path',
        'export library_parameter_file=/some/path',
        'export sap_system_parameter_file=/some/path',
        'export workload_zone_parameter_file=/some/path',
        'export tfstate_storage_account=labsecetfstate300',
        'export key_vault=LABSECEDEP05userDDF'
    );

    set_common_sdaf_os_env(%arguments);
    is $file_content, $expected_result, 'Compile variable file correctly';

};

subtest '[az_login]' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sdaf_library', no_auto => 1);
    set_var('_SECRET_AZURE_SDAF_APP_ID', 'some-id');
    set_var('_SECRET_AZURE_SDAF_APP_PASSWORD', '$0me_paSSw0rdt');
    set_var('_SECRET_AZURE_SDAF_TENANT_ID', 'some-tennant-id');

    my $variable_file_content;

    $ms_sdaf->redefine(get_current_job_id => sub { return '0097'; });
    $ms_sdaf->redefine(record_info => sub { return; });
    $ms_sdaf->redefine(write_sut_file => sub { $variable_file_content = $_[1]; });
    $ms_sdaf->redefine(assert_script_run => sub { return 0; });
    $ms_sdaf->redefine(script_output => sub { return 'some-subscription-id'; });

    az_login();
    is $variable_file_content,
      join("\n", 'export ARM_CLIENT_ID=some-id', 'export ARM_CLIENT_SECRET=$0me_paSSw0rdt', 'export ARM_TENANT_ID=some-tennant-id'),
      'Create temporary file correctly';
    undef_variables();
};



done_testing;
