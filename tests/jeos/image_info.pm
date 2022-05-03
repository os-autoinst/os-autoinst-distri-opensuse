# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This module is to collect information about JeOS/Minimal-VM
#          information, like image size, directory sizes, package list,
#          etc. and push it to an InfluxDB to be displayed in Grafana.
#          This module doesn't do any interaction with the booted system.
#          All the operations are done on worker level.
#          This module is not intended to be a limiting factor to fail a
#          job, specially pushing data to the DB, therefore no `die`
#          operations are used.
# Maintainer: QA-C <qa-c@suse.de>

use Mojo::Base qw(opensusebasetest);
use testapi;
use version_utils qw(is_sle is_opensuse is_openstack);
use mmapi qw(get_current_job_id);
use Cwd;

sub ls {
    my $output = `ls -l`;
    record_info('ls', $output);
}

sub run {
    my $self = shift;
    my $download_url;
    my $hdd;
    my $image;
    my $size;

    my $dir = getcwd;
    record_info('pwd', $dir);    # For debug purposes

    ls;    # debug
    if (is_openstack) {
        # In OpenStack JeOS tests, we boot a different HDD which serves as
        # a jumphost with the needed CLI tools to upload the image and create
        # the VM in the remote openStack environment.
        # The JeOS HDD is not copied in the openQA pool directory, we need to
        # download using PUBLIC_CLOUD_IMAGE_LOCATION variable
        my $img_url = get_required_var('PUBLIC_CLOUD_IMAGE_LOCATION');
        record_info('URL', "Downloading $img_url ...");
        system("curl -O $img_url");
        ($hdd) = $img_url =~ /([^\/]+)$/;
    } else {
        $hdd = get_required_var('HDD_1');
    }

    record_info('HDD', $hdd);
    ls;

    if ($hdd =~ /\.xz/) {
        # We want to monitor the size of uncompressed images.
        my $cmd = "nice ionice unxz -k $hdd -c > hdd_uncompressed";
        record_info('unxz', "Extracting compressed file to get its size.\n$cmd");
        system($cmd);
        $size = -s 'hdd_uncompressed';
        ls;    # debug
        system("rm hdd_uncompressed");
        ($image = $hdd) =~ s/\.xz//;
    } else {
        $image = $hdd;
        $size = -s $hdd;
    }
    my $size_mb = $size / 1024 / 1024;
    record_info('Image', "Image: $image\nSize: $size_mb");

    # Record this value in the InfluxDB
    # We only allow this on certain conditions:
    #  - The job must be executed from OSD or O3
    #  - The job must contain INFLUXDB_SERVER and _SECRET_INFLUXDB_USER and _SECRET_INFLUXDB_PWD
    #  - The job shouldn't be a verification run => CASEDIR variable
    my $influxdb_server = get_var('INFLUXDB_SERVER');
    my $influxdb_user = get_var('_SECRET_INFLUXDB_USER');
    my $influxdb_pwd = get_var('_SECRET_INFLUXDB_PWD');

    return if (get_var('CASEDIR') !~ m/^sle$|^opensuse$/);
    return unless ($influxdb_server || $influxdb_user || $influxdb_pwd);

    my $job_url;
    my $openqa_host = get_required_var('OPENQA_HOSTNAME');
    if ($openqa_host =~ /openqa1-opensuse|openqa.opensuse.org/) {    # O3 hostname
        $job_url = 'https://openqa.opensuse.org/tests/' . get_current_job_id();
    }
    elsif ($openqa_host =~ /openqa.suse.de/) {    # OSD hostname
        $job_url = 'https://openqa.suse.de/tests/' . get_current_job_id();
    }

    return unless ($job_url);

    # Check if the data for this image has been already published before.
    # This will avoid publishing the same data if a job is restarted.
    system("echo '-u $influxdb_user:$influxdb_pwd' > $dir/influxdb_conf");

    my $query = 'curl -K ' . $dir . '/influxdb_conf -i -G "http://' . $influxdb_server . ':8086/query?db=data"';
    $query .= ' --data-urlencode "q=SELECT \"value\" FROM \"image_size\" WHERE \"image\" = \'' . $image . '\'"';
    my $query_output = `$query 2>&1`;
    record_info('DB check', "Check if this value exists in the DB.\nquery = $query\nresult = \n$query_output");
    # Successful query should return 'HTTP/1.1 200 OK'
    # Empty records will return  '{"results":[{"statement_id":0}]}'
    # Existing records will return '{"results":[{"statement_id":0,"series":[{"name":"size","columns":["time","value"],"values"' ...
    if ($query_output !~ /200 OK/) {
        record_soft_failure("poo#110221 - There has been a problem with the query.");
    } elsif ($query_output =~ /values/) {
        record_info('Skip', "Skip pushing the data to the DB. There is already a DB record for this image.");
    } else {
        $query = 'curl -K influxdb_conf -i -XPOST "http://' . $influxdb_server . ':8086/write?db=data"';
        $query .= ' --data-binary "image_size';
        $query .= ',distri=' . get_required_var('DISTRI');
        $query .= ',version=' . get_required_var('VERSION');
        $query .= ',arch=' . get_required_var('ARCH');
        $query .= ',flavor=' . get_required_var('FLAVOR');
        $query .= ',build=' . get_required_var('BUILD');
        $query .= ',image=' . $image;
        $query .= ',job_url=' . $job_url;
        $query .= ',type=uncompressed';
        $query .= ' value=' . $size_mb . '"';
        my $query_output = `$query 2>&1`;
        record_info('DB push', "query = $query\nresult = \n$query_output");
        # if successful push, it should return 'HTTP/1.1 204 No Content'
        record_soft_failure("poo#110221 - There has been a problem pushing data to InfluxDB.") unless ($query_output =~ /(?=.*204 No Content)/);
    }
}

1;
