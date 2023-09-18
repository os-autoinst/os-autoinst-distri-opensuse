# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-Core <qe-core@suse.de>
package maintenance_smelt;

use strict;
use warnings;
use testapi;
use List::Util qw(first);
use Mojo::UserAgent;

use base "Exporter";
use Exporter;


our @EXPORT = qw(query_smelt get_incident_packages get_packagebins_in_modules);

sub query_smelt {
    my $graphql = $_[0];
    my $transaction = Mojo::UserAgent->new->post("https://smelt.suse.de/graphql/" => json => {query => "$graphql"});
    my $resp_code = $transaction->res->code;
    if ($resp_code != 200) {
        record_info "Response: $resp_code", "Unexpected response code from SMELT";
        die "Unexpected response code from SMELT: $resp_code";
    }
    return $transaction->res->body;
}

sub get_incident_packages {
    my $mr = $_[0];
    my $gql_query = "{incidents(incidentId: $mr){edges{node{incidentpackagesSet{edges{node{package{name}}}}}}}}";
    my $graph = JSON->new->utf8->decode(query_smelt($gql_query));
    my $exception_message = "Unexpected response code from SMELT\n";
    die $exception_message . "Error in getting incident data (incidentId:$mr) from SMELT" unless $graph;
    my $nodes = $graph->{data}{incidents}{edges}[0]{node}{incidentpackagesSet}{edges};
    die $exception_message . "Invalid/empty incident data (incidentId:$mr) from SMELT" unless $nodes;
    my @packages = map { $_->{node}{package}{name} } @{$nodes};
    die $exception_message . "Test could not parse any packages in SMELT response" if not @packages;
    return @packages;
}

sub get_packagebins_in_modules {
    # This function uses the term package in the way that SMELT uses it. Not as
    # an rpm but as a set of binaries that receive varying levels of support and are
    # in different modules.
    my ($self) = @_;
    my ($package_name, $module_ref) = ($self->{package_name}, $self->{modules});
    my $response = Mojo::UserAgent->new->get("https://smelt.suse.de/api/v1/basic/maintained/$package_name/")->result->body;
    my $graph = JSON->new->utf8->decode($response);
    # Get the modules to which this package provides binaries.
    my @existing_modules = grep { exists($graph->{$_}) } @{$module_ref};
    my @arr;
    foreach my $m (@existing_modules) {
        # The refs point to a hash of hashes. We only care about the value with
        # the codestream key. The Update key is different for every SLE
        # Codestream so instead of maintaining a LUT we just use a regex for it.
        my $upd_key = first { m/Update\b/ } keys %{$graph->{$m}};
        push(@arr, @{$graph->{$m}{$upd_key}});
    }
    # Return a hash of hashes, hashed by name. The values are hashes with the keys 'name', 'supportstatus' and
    # 'package'.
    return map { $_->{name} => $_ } @arr;
}

1;
