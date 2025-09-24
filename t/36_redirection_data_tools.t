use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use List::MoreUtils qw(all);
use List::Util qw(any);
use Data::Dumper;
use testapi;
use sles4sap::console_redirection::redirection_data_tools;

my $mock_data = {
    db_hana => {
        hanadb_a => {
            ip_address => '192.168.1.3',
            ssh_user => 'hanaadmin'
        },
        hanadb_b => {
            ip_address => '192.168.1.4',
            ssh_user => 'hanaadmin'
        }
    },
    nw_pas => {
        nw_pas => {
            ip_address => '192.168.1.6',
            ssh_user => 'hanaadmin'
        }
    },
    nw_aas => {
        nw_aas_01 => {
            ip_address => '192.168.1.7',
            ssh_user => 'hanaadmin'
        }
    },
    nw_ascs => {
        nw_ascs_01 => {
            ip_address => '192.168.1.9',
            ssh_user => 'hanaadmin'
        }
    },
    nw_ers => {
        nw_ers_02 => {
            ip_address => '192.168.1.10',
            ssh_user => 'hanaadmin'
        }
    }
};

subtest '[get_databases]' => sub {
    my $mockObject = sles4sap::console_redirection::redirection_data_tools->new($mock_data);
    my %dbs = %{$mockObject->get_databases()};
    note('Databases found: ' . join(' ', keys %dbs));
    ok((any { /hanadb_a/ } %dbs and any { /hanadb_b/ } %dbs), 'Get correct list of databases');
};

subtest '[get_ensa2_hosts]' => sub {
    my $mockObject = sles4sap::console_redirection::redirection_data_tools->new($mock_data);
    my %ensa2 = %{$mockObject->get_ensa2_hosts()};
    my @expected_hosts = qw(nw_ascs_01 nw_ers_02);
    note('ENSA2 hosts found: ' . join(' ', keys %ensa2));
    for my $host (@expected_hosts) {
        ok(grep(/$host/, keys(%ensa2)), "ENSA2 list contains host '$host'");
    }
};

subtest '[get_nw_hosts]' => sub {
    my $mockObject = sles4sap::console_redirection::redirection_data_tools->new($mock_data);
    my %nw_hosts = %{$mockObject->get_nw_hosts()};
    my @expected_hosts = qw(nw_ascs_01 nw_ers_02 nw_aas_01 nw_pas);
    note('NW hosts found: ' . join(' ', keys %nw_hosts));
    for my $host (@expected_hosts) {
        ok(grep(/$host/, keys(%nw_hosts)), "NW list contains host '$host'");
    }
};

subtest '[get_pas_host]' => sub {
    my $mockObject = sles4sap::console_redirection::redirection_data_tools->new($mock_data);
    my %pas_host = %{$mockObject->get_pas_host()};
    my $expected_host = 'nw_pas';
    note('PAS host found: ' . join(' ', keys %pas_host));
    ok(grep(/$expected_host/, keys(%pas_host)), "NW list contains host '$expected_host'");
};

subtest '[get_sap_hosts]' => sub {
    my $mockObject = sles4sap::console_redirection::redirection_data_tools->new($mock_data);
    my %nw_hosts = %{$mockObject->get_sap_hosts()};
    my @expected_hosts = qw(nw_ascs_01 nw_ers_02 nw_aas_01 nw_pas hanadb_a hanadb_b);
    note('NW hosts found: ' . join(' ', keys %nw_hosts));
    for my $host (@expected_hosts) {
        ok(grep(/$host/, keys(%nw_hosts)), "SAP list contains host '$host'");
    }
};

done_testing();
