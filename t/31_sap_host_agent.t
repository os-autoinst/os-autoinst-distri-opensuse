use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use testapi;
use sles4sap::sap_host_agent;

subtest '[parse_instance_name] ' => sub {
    my ($sid, $id) = @{parse_instance_name('POO08')};
    is $sid, 'POO', "Return correct SID: $sid";
    is $id, '08', "Return correct ID: $id";
};

subtest '[parse_instance_name] Exceptions' => sub {
    dies_ok { parse_instance_name('POO0') } 'Instance name with less than 5 characters';
    dies_ok { parse_instance_name('POO0ASDF') } 'Instance name with more than 5 characters';
    dies_ok { parse_instance_name('POO0 ') } 'Instance name contains spaces';
    dies_ok { parse_instance_name('Poo0a') } 'Instance name contains lowercase characters';
    dies_ok { parse_instance_name('POO0.') } 'Instance name contains any non-word characters';
};

subtest '[saphostctrl_list_instances] Command composition' => sub {
    my $saphostagent = Test::MockModule->new('sles4sap::sap_host_agent', no_auto => 1);
    my $mock_data = ' Inst Info : HDB - 00 - qesdhdb01l000 - 753, patch 1236, changelist 2222163';
    my @cmd_args;
    $saphostagent->redefine(script_output => sub { @cmd_args = @_; return $mock_data; });
    $saphostagent->redefine(get_instance_type => sub { return 'ERS'; });

    saphostctrl_list_instances();
    note("\n  -->  " . join("\n  -->  ", @cmd_args));
    ok((grep /\/usr\/sap\/hostctrl\/exe\/saphostctrl/, @cmd_args), 'Base saphostctrl command');
    ok((grep /-function/, @cmd_args), 'Add "-function" argument');
    ok((grep /ListInstances/, @cmd_args), 'Execute "ListInstances" function');
    ok((grep /| grep 'Inst Info'/, @cmd_args), 'Filter out instance info');
};

subtest '[saphostctrl_list_instances] Command composition - switch user' => sub {
    my $saphostagent = Test::MockModule->new('sles4sap::sap_host_agent', no_auto => 1);
    my $mock_data = ' Inst Info : HDB - 00 - qesdhdb01l000 - 753, patch 1236, changelist 2222163';
    my @cmd_args;
    $saphostagent->redefine(script_output => sub { @cmd_args = @_; return $mock_data; });
    $saphostagent->redefine(get_instance_type => sub { return 'ERS'; });

    saphostctrl_list_instances();
    note("\n  -->  " . join("\n  -->  ", @cmd_args));
    ok((grep /\/usr\/sap\/hostctrl\/exe\/saphostctrl/, @cmd_args), 'Base saphostctrl command');
    ok((grep /-function/, @cmd_args), 'Add "-function" argument');
    ok((grep /ListInstances/, @cmd_args), 'Execute "ListInstances" function');
    ok((grep /| grep 'Inst Info'/, @cmd_args), 'Filter out instance info');
};

done_testing;
