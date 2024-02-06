use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use Data::Dumper;
use List::Util qw(any);
use testapi;
use saputils;


subtest '[calculate_hana_topology] invalid output' => sub {
    my $saputils = Test::MockModule->new('saputils', no_auto => 1);
    $saputils->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my $topology = calculate_hana_topology(input => 'PUFFI');
    ok keys %$topology == 0, 'No entry in topology if SAPHanaSR-showAttr has nothing';
};

subtest '[calculate_hana_topology] minimal 2 nodes' => sub {
    my $saputils = Test::MockModule->new('saputils', no_auto => 1);
    $saputils->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my $topology = calculate_hana_topology(input => 'Global/global/cib-time="Thu Feb  1 18:33:56 2024"
Global/global/maintenance="false"
Sites/site_b/b="SOK"
Hosts/vmhana01/vhost="AAAAAAA"
Hosts/vmhana02/vhost="BBBBBBB"');
    ok keys %$topology == 2, 'Output is about exactly 2 hosts';
    ok((any { qr/vmhana01/ } keys %$topology), 'External hash has key vmhana01');
    ok((any { qr/vmhana02/ } keys %$topology), 'External hash has key vmhana02');
};

subtest '[calculate_hana_topology] internal keys' => sub {
    my $saputils = Test::MockModule->new('saputils', no_auto => 1);
    $saputils->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $topology = calculate_hana_topology(input => 'Global/global/cib-time="Thu Feb  1 18:33:56 2024"
Global/global/maintenance="false"
Sites/site_b/b="SOK"
Hosts/vmhana01/remoteHost="vmhana02"
Hosts/vmhana01/sync_state="PRIM"
Hosts/vmhana01/vhost="vmhana01"
Hosts/vmhana02/remoteHost="vmhana01"
Hosts/vmhana02/sync_state="SOK"
Hosts/vmhana02/vhost="vmhana02"');

    note("Parsed input looks like " . Dumper($topology));
    ok((keys %$topology eq 2), "Parsed input has two hosts, so two outer keys.");

    while (my ($key, $value) = each %$topology) {
        ok((keys %$value eq 3), "Parsed input has 3 values for each host, so 3 inner keys.");

        # how to access one value of an inner hash
        like(%$value{remoteHost}, qr/vmhana0/, 'remoteHost is like vmhana0');
    }
    # how to access one inner value in one shot
    ok((%$topology{vmhana01}->{sync_state} eq 'PRIM'), 'sync_state of vmhana01 is exactly PRIM');
};

done_testing;
