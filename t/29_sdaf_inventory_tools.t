use strict;
use warnings;
use Test::Mock::Time;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use testapi;
use sles4sap::sap_deployment_automation_framework::inventory_tools;
use Data::Dumper;

# SDAF inventory data example:
# - Single host group
# - Group with multiple hosts
# - Empty group

my $mock_inventory_data = {
    QES_PAS => {
        hosts => {
            Freddie => {
                ansible_connection => 'ssh',
                connection_type => 'key',
                virtual_host => 'Mercury',
                ansible_user => 'freddie',
                vm_name => 'FreddieMercury',
                become_user => 'root',
                ansible_host => '10.10.10.2',
                os_type => 'linux'
            }
        },
        vars => undef
    },
    QES_DB => {
        vars => undef,
        hosts => {
            John => {
                ansible_connection => 'ssh',
                connection_type => 'key',
                virtual_host => 'Deacon',
                ansible_user => 'john',
                vm_name => 'JohnDeacon',
                become_user => 'john',
                ansible_host => '10.10.10.3',
                os_type => 'linux'
            },
            Roger => {
                ansible_connection => 'ssh',
                connection_type => 'key',
                virtual_host => 'Taylor',
                ansible_user => 'roger',
                vm_name => 'RogerTaylor',
                become_user => 'root',
                ansible_host => '10.10.10.1',
                os_type => 'linux'
            }
        }
    },
    QES_AAS => {
        vars => undef,
        hosts => undef
    }
};

subtest '[prepare_ssh_config] ' => sub {
    my $mock = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::inventory_tools', no_auto => 1);
    my $croak_message;
    $mock->redefine(croak => sub { $croak_message = $_[0]; die; });
    $mock->redefine(record_info => sub { return; });
    my %mandatory_args = (
        inventory_data => 'Radio GaGa',
        jump_host_ip => '8.8.8.8',
        jump_host_user => 'Freddie',
    );
    foreach (keys(%mandatory_args)) {
        my $original_value = $mandatory_args{$_};
        $mandatory_args{$_} = undef;
        dies_ok { prepare_ssh_config(%mandatory_args) } "Croak with mandatory argument '$_' undefined";
        ok($croak_message =~ /$_/, "Verify croak message: $croak_message");
        $mandatory_args{$_} = $original_value;
    }
};

subtest '[prepare_ssh_config] ' => sub {
    my $mock = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::inventory_tools', no_auto => 1);
    my $jump_config_content;
    my $db_host_A_content;
    my $db_host_B_content;

    $mock->redefine(record_info => sub { return; });
    $mock->redefine(script_output => sub { return 'I`ve got to break free'; });
    $mock->redefine(ssh_config_entry_add => sub {
            $jump_config_content = join(' ', @_) if join(' ', @_) =~ /entry_name deployer_jump/;
            $db_host_A_content = join(' ', @_) if join(' ', @_) =~ /entry_name John/;
            $db_host_B_content = join(' ', @_) if join(' ', @_) =~ /entry_name Freddie/;
            return; });

    prepare_ssh_config(inventory_data => $mock_inventory_data, jump_host_ip => '127.0.0.1', jump_host_user => 'Freddie');
    note("\n --> $jump_config_content");
    ok($jump_config_content =~ /entry_name deployer_jump/, 'Jump host: entry_name');
    ok($jump_config_content =~ /user Freddie/, 'Jump host: user');
    ok($jump_config_content =~ /hostname 127.0.0.1/, 'Jump host: hostname');
    ok($jump_config_content =~ /identities_only yes/, 'Jump host: identities_only');
    ok($jump_config_content =~ /identity_file/, 'Jump host: identity_file');

    note("\n --> $db_host_A_content");
    ok($db_host_A_content =~ /entry_name John/, 'DB host A: entry_name');
    ok($db_host_A_content =~ /user john/, 'DB host A: user');
    ok($db_host_A_content =~ /hostname 10.10.10.3/, 'DB host A: hostname');
    ok($db_host_A_content =~ /identities_only yes/, 'DB host A: identities_only');
    ok($db_host_A_content =~ /identity_file/, 'DB host A: identity_file');
    ok($db_host_A_content =~ /proxy_jump deployer_jump/, 'DB host A: proxy_jump');
    ok($db_host_A_content =~ /strict_host_key_checking no/, 'DB host A: strict_host_key_checking');

    note("\n --> $db_host_B_content");
    ok($db_host_B_content =~ /entry_name Freddie/, 'DB host A: entry_name');
    ok($db_host_B_content =~ /user freddie/, 'DB host A: user');
    ok($db_host_B_content =~ /hostname 10.10.10.2/, 'DB host A: hostname');
    ok($db_host_B_content =~ /identities_only yes/, 'DB host A: identities_only');
    ok($db_host_B_content =~ /identity_file/, 'DB host A: identity_file');
    ok($db_host_B_content =~ /proxy_jump deployer_jump/, 'DB host A: proxy_jump');
    ok($db_host_B_content =~ /strict_host_key_checking no/, 'DB host A: strict_host_key_checking');
};

subtest '[create_redirection_data] ' => sub {
    set_var('SAP_SID', 'QES');
    my $result = create_redirection_data(inventory_data => $mock_inventory_data);
    note("\n -->" . Dumper($result));
    foreach ('db_hana', 'nw_pas') {
        ok($result->{$_}, "Check presence of host group: $_");
    }

    foreach ('John', 'Freddie', 'Roger') {
        ok(grep(/$_/, keys(%{$result->{db_hana}})), "Check presence of database hostname: $_");
    }
    set_var('SAP_SID', undef);
};

done_testing;
