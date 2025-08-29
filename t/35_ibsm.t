use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use List::Util qw(any);
use sles4sap::ibsm;

subtest '[ibsm_calculate_address_range]' => sub {
    my %result_1 = ibsm_calculate_address_range(slot => 1);
    my %result_2 = ibsm_calculate_address_range(slot => 2);
    my %result_64 = ibsm_calculate_address_range(slot => 64);
    my %result_65 = ibsm_calculate_address_range(slot => 65);
    my %result_8192 = ibsm_calculate_address_range(slot => 8192);

    is($result_1{main_address_range}, "10.0.0.0/21", 'result_1 main_address_range is correct');
    is($result_1{subnet_address_range}, "10.0.0.0/24", 'result_1 subnet_address_range is correct');
    is($result_2{main_address_range}, "10.0.8.0/21", 'result_2 main_address_range is correct');
    is($result_2{subnet_address_range}, "10.0.8.0/24", 'result_2 subnet_address_range is correct');
    is($result_64{main_address_range}, "10.1.248.0/21", 'result_64 main_address_range is correct');
    is($result_64{subnet_address_range}, "10.1.248.0/24", 'result_64 subnet_address_range is correct');
    is($result_65{main_address_range}, "10.2.0.0/21", 'result_65 main_address_range is correct');
    is($result_65{subnet_address_range}, "10.2.0.0/24", 'result_65 subnet_address_range is correct');
    is($result_8192{main_address_range}, "10.255.248.0/21", 'result_8192 main_address_range is correct');
    is($result_8192{subnet_address_range}, "10.255.248.0/24", 'result_8192 subnet_address_range is correct');
    dies_ok { ibsm_calculate_address_range(slot => 0); } "Expected die for slot < 1";
    dies_ok { ibsm_calculate_address_range(slot => 8193); } "Expected die for slot > 8192";
};

subtest '[ibsm_network_peering_azure_create]' => sub {
    my $ibsm = Test::MockModule->new('sles4sap::ibsm', no_auto => 1);

    $ibsm->redefine(az_network_vnet_get => sub {
            my (%args) = @_;
            note(" --> az_network_vnet_get(resource_group => '$args{resource_group}', query => '$args{query}')");
            return ['VNET' . $args{resource_group}]; });
    my @peering_names;
    $ibsm->redefine(az_network_peering_create => sub {
            my (%args) = @_;
            push @peering_names, $args{name};
            note(" --> az_network_peering_create(name => '$args{name}, source_rg => '$args{source_rg}, source_vnet => '$args{source_vnet}', target_rg => '$args{target_rg},  target_vnet => '$args{target_vnet}')");
            return; });
    $ibsm->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    ibsm_network_peering_azure_create(ibsm_rg => 'COLIBRI', sut_rg => 'PASSEROTTO');

    note("\n  PN-->  " . join("\n  PN-->  ", @peering_names));
    ok((any { /VNETPASSEROTTO-VNETCOLIBRI/ } @peering_names), 'Peering named VNETPASSEROTTO-VNETCOLIBRI');
    ok((any { /VNETCOLIBRI-VNETPASSEROTTO/ } @peering_names), 'Peering named VNETCOLIBRI-VNETPASSEROTTO');
};

subtest '[ibsm_network_peering_azure_create] with name' => sub {
    my $ibsm = Test::MockModule->new('sles4sap::ibsm', no_auto => 1);

    $ibsm->redefine(az_network_vnet_get => sub {
            my (%args) = @_;
            note(" --> az_network_vnet_get(resource_group => '$args{resource_group}', query => '$args{query}')");
            return ['VNET' . $args{resource_group}]; });
    my @peering_names;
    $ibsm->redefine(az_network_peering_create => sub {
            my (%args) = @_;
            push @peering_names, $args{name};
            note(" --> az_network_peering_create(name => '$args{name}, source_rg => '$args{source_rg}, source_vnet => '$args{source_vnet}', target_rg => '$args{target_rg},  target_vnet => '$args{target_vnet}')");
            return; });
    $ibsm->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    ibsm_network_peering_azure_create(
        ibsm_rg => 'COLIBRI',
        sut_rg => 'PASSEROTTO',
        name_prefix => 'PETTIROSSO');

    note("\n  PN-->  " . join("\n  PN-->  ", @peering_names));
    ok((any { /PETTIROSSO-VNETPASSEROTTO-VNETCOLIBRI/ } @peering_names), 'Peering named VNETPASSEROTTO-VNETCOLIBRI');
    ok((any { /PETTIROSSO-VNETCOLIBRI-VNETPASSEROTTO/ } @peering_names), 'Peering named VNETCOLIBRI-VNETPASSEROTTO');
};

subtest '[ibsm_network_peering_azure_create] az integration' => sub {
    my $ibsm = Test::MockModule->new('sles4sap::ibsm', no_auto => 1);
    my $az_cli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);

    my @calls;
    $az_cli->redefine(script_run => sub {
            push @calls, 'SR: ' . $_[0];
            return; });

    $az_cli->redefine(assert_script_run => sub {
            push @calls, 'ASR: ' . $_[0];
            return; });

    $az_cli->redefine(script_output => sub {
            push @calls, 'SO: ' . $_[0];
            if ($_[0] =~ /az network vnet list -g (.*) --query.*/) { return '["VNET-' . $1 . '"]'; }
            if ($_[0] =~ /az network vnet show --query id.*--name (.*)/) { return $1 . '-ID'; }
            return 'NOT VALID'; });

    $ibsm->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    ibsm_network_peering_azure_create(ibsm_rg => 'COLIBRI', sut_rg => 'PASSEROTTO');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /.*ASR: az network vnet peering create.*/ } @calls), 'There is at least 1 "az network vnet peering create" (there should be exactly 2).');
    ok((any { /.*ASR: az network vnet peering create.*name VNET-PASSEROTTO-VNET-COLIBRI.*/ } @calls), 'Peering named VNET-PASSEROTTO-VNET-COLIBRI');
    ok((any { /.*ASR: az network vnet peering create.*resource-group PASSEROTTO.*/ } @calls), 'Peering resource group PASSEROTTO');
    ok((any { /.*ASR: az network vnet peering create.*vnet-name VNET-PASSEROTTO.*/ } @calls), 'Peering source vnet VNET-PASSEROTTO');
    ok((any { /.*ASR: az network vnet peering create.*remote-vnet VNET-COLIBRI-ID/ } @calls), 'Peering remote vnet id VNET-COLIBRI-ID');
    ok((any { /.*ASR: az network vnet peering create.*name VNET-COLIBRI-VNET-PASSEROTTO.*/ } @calls), 'Peering named VNET-COLIBRI-VNET-PASSEROTTO');
    ok((any { /.*ASR: az network vnet peering create.*resource-group COLIBRI.*/ } @calls), 'Peering resource group COLIBRI');
    ok((any { /.*ASR: az network vnet peering create.*vnet-name VNET-COLIBRI.*/ } @calls), 'Peering source vnet VNET-COLIBRI');
    ok((any { /.*ASR: az network vnet peering create.*remote-vnet VNET-PASSEROTTO-ID/ } @calls), 'Peering remote vnet id VNET-PASSEROTTO-ID');
};

subtest '[ibsm_network_peering_azure_delete]' => sub {
    my $ibsm = Test::MockModule->new('sles4sap::ibsm', no_auto => 1);

    $ibsm->redefine(az_network_vnet_get => sub {
            my (%args) = @_;
            note(" --> az_network_vnet_get(resource_group => '$args{resource_group}', query => '$args{query}')");
            return ['VNET' . $args{resource_group}]; });
    $ibsm->redefine(az_network_peering_list => sub {
            my (%args) = @_;
            note(" --> az_network_peering_list(resource_group => '$args{resource_group}', vnet => '$args{vnet}')");
            # The function is calling the az cli with "[?contains(name,'" . $args{sut_vnet} . "')].name" or '[].name'
            # that both return a json list, even if usually only of one element.
            return ['PEERING' . $args{resource_group}]; });
    my $peering_delete = 0;
    $ibsm->redefine(az_network_peering_delete => sub { $peering_delete = 1; return 0; });
    $ibsm->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    ibsm_network_peering_azure_delete(sut_rg => 'PICCIONE', ibsm_rg => 'COLOMBA');
    ok($peering_delete eq 1), 'az_network_peering_delete called';
};

subtest '[ibsm_network_peering_azure_delete] az integrate' => sub {
    my $ibsm = Test::MockModule->new('sles4sap::ibsm', no_auto => 1);
    $ibsm->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $az_cli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $az_cli->redefine(script_run => sub {
            push @calls, 'SR: ' . $_[0];
            return 0; });

    $az_cli->redefine(assert_script_run => sub {
            push @calls, 'ASR: ' . $_[0];
            return; });

    $az_cli->redefine(script_output => sub {
            push @calls, 'SO: ' . $_[0];
            if ($_[0] =~ /az network vnet list -g (.*) --query.*/) { return '["VNET-' . $1 . '"]'; }
            if ($_[0] =~ /az network vnet show --query id.*--name (.*)/) { return $1 . '-ID'; }
            if ($_[0] =~ /az network vnet peering list/) { return '["GABBIANO"]'; }
            if ($_[0] =~ /az network vnet peering delete/) { return 0; }
            return 'NOT VALID'; });

    ibsm_network_peering_azure_delete(sut_rg => 'PICCIONE', ibsm_rg => 'COLOMBA');
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /.*SR: az network vnet peering delete.*/ } @calls), 'There is at least 1 "az network vnet peering delete" (there should be exactly 2).');
    ok((any { /.*SR: az network vnet peering delete.*name GABBIANO / } @calls), 'There is at least 1 call with peering name GABBIANO.');
};

done_testing;
