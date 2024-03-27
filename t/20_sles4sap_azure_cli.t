use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use Test::Mock::Time;

use List::Util qw(any none);
use sles4sap::azure_cli;

subtest '[az_group_create]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_group_create(name => 'Arlecchino', region => 'Pulcinella');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az group create/ } @calls), 'Correct composition of the main command');
    ok((any { /--location Pulcinella/ } @calls), '--location');
    ok((any { /--name Arlecchino/ } @calls), '--name');
};


subtest '[az_group_create] missing args' => sub {
    dies_ok { az_group_create(region => 'Pulcinella') } 'Die for missing argument name';
    dies_ok { az_group_create(name => 'Arlecchino') } 'Die for missing argument region';
    ok 1;
};


subtest '[az_network_vnet_create]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_network_vnet_create(
        resource_group => 'Arlecchino',
        region => 'Pulcinella',
        vnet => 'Pantalone',
        snet => 'Colombina');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network vnet create/ } @calls), 'Correct composition of the main command');
};


subtest '[az_network_nsg_create]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_network_nsg_create(
        resource_group => 'Arlecchino',
        name => 'Brighella');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network nsg create/ } @calls), 'Correct composition of the main command');
};


subtest '[az_network_publicip_create]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_network_publicip_create(
        resource_group => 'Arlecchino',
        name => 'Truffaldino');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network public-ip create/ } @calls), 'Correct composition of the main command');
    ok((none { /allocation-method/ } @calls), 'No argument --allocation-method');
    ok((none { /zone/ } @calls), 'No argument --zone');
};


subtest '[az_network_publicip_create] with optional arguments' => sub {
    my $qesap = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_network_publicip_create(
        resource_group => 'Arlecchino',
        name => 'Truffaldino',
        allocation_method => 'Static',
        zone => 'Venezia Mestre');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /--allocation-method Static/ } @calls), 'Argument --allocation-method');
    ok((any { /--zone Venezia Mestre/ } @calls), 'Argument --zone');
};


subtest '[az_network_lb_create]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_network_lb_create(
        resource_group => 'Arlecchino',
        name => 'Truffaldino',
        vnet => 'Pantalone',
        snet => 'Colombina',
        backend => 'Smeraldina',
        frontend_ip => 'Momolo');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network lb create/ } @calls), 'Correct composition of the main command');
};


subtest '[az_vm_as_create]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_vm_as_create(
        resource_group => 'Arlecchino',
        name => 'Truffaldino',
        region => 'Pulcinella');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az vm availability-set create/ } @calls), 'Correct composition of the main command');
};


subtest '[az_vm_create]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_vm_create(
        resource_group => 'Arlecchino',
        name => 'Truffaldino',
        image => 'Mirandolina');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az vm create/ } @calls), 'Correct composition of the main command');
};

subtest '[az_vm_create] with public IP' => sub {
    my $qesap = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_vm_create(
        resource_group => 'Arlecchino',
        name => 'Truffaldino',
        image => 'Mirandolina',
        public_ip => 'Fulgenzio');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /--public-ip-address Fulgenzio/ } @calls), 'custom Public IP address');
};

subtest '[az_vm_create] with no public IP' => sub {
    my $qesap = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_vm_create(
        resource_group => 'Arlecchino',
        name => 'Truffaldino',
        image => 'Mirandolina',
        public_ip => '""');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /--public-ip-address ""/ } @calls), 'empty Public IP address');
};

subtest '[az_vm_openport]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_vm_openport(
        resource_group => 'Arlecchino',
        name => 'Truffaldino',
        port => 80);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az vm open-port/ } @calls), 'Correct composition of the main command');
    ok((any { /--port 80/ } @calls), 'Correct port argument');
};

subtest '[az_nic_id_get]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'Eugenia'; });
    my $res = az_nic_id_get(
        resource_group => 'Arlecchino',
        name => 'Truffaldino');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az vm show/ } @calls), 'Correct composition of the main command');
    ok(($res eq 'Eugenia'), 'Correct return');
};

subtest '[az_nic_name_get]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'Eugenia'; });
    my $res = az_nic_name_get(
        nic_id => 'Fabrizio');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network nic show/ } @calls), 'Correct composition of the main command');
    ok((any { /--query.*name/ } @calls), 'Correct filter');
    ok(($res eq 'Eugenia'), 'Correct return');
};

subtest '[az_ipconfig_name_get]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'Eugenia'; });
    my $res = az_ipconfig_name_get(
        nic_id => 'Fabrizio');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network nic show/ } @calls), 'Correct composition of the main command');
    ok((any { /--query.*ipConfigurations.*name/ } @calls), 'Correct filter');
    ok(($res eq 'Eugenia'), 'Correct return');
};

done_testing;
