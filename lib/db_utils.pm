# Copyright 2015-2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package db_utils;

use base 'Exporter';

use strict;
use warnings;
use testapi;

our @EXPORT = qw(
  influxdb_push_data
  influxdb_read_data
);

sub build_influx_kv {
    my $hash = shift;
    my $req = '';
    for my $k (keys(%{$hash})) {
        my $v = $hash->{$k};
        $v =~ s/,/\\,/g;
        $v =~ s/ /\\ /g;
        $v =~ s/=/\\=/g;
        $req .= $k . '=' . $v . ',';
    }
    return substr($req, 0, -1);
}

sub build_influx_query {
    my $data = shift;
    my $req = $data->{table} . ',';
    $req .= build_influx_kv($data->{tags});
    $req .= ' ';
    $req .= build_influx_kv($data->{values});
    return $req;
}

=head2 influxdb_push_data

    influxdb_push_data($url, $db, $data [, quiet => 1])

Builds an influx-db query and write it to the given database specified with
C<url> and C<db> for the Influx DB name.
C<data> is a hash containing the table name in Influx DB, the tags
and the values to plot.

Example of data:
    $data = {
        table  => 'my_db_table_name',
        tags   => { BUILD => '42', KERNEL => '4.12.14-lp151.28.20-default'},
        values => { io_reads' => 1337, io_writes => 1338 }
    }
=cut

sub influxdb_push_data {
    my ($url, $db, $data, %args) = @_;
    $args{quiet} //= 1;
    $data = build_influx_query($data);
    my $cmd = sprintf("curl -i -X POST '%s/write?db=%s' --write-out 'RETURN_CODE:%%{response_code}' --data-binary '%s'", $url, $db, $data);
    record_info('curl', $cmd);
    my $output = script_output($cmd, quiet => $args{quiet});
    my ($return_code) = $output =~ /RETURN_CODE:(\d+)/;
    die("Fail to push data into Influx DB:\n$output") unless ($return_code >= 200 && $return_code < 300);
}

=head2 influxdb_read_data

Builds an Influx DB query and read data from specified database
with C<url_base> and C<db> for the Influx DB name. C<query> contains
SELECT query for given DB.

returns json with results of SELECT query.

=cut

sub influxdb_read_data {
    my ($url_base, $db, $query) = @_;
    my $ua = Mojo::UserAgent->new();
    $ua->max_redirects(5);
    my $mojo_url = Mojo::URL->new($url_base . '/query');
    $mojo_url->query(db => $db, q => $query);
    my $res = $ua->get($mojo_url)->res;
    unless ($res && $res->json) {
        die sprintf("Failed to get data from InfluxDB. \n Response code : %s \n Message: %s \n", $res->code, $res->message);
    }
    return $res->json;
}
