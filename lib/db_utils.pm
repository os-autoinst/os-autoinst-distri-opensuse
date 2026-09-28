# Copyright 2015-2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package db_utils;

use base 'Exporter';

use strict;
use warnings;
use testapi;
use mmapi qw(get_current_job_id);
use JSON qw(encode_json);
use utils qw(script_retry);

our @EXPORT = qw(
  push_image_data_to_db
  check_postgres_db
  is_ok_url
);

=head2 push_image_data_to_db

Pushes data to specified with C<url> and C<db> for the Postgres DB name using curl.

=cut

sub push_image_data_to_db {
    my ($product, $image, $value, %args) = @_;
    my $db_log = "/tmp/db.log";
    my $db_ip = get_required_var('POSTGRES_IP');
    my $db_port = get_var('POSTGRES_PORT', '5444');
    my $token = get_required_var('_SECRET_DATABASE_PWD');

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
    bmwqemu::diag('job_url', $job_url);
    return 0 unless ($job_url);

    $args{distri} //= get_required_var('DISTRI');
    $args{version} //= get_required_var('VERSION');
    $args{arch} //= get_required_var('ARCH');
    $args{flavor} //= get_required_var('FLAVOR');
    $args{build} //= get_required_var('BUILD');
    $args{table} //= 'size';
    $args{url} = $job_url;
    $args{asset} = $image;
    $args{value} = $value;
    $args{product} = $product;
    $args{build} =~ s/\_.*//;    #To remove unneeded strings, e.g. 15.11_init-image -> 15.11

    my $ua = Mojo::UserAgent->new;
    $ua = $ua->max_connections(5);
    $ua = $ua->max_redirects(3);
    $ua = $ua->connect_timeout(30);

    my $url = sprintf('http://%s:%s/%s', $db_ip, $db_port, $args{table});
    bmwqemu::diag("Database URL: $url");
    my $table = delete $args{table};

    #my $data = encode_json(\%args);
    bmwqemu::diag("Collected image data: " . encode_json(\%args));
    record_info("Image DB", "Destination DB: $url\nData: " . encode_json(\%args));

    my $retries = 3;
    my $res;
    for (my $i = 0; $i < $retries; $i++) {
        $res = $ua->post("$url" => {Authorization => "Bearer $token", Accept => "application/json",
                'Content-type' => "application/json"} => json => \%args)->result();

        # if successful push, it should return 'HTTP/1.1 201 Created'
        if ($res->code == 201) {
            bmwqemu::diag("Image data has been successfully pushed to the Database ($table), RC => " . $res->code);
            return $res->code;
        } elsif ($res->code == 409) {
            bmwqemu::diag("This image info already exists in $table, RC => " . $res->code);
            # return to the caller that conflict has been found
            # caller should exit the test case module immediately
            return $res->code;
        } else {
            record_info('DB error', "There has been a problem pushing data to the $table. RC => " . $res->code, result => 'fail');
            sleep(30);    # Give database some time to recover in case of issues
        }
    }
    return $res->code;
}

sub check_postgres_db {
    my $image = shift;
    my $db_ip = get_var('POSTGRES_IP');
    my $db_port = get_var('POSTGRES_PORT', '5444');
    my $db_db = get_var('POSTGRES_DB', 'size');
    my $db_log = "/tmp/db.log";

    ## We only allow data push to the database if all of the following conditions are met:
    ## 1. The job must hold the POSTGRES_IP setting (database host)
    ## 2. The job shouldn't be a verification run
    ## 3. The job must be executed from OSD or O3

    ## Check if database host ist set
    return 0 unless ($db_ip);

    ## Check if job is a verification run
    # CASEDIR var is always set (check vars.json). If not explicitly specified, the value is "sle/sle-micro" for OSD and "opensuse/leap-micro" for O3
    return 0 if (get_required_var('CASEDIR') !~ m/^sle$|^opensuse$|^(sle|leap)-micro$/);

    ## Check if job is executed on OSD/O3
    my $job_url;
    my $openqa_host = get_required_var('OPENQA_HOSTNAME');
    if ($openqa_host =~ /openqa1-opensuse|openqa.opensuse.org/) {    # O3 hostname
        $job_url = 'https://openqa.opensuse.org/tests/' . get_current_job_id();
    } elsif ($openqa_host =~ /openqa.suse.de/) {    # OSD hostname
        $job_url = 'https://openqa.suse.de/tests/' . get_current_job_id();
    } else {
        return 0;
    }

    ## Probe the database
    # A successful query should return 'HTTP/1.1 200 OK'
    # Empty records will return  '{"results":[{"statement_id":0}]}'
    # Existing records will return '{"results":[{"statement_id":0,"series":[{"name":"size","columns":["time","value"],"values"' ...
    my $request = "curl -IfLv 'http://$db_ip:$db_port/$db_db'";
    if (script_run("timeout 100 $request 2>&1 >/var/tmp/db_curl.tmp", timeout => 120) != 0) {
        my $output = script_output("cat /var/tmp/db_curl.tmp");
        record_info("db error", "cannot reach POSTGREST database\n$request\n$output", result => 'fail');
        return 0;
    }
    return 1;
}

sub is_ok_url {
    # url connectivity check
    # Parameters: url[:port] [, <script_retry parameters>]
    my ($url, %args) = @_;
    $args{die} //= 0;
    $args{retry} //= 5;
    $args{delay} //= 10;
    $args{timeout} //= 50;
    # Any other input default of called routine: max wait default = 300s
    my $cmd = "curl -ILskf --connect-timeout " . $args{timeout} . " " . $url . " >/dev/null";
    # Increase routine's timeout to let cmd timeout be triggered first.
    $args{timeout} += 2;
    return (script_retry($cmd, %args) == 0);
}
