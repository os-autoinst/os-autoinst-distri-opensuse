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
            my $ret = 'VNET' . $args{resource_group};
            note(" --> az_network_vnet_get(resource_group => '$args{resource_group}', query => '$args{query}') --> return [ $ret ]");
            return [$ret]; });
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
            my $ret = 'VNET' . $args{resource_group};
            note(" --> az_network_vnet_get(resource_group => '$args{resource_group}', query => '$args{query}') --> return [ $ret ]");
            return [$ret]; });
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
            my $ret = 'VNET' . $args{resource_group};
            note(" --> az_network_vnet_get(resource_group => '$args{resource_group}', query => '$args{query}') --> return [ $ret ]");
            return [$ret]; });
    $ibsm->redefine(az_network_peering_list => sub {
            my (%args) = @_;
            my @az_args;
            push @az_args, "resource_group => '$args{resource_group}'";
            push @az_args, "vnet => '$args{vnet}'";
            push @az_args, "query => '$args{query}'" if $args{query};
            note(' --> az_network_peering_list(' . join(', ', @az_args) . ')');
            # The function is calling the az cli with "[?contains(name,'" . $args{sut_vnet} . "')].name" or '[].name'
            # that both return a json list, even if usually only of one element.
            return ['PEERING' . $args{resource_group}]; });
    my $peering_delete = 0;
    $ibsm->redefine(az_network_peering_delete => sub {
            my (%args) = @_;
            note(" --> az_network_peering_delete(name => '$args{name}', resource_group => '$args{resource_group}', vnet => '$args{vnet}')");
            $peering_delete = 1; return 0; });
    $ibsm->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    ibsm_network_peering_azure_delete(sut_rg => 'PICCIONE', ibsm_rg => 'COLOMBA');
    ok($peering_delete eq 1), 'az_network_peering_delete called';
};

subtest '[ibsm_network_peering_azure_delete] including az_cli code layer' => sub {
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

subtest '[ibsm_network_peering_azure_delete] error handling' => sub {
    my $ibsm = Test::MockModule->new('sles4sap::ibsm', no_auto => 1);
    $ibsm->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $ibsm->redefine(az_network_vnet_get => sub {
            my (%args) = @_;
            my $ret = 'VNET' . $args{resource_group};
            note(" --> az_network_vnet_get(resource_group => '$args{resource_group}', query => '$args{query}') --> return [ $ret ]");
            return [$ret]; });

    # Empty list on SUT side (should return early)
    $ibsm->redefine(az_network_peering_list => sub {
            my (%args) = @_;
            my @az_args;
            push @az_args, "resource_group => '$args{resource_group}'";
            push @az_args, "vnet => '$args{vnet}'";
            push @az_args, "query => '$args{query}'" if $args{query};
            note(' --> az_network_peering_list(' . join(', ', @az_args) . ')');
            note(" --> az_network_peering_list(resource_group => '$args{resource_group}', vnet => '$args{vnet}') --> return []");
            return []; });
    lives_ok { ibsm_network_peering_azure_delete(sut_rg => 'SUT', ibsm_rg => 'IBSM') } 'Graceful exit if SUT peering not found';

    # Multiple elements (should die)
    $ibsm->redefine(az_network_peering_list => sub {
            my (%args) = @_;
            note(" --> az_network_peering_list(resource_group => '$args{resource_group}', vnet => '$args{vnet}') --> return ['PEERING1', 'PEERING2']");
            my @az_args;
            push @az_args, "resource_group => '$args{resource_group}'";
            push @az_args, "vnet => '$args{vnet}'";
            push @az_args, "query => '$args{query}'" if $args{query};
            note(' --> az_network_peering_list(' . join(', ', @az_args) . ')');
            return ['PEERING1', 'PEERING2']; });
    dies_ok { ibsm_network_peering_azure_delete(sut_rg => 'SUT', ibsm_rg => 'IBSM') } 'Die if multiple peerings found';
};

subtest '[ibsm_network_peering_azure_create/_delete] symmetry' => sub {
    my $ibsm = Test::MockModule->new('sles4sap::ibsm', no_auto => 1);

    $ibsm->redefine(az_network_vnet_get => sub {
            my (%args) = @_;
            my $ret = 'VNET' . $args{resource_group};
            note(" --> az_network_vnet_get(resource_group => '$args{resource_group}', query => '$args{query}') --> return [ $ret ]");
            return [$ret]; });

    my @peering_names;
    $ibsm->redefine(az_network_peering_create => sub {
            my (%args) = @_;
            push @peering_names, $args{name};
            note(" --> az_network_peering_create(name => '$args{name}, source_rg => '$args{source_rg}, source_vnet => '$args{source_vnet}', target_rg => '$args{target_rg},  target_vnet => '$args{target_vnet}')");
            return;
    });

    $ibsm->redefine(az_network_peering_list => sub {
            my (%args) = @_;
            my @az_args;
            push @az_args, "resource_group => '$args{resource_group}'";
            push @az_args, "vnet => '$args{vnet}'";
            push @az_args, "query => '$args{query}'" if $args{query};
            # Extract target name from JMESPath query: "[?contains(name, 'EXPECTED_NAME')].name" or "[?name=='EXPECTED_NAME'].name"
            if ($args{query} =~ /(?:contains\(name, '|name=='|name\s+==\s+')([^']+)'/) {
                my $target = $1;
                my @matches = grep { $_ eq $target } @peering_names;
                note(' --> az_network_peering_list(' . join(', ', @az_args) . ') --> Found ' . scalar(@matches) . " matches for '$target'");
                return [@matches];
            }
            note(' --> az_network_peering_list(' . join(', ', @az_args) . ') --> []');
            return [];
    });

    $ibsm->redefine(az_network_peering_delete => sub {
            my (%args) = @_;
            note(" --> az_network_peering_delete(name => '$args{name}', resource_group => '$args{resource_group}', vnet => '$args{vnet}')");
            my $initial_count = scalar @peering_names;
            @peering_names = grep { $_ ne $args{name} } @peering_names;
            die "Peering '$args{name}' not found in internal list" if scalar @peering_names == $initial_count;
            note("Mock az_network_peering_delete: Remaining peerings: [" . join(', ', @peering_names) . "]");
            return 0;
    });

    $ibsm->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    note("--- Create Peerings ---");
    ibsm_network_peering_azure_create(ibsm_rg => 'COLIBRI', sut_rg => 'PASSEROTTO');
    is(scalar @peering_names, 2, 'Two peerings were created');

    note("--- Delete Peerings ---");
    ibsm_network_peering_azure_delete(ibsm_rg => 'COLIBRI', sut_rg => 'PASSEROTTO');
    is(scalar @peering_names, 0, 'All peerings were successfully deleted');
};

subtest '[ibsm_network_peering_azure_create/_delete] symmetry with prefix' => sub {
    my $ibsm = Test::MockModule->new('sles4sap::ibsm', no_auto => 1);
    $ibsm->redefine(az_network_vnet_get => sub {
            my (%args) = @_;
            my $ret = 'VNET' . $args{resource_group};
            note(" --> az_network_vnet_get(resource_group => '$args{resource_group}', query => '$args{query}') --> return [ $ret ]");
            return [$ret]; });
    $ibsm->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my @peering_names;
    $ibsm->redefine(az_network_peering_create => sub {
            my (%args) = @_;
            push @peering_names, $args{name};
            note(" --> az_network_peering_create(name => '$args{name}, source_rg => '$args{source_rg}, source_vnet => '$args{source_vnet}', target_rg => '$args{target_rg},  target_vnet => '$args{target_vnet}')");
    });

    $ibsm->redefine(az_network_peering_list => sub {
            my (%args) = @_;
            my @az_args;
            push @az_args, "resource_group => '$args{resource_group}'";
            push @az_args, "vnet => '$args{vnet}'";
            push @az_args, "query => '$args{query}'" if $args{query};
            # Extract target name from JMESPath query
            if ($args{query} =~ /(?:contains\(name, '|name=='|name\s+==\s+')([^']+)'/) {
                my $target = $1;
                my @matches = grep { $_ eq $target } @peering_names;
                note(' --> az_network_peering_list(' . join(', ', @az_args) . ') --> Found ' . scalar(@matches) . " matches for '$target'");
                return [@matches];
            }
            note(' --> az_network_peering_list(' . join(', ', @az_args) . ') --> []');
            return [];
    });

    $ibsm->redefine(az_network_peering_delete => sub {
            my (%args) = @_;
            note(" --> az_network_peering_delete(name => '$args{name}', resource_group => '$args{resource_group}', vnet => '$args{vnet}')");
            @peering_names = grep { $_ ne $args{name} } @peering_names;
            return 0;
    });

    note("--- Testing symmetry with prefix 'SDAF' ---");
    ibsm_network_peering_azure_create(ibsm_rg => 'COLIBRI', sut_rg => 'PASSEROTTO', name_prefix => 'RONDINE');
    ok((grep { /^RONDINE-VNETPASSEROTTO-VNETCOLIBRI$/ } @peering_names), 'Expected peering name with prefix found');

    ibsm_network_peering_azure_delete(ibsm_rg => 'COLIBRI', sut_rg => 'PASSEROTTO', name_prefix => 'RONDINE');
    is(scalar @peering_names, 0, 'Symmetry verified with prefix');
};

subtest '[ibsm_network_peering_azure_create] dies if one VNET failure' => sub {
    my $ibsm = Test::MockModule->new('sles4sap::ibsm', no_auto => 1);
    $ibsm->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    # Test _create dies if one VNET is missing
    $ibsm->redefine(az_network_vnet_get => sub {
            my (%args) = @_;
            if ($args{resource_group} eq 'COLIBRI') {
                note(" --> az_network_vnet_get(resource_group => '$args{resource_group}') --> return []");
                return [];
            }
            note(" --> az_network_vnet_get(resource_group => '$args{resource_group}') --> return [VNET$args{resource_group}]");
            return ['VNET' . $args{resource_group}];
    });

    my @deleted;
    $ibsm->redefine(az_network_peering_delete => sub {
            my (%args) = @_;
            push @deleted, $args{name};
            return 0;
    });

    $ibsm->redefine(az_network_peering_list => sub {
            my (%args) = @_;
            my @az_args;
            push @az_args, "resource_group => '$args{resource_group}'";
            push @az_args, 'vnet => ' . ("'$args{vnet}'" // 'undef');
            push @az_args, "query => '$args{query}'" if $args{query};

            if ($args{vnet} && $args{query} =~ /(?:contains\(name, '|name=='|name\s+==\s+')([^']+)'/) {
                if ($1 eq 'VNETPASSEROTTO-') {
                    # If IBSM VNET (COLIBRI) is missing, expected_name for SUT->IBSM will be 'VNETPASSEROTTO-'
                    note(' --> az_network_peering_list(' . join(', ', @az_args) . ') --> [VNETPASSEROTTO-VNETCOLIBRI]');
                    return ['VNETPASSEROTTO-VNETCOLIBRI'];
                }
            }
            note(' --> az_network_peering_list(' . join(', ', @az_args) . ') --> []');
            return [];
    });

    dies_ok { ibsm_network_peering_azure_create(ibsm_rg => 'COLIBRI', sut_rg => 'PASSEROTTO') }
    'ibsm_network_peering_azure_create dies if one VNET is missing';
};

subtest '[ibsm_network_peering_azure_delete] dies if one VNET failure' => sub {
    my $ibsm = Test::MockModule->new('sles4sap::ibsm', no_auto => 1);
    $ibsm->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    # Test _create dies if one VNET is missing
    $ibsm->redefine(az_network_vnet_get => sub {
            my (%args) = @_;
            if ($args{resource_group} eq 'COLIBRI') {
                note(" --> az_network_vnet_get(resource_group => '$args{resource_group}') --> return []");
                return [];
            }
            note(" --> az_network_vnet_get(resource_group => '$args{resource_group}') --> return [VNET$args{resource_group}]");
            return ['VNET' . $args{resource_group}];
    });

    my @deleted;
    $ibsm->redefine(az_network_peering_delete => sub {
            my (%args) = @_;
            push @deleted, $args{name};
            return 0;
    });

    $ibsm->redefine(az_network_peering_list => sub {
            my (%args) = @_;
            my @az_args;
            push @az_args, "resource_group => '$args{resource_group}'";
            push @az_args, 'vnet => ' . ("'$args{vnet}'" // 'undef');
            push @az_args, "query => '$args{query}'" if $args{query};

            if ($args{vnet} && $args{query} =~ /(?:contains\(name, '|name=='|name\s+==\s+')([^']+)'/) {
                if ($1 eq 'VNETPASSEROTTO-') {
                    # If IBSM VNET (COLIBRI) is missing, expected_name for SUT->IBSM will be 'VNETPASSEROTTO-'
                    note(' --> az_network_peering_list(' . join(', ', @az_args) . ') --> [VNETPASSEROTTO-VNETCOLIBRI]');
                    return ['VNETPASSEROTTO-VNETCOLIBRI'];
                }
            }
            note(' --> az_network_peering_list(' . join(', ', @az_args) . ') --> []');
            return [];
    });


    # Test _delete with one VNET missing
    dies_ok { ibsm_network_peering_azure_delete(ibsm_rg => 'COLIBRI', sut_rg => 'PASSEROTTO') }
    'ibsm_network_peering_azure_delete dies if one VNET is missing';
};


subtest '[ibsm_network_peering_azure_delete] peering list failure' => sub {
    my $ibsm = Test::MockModule->new('sles4sap::ibsm', no_auto => 1);
    $ibsm->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    # Test _create dies if one VNET is missing
    $ibsm->redefine(az_network_vnet_get => sub {
            my (%args) = @_;
            note(" --> az_network_vnet_get(resource_group => '$args{resource_group}') --> return [VNET$args{resource_group}]");
            return ['VNET' . $args{resource_group}];
    });

    my @deleted;
    $ibsm->redefine(az_network_peering_delete => sub {
            my (%args) = @_;
            push @deleted, $args{name};
            return 0;
    });

    $ibsm->redefine(az_network_peering_list => sub {
            my (%args) = @_;
            my @az_args;
            push @az_args, "resource_group => '$args{resource_group}'";
            push @az_args, 'vnet => ' . ("'$args{vnet}'" // 'undef');
            push @az_args, "query => '$args{query}'" if $args{query};

            if ($args{vnet} && $args{query} =~ /(?:contains\(name, '|name=='|name\s+==\s+')([^']+)'/) {
                if ($1 eq 'VNETCOLIBRI-VNETPASSEROTTO') {
                    note(' --> az_network_peering_list(' . join(', ', @az_args) . ') --> [VNETCOLIBRI-VNETPASSEROTTO]');
                    return ['VNETCOLIBRI-VNETPASSEROTTO'];
                }
            }
            note(' --> az_network_peering_list(' . join(', ', @az_args) . ') --> []');
            return [];
    });


    # Test _delete with one VNET missing
    @deleted = ();
    lives_ok { ibsm_network_peering_azure_delete(sut_rg => 'PASSEROTTO', ibsm_rg => 'COLIBRI') }
    'ibsm_network_peering_azure_delete lives even if one VNET is missing';

    is(scalar @deleted, 1, 'Only one peering deleted when IBSM VNET is missing');
    is($deleted[0], 'VNETCOLIBRI-VNETPASSEROTTO', 'Deleted the listed peering VNETCOLIBRI-VNETPASSEROTTO');
};

done_testing;
