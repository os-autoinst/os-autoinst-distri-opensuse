# Copyright 2015-2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package db_utils;

use base 'Exporter';

use strict;
use warnings;
use testapi;
use mmapi qw(get_current_job_id);

our @EXPORT = qw(
  influxdb_push_data
  influxdb_read_data
  push_image_data_to_db
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

    influxdb_push_data($url, $db, $org, $token, $data [, quiet => 1])

Builds an influx-db query and write it to the given database specified with
C<url>, C<org> and C<db> for the Influx DB organization and database name.
C<token> is used for user authentication.
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
    my ($url, $db, $org, $token, $data, %args) = @_;
    $args{quiet} //= 1;
    $data = build_influx_query($data);
    my $cmd = sprintf("curl -iLk -X POST '$url/api/v2/write?org=$org&bucket=$db' --header 'Authorization: Token $token' --write-out 'RETURN_CODE:%%{response_code}' --data-binary '%s'", $data);

    # Hide the token in the info box
    my $out = $cmd;
    $out =~ s/$token/<redacted>/;
    record_info('curl', $out);

    my $output = script_output($cmd, quiet => $args{quiet});
    my ($return_code) = $output =~ /RETURN_CODE:(\d+)/;
    die("Fail to push data into Influx DB:\n$output") unless ($return_code >= 200 && $return_code < 300);
}

=head2 influxdb_read_data

Builds an Influx DB query and read data from specified database
with C<url_base>, C<db> and C<org> for the Influx DB name.
C<token> contains the access token.
C<query> contains SELECT query for given DB.

returns json with results of SELECT query.

=cut

sub influxdb_read_data {
    my ($url_base, $db, $org, $token, $query) = @_;

    my $ua = Mojo::UserAgent->new();
    $ua->max_redirects(5);

    my $mojo_url = Mojo::URL->new("$url_base/query");
    $mojo_url->query(orgID => $org, db => $db, q => $query);
    my $res = $ua->post($mojo_url => {Authorization => "Token $token", Accept => "application/json", 'Content-type' => "application/json"})->res;
    if ($res->code != 200) {
        die sprintf("Failed to get data from InfluxDB. \n Response code : %s \n Message: %s \n", $res->code, $res->message);
    } else {
        my $json = $res->json;
        my @results = $json->{results};
        # Check if we got an error object as reply
        my $result = $results[0][0];
        if (defined($result->{error})) {
            die($result->{error});
        }
        return $json;
    }
}



=head2 push_image_data_to_db

Pushes data to specified with C<url> and C<db> for the Postgres DB name using curl.

=cut

sub push_image_data_to_db {
    my ($product, $image, $value, %args) = @_;
    my $db_log = "/tmp/db.log";
    my $db_ip = get_var('POSTGRES_IP');
    my $db_port = get_var('POSTGRES_PORT', '5444');
    my $token = get_var('_SECRET_DATABASE_PWD');
    unless ($db_ip) {
        record_soft_failure("poo#113120 - Missing variable POSTGRES_IP. Can't push data to DB.");
        return 0;
    }
    unless ($token) {
        record_soft_failure("poo#113120 - Missing variable _SECRET_DATABASE_PWD. Can't push data to DB.");
        return 0;
    }
    script_run("read -s pg_pwd", 0);
    type_password("-H \"Authorization: Bearer $token\"\n");
    assert_script_run('echo $pg_pwd > /etc/postgres_conf');
    assert_script_run('echo \'-H "Content-Type: application/json"\' >> /etc/postgres_conf');


    my $openqa_host = get_required_var('OPENQA_HOSTNAME');
    my $job_url;
    my $job_id = get_current_job_id();
    if ($openqa_host =~ /openqa1-opensuse|openqa.opensuse.org/) {    # O3 hostname
        $job_url = 'https://openqa.opensuse.org/tests/' . $job_id;
    }
    elsif ($openqa_host =~ /openqa.suse.de/) {    # OSD hostname
        $job_url = 'https://openqa.suse.de/tests/' . $job_id;
    } else {
        $job_url = $openqa_host . '/' . $job_id;
    }
    record_info('job_url', $job_url);
    return 0 unless ($job_url);

    $args{distri} //= get_required_var('DISTRI');
    $args{version} //= get_required_var('VERSION');
    $args{arch} //= get_required_var('ARCH');
    $args{flavor} //= get_required_var('FLAVOR');
    $args{build} //= get_required_var('BUILD');
    $args{type} //= '';
    (my $build = $args{build}) =~ s/\_.*//;    #To remove unneeded strings, e.g. 15.11_init-image -> 15.11

    my $cmd = 'curl -i -K /etc/postgres_conf -X POST http://' . $db_ip . ':' . $db_port . '/size -d \'{';
    $cmd .= '"product": "' . $product . '", ';
    $cmd .= '"distri": "' . $args{distri} . '", ';
    $cmd .= '"version": "' . $args{version} . '", ';
    $cmd .= '"arch": "' . $args{arch} . '", ';
    $cmd .= '"flavor": "' . $args{flavor} . '", ';
    $cmd .= '"build": "' . $build . '", ';
    $cmd .= '"asset": "' . $image . '", ';
    $cmd .= '"url": "' . $job_url . '", ';
    $cmd .= '"type": "' . $args{type} . '", ';
    $cmd .= '"value": "' . $value . '"}\'';
    record_info('db cmd', $cmd);
    script_run("echo '$cmd' | tee -a $db_log");
    my $cmd_output = script_output("$cmd 2>&1 | tee -a $db_log", proceed_on_failure => 1);
    # if successful push, it should return 'HTTP/1.1 201 Created'
    if ($cmd_output =~ /(?=.*201 Created)/) {
        record_info("DB", "Image data has been successfully pushed to the Database.");
    } elsif ($cmd_output =~ /(?=.*409 Conflict)/) {
        record_info("DB", "This image info already exists DB.");
    } else {
        record_soft_failure("poo#113120 - There has been a problem pushing data to the DB.");
    }
}
