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
use sles4sap::sap_deployment_automation_framework::ansible;

sub undef_variables {
    my @openqa_variables = qw( PUBLIC_CLOUD_REGION SDAF_ANSIBLE_VERBOSITY_LEVEL);
    set_var($_, '') foreach @openqa_variables;
}

subtest '[sdaf_execute_playbook] Fail with missing mandatory arguments' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::ansible', no_auto => 1);
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
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::ansible', no_auto => 1);
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
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::ansible', no_auto => 1);
    my @calls;

    $ms_sdaf->redefine(script_run => sub { return; });
    $ms_sdaf->redefine(deployment_dir => sub { return '/directory'; });
    $ms_sdaf->redefine(log_command_output => sub { push(@calls, $_[1]); return 0; });
    $ms_sdaf->noop(qw(assert_script_run record_info log_dir upload_logs));
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

subtest '[register_byos] Test exceptions' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::ansible', no_auto => 1);
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
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::ansible', no_auto => 1);
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

subtest '[playbook_set] Test exceptions' => sub {
    my $playbooks = sles4sap::sap_deployment_automation_framework::ansible->new();
    my @components = ('db_install', 'db_ha', 'nw_pas', 'nw_aas', 'nw_ensa');

    dies_ok { $playbooks->set() } 'Croak with missing $args{components}';
    dies_ok { $playbooks->set(@components) } 'Argument <$components> must be an ARRAYREF';
};

subtest '[playbook_get] Validate playbook order' => sub {
    my $playbooks = sles4sap::sap_deployment_automation_framework::ansible->new();
    my $components = ['db_install', 'db_ha', 'nw_pas', 'nw_aas', 'nw_ensa'];
    my @expected_order = qw(
      pb_get-sshkey.yaml
      playbook_00_validate_parameters.yaml
      playbook_01_os_base_config.yaml
      playbook_02_os_sap_specific_config.yaml
      playbook_03_bom_processing.yaml
      playbook_04_00_00_db_install.yaml
      playbook_05_00_00_sap_scs_install.yaml
      playbook_05_01_sap_dbload.yaml
      playbook_04_00_01_db_ha.yaml
      playbook_05_02_sap_pas_install.yaml
      playbook_05_03_sap_app_install.yaml
      playbook_06_00_acss_registration.yaml
    );
    my $playbook_list = $playbooks->set($components);
    ok($playbook_list, '"set" method returns list of playbooks served');
    # method `get` is expected to return nex playbook in the list
    my $index = 1;
    for my $playbook_filename (@expected_order) {
        is $playbooks->get->{playbook_filename}, $playbook_filename, "Playbook no. $index must be: $playbook_filename";
        $index++;
    }

    is $playbooks->get->{playbook_filename}, undef, 'Method returns "undef" after all playbooks are served';
    dies_ok { $playbooks->set($components) } 'Calling method "set" second time must fail.';
};

done_testing;
