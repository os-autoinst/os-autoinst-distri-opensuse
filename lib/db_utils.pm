# Copyright (C) 2015-2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

package db_utils;

use base 'Exporter';

use strict;
use warnings;
use testapi;

our @EXPORT = qw(
  influxdb_query
);

sub build_influx_kv {
    my $hash = shift;
    my $req  = '';
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
    my $req  = $data->{table} . ',';
    $req .= build_influx_kv($data->{tags});
    $req .= ' ';
    $req .= build_influx_kv($data->{values});
    return $req;
}

=head2 influxdb_query
    influxdb_query(data)

    builds an influx-db query and posts it to the given database by C<url>.
    C<data> should contain a hash containing the table name in Influx DB, the tags and the values to plot.
=cut
sub influxdb_query {
    my ($url, $data, %args) = @_;
    $args{quiet} //= 1;
    $data = build_influx_query($data);
    assert_script_run(sprintf("curl -i -X POST '%s' --data-binary '%s'", $url, $data), quiet => $args{quiet});
}
