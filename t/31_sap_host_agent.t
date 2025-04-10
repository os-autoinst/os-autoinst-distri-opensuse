use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use testapi;
use sles4sap::sap_host_agent;

subtest '[saphostctrl_list_databases] Verify command compilation' => sub {
    my $saphostctrl_output = 'Instance name: PRD00, Hostname: qesdhdb01l029, Vendor: HDB, Type: hdb, Release: 42';
    my $mock = Test::MockModule->new('sles4sap::sap_host_agent', no_auto => 1);
    my @calls;
    $mock->redefine(script_output => sub { push @calls, $_[0]; return $saphostctrl_output; });
    $mock->redefine(assert_script_run => sub { return 0; });

    saphostctrl_list_databases();
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((grep /saphostctrl/, @calls), 'Execute "saphostctrl" binary');
    ok((grep /-function ListDatabases/, @calls), 'Execute "ListDatabases" function');
    ok((grep /\| grep Instance/, @calls), 'Show only "Instances" entries');
};

subtest '[saphostctrl_list_databases] Verify command compilation - executed as root' => sub {
    my $saphostctrl_output = 'Instance name: PRD00, Hostname: qesdhdb01l029, Vendor: HDB, Type: hdb, Release: 42';
    my $mock = Test::MockModule->new('sles4sap::sap_host_agent', no_auto => 1);
    my @calls;
    $mock->redefine(script_output => sub { push @calls, $_[0]; return $saphostctrl_output; });
    $mock->redefine(assert_script_run => sub { return 0; });

    saphostctrl_list_databases(as_root => 1);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((grep /sudo/, @calls), 'Execute as root');
};

subtest '[saphostctrl_list_databases] Verify output' => sub {
    my $saphostctrl_output = 'Instance name: PRD00, Hostname: qesdhdb01l029, Vendor: HDB, Type: hdb, Release: 42';

    my $mock = Test::MockModule->new('sles4sap::sap_host_agent', no_auto => 1);
    $mock->redefine(script_output => sub { return $saphostctrl_output; });
    $mock->redefine(assert_script_run => sub { return 0; });

    my @output = @{saphostctrl_list_databases()};
    is $output[0]->{instance_name}, 'PRD00', 'Check "instance_name" value';
    is $output[0]->{hostname}, 'qesdhdb01l029', 'Check "hostname" value';
    is $output[0]->{vendor}, 'HDB', 'Check "vendor" value';
    is $output[0]->{type}, 'hdb', 'Check "type" value';
    is $output[0]->{release}, '42', 'Check "release" value';
};

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

done_testing;
