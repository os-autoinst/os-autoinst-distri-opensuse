# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package maintenance_smelt;

use strict;
use warnings;
use testapi;
use List::Util qw(first);

use base "Exporter";
use Exporter;


our @EXPORT = qw(query_smelt get_incident_packages get_packagebins_in_modules repo_is_not_active);

sub query_smelt {
    my $graphql = $_[0];
    my $api_url = "--request POST https://smelt.suse.de/graphql/";
    my $header  = '--header "Content-Type: application/json"';
    my $data    = qq( --data '{"query": "$graphql"}');
    return qx(curl $api_url $header $data 2>/dev/null );
}

sub get_incident_packages {
    my $mr        = $_[0];
    my $gql_query = "{incidents(incidentId: $mr){edges{node{incidentpackagesSet{edges{node{package{name}}}}}}}}";
    my $graph     = JSON->new->utf8->decode(query_smelt($gql_query));
    my @nodes     = @{$graph->{data}{incidents}{edges}[0]{node}{incidentpackagesSet}{edges}};
    my @packages  = map { $_->{node}{package}{name} } @nodes;
    return @packages;
}

sub get_packagebins_in_modules {
    # This function uses the term package in the way that SMELT uses it. Not as
    # an rpm but as a set of binaries that receive varying levels of support and are
    # in different modules.
    my ($self) = @_;
    my ($package_name, $module_ref) = ($self->{package_name}, $self->{modules});
    my $response = qx(curl "https://smelt.suse.de/api/v1/basic/maintained/$package_name/" 2>/dev/null);
    my $graph    = JSON->new->utf8->decode($response);
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

sub repo_is_not_active {
    my $repo = $_[0];
    $repo =~ m".+Maintenance\:\/(\d+)";
    my $id     = $1;
    my $status = query_smelt("{incidents(incidentId: $id){edges{node{status {name}}}}}");
    record_info("$id", "$id have been released") && return $id if $status =~ /\Qstatus":{"name":"done"\E/;
}

1;
