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

my $image;
my $job_url;
my $db_log = "/tmp/influxdb.txt";
my $influxdb_server = get_var('INFLUXDB_SERVER');

sub check_db {
    # Check if the running job can push data to the Data Base
    # We only allow this on certain conditions:
    #  - The job must contain INFLUXDB_SERVER, _SECRET_INFLUXDB_USER and _SECRET_INFLUXDB_PWD
    #  - The job shouldn't be a verification run
    #  - The job must be executed from OSD or O3
    return 0 unless ($influxdb_server);
    my $influxdb_user = get_var('_SECRET_INFLUXDB_USER');
    my $influxdb_pwd = get_var('_SECRET_INFLUXDB_PWD');
    unless ($influxdb_user || $influxdb_pwd) {
        record_info('INFO', 'INFLUXDB_SERVER variable is set but "_SECRET_INFLUXDB_USER" and "_SECRET_INFLUXDB_PWD" are missing.');
        return 0;
    }

    # CASEDIR var is always set, and if when no specified, the value is "sle" for OSD and "opensuse" for O3
    return 0 if (get_required_var('CASEDIR') !~ m/^sle$|^opensuse$|^(sle|leap)-micro$/);

    my $openqa_host = get_required_var('OPENQA_HOSTNAME');
    if ($openqa_host =~ /openqa1-opensuse|openqa.opensuse.org/) {    # O3 hostname
        $job_url = 'https://openqa.opensuse.org/tests/' . get_current_job_id();
    }
    elsif ($openqa_host =~ /openqa.suse.de/) {    # OSD hostname
        $job_url = 'https://openqa.suse.de/tests/' . get_current_job_id();
    }
    return 0 unless ($job_url);
    # Store credentials in a file to be used by curl commands
    script_run("read -s influx_creds", 0);
    type_password("-u $influxdb_user:$influxdb_pwd\n");
    assert_script_run('echo $influx_creds > influxdb_conf');

    # Check if the data for this image has been already published before.
    # This will avoid publishing the same data if a job is restarted.
    my $query = 'curl -K influxdb_conf -i -G "http://' . $influxdb_server . ':8086/query?db=data"';
    $query .= ' --data-urlencode "q=SELECT \"value\" FROM \"image_size\" WHERE \"image\" = \'' . $image . '\'"';
    script_run("echo '$query' | tee -a $db_log");
    my $query_output = script_output("$query 2>&1 | tee -a $db_log", proceed_on_failure => 1);

    # Successful query should return 'HTTP/1.1 200 OK'
    # Empty records will return  '{"results":[{"statement_id":0}]}'
    # Existing records will return '{"results":[{"statement_id":0,"series":[{"name":"size","columns":["time","value"],"values"' ...
    if ($query_output !~ /200 OK/) {
        record_soft_failure("poo#110221 - There has been a problem with the query.");
        return 0;
    } elsif ($query_output =~ /values/) {
        record_info('DB skip', "Skip pushing the data to the DB. There is already a DB record for this image.");
        return 0;
    }
    record_info('DB ok', "Access is OK and the data will be pushed to the DB.\nquery = $query\nresult = \n$query_output");
    return 1;
}

sub push_to_influxdb {
    my ($self, %args) = @_;

    my $query = 'curl -K influxdb_conf -i -XPOST "http://' . $influxdb_server . ':8086/write?db=data"';
    $query .= ' --data-binary "' . $args{table};
    $query .= ',distri=' . get_required_var('DISTRI');
    $query .= ',version=' . get_required_var('VERSION');
    $query .= ',arch=' . get_required_var('ARCH');
    $query .= ',flavor=' . get_required_var('FLAVOR');
    $query .= ',build=' . get_required_var('BUILD');
    $query .= ',image=' . $image;
    $query .= ',job_url=' . $job_url;
    if (ref $args{extra} eq 'HASH') {
        foreach (keys %{$args{extra}}) {
            $query .= ',' . $_ . '=' . $args{extra}->{$_};
        }
    }
    $query .= ' value=' . $args{value} . '"';
    script_run("echo '$query' | tee -a $db_log");
    my $query_output = script_output("$query 2>&1 | tee -a $db_log", proceed_on_failure => 1);
    # if successful push, it should return 'HTTP/1.1 204 No Content'
    record_soft_failure("poo#110221 - There has been a problem pushing data to InfluxDB.") unless ($query_output =~ /(?=.*204 No Content)/);
}

sub run {
    my $self = shift;
    set_var('_QUIET_SCRIPT_CALLS', 1);    # Only show record_info frames.
    $self->select_serial_terminal;

    my $hdd;
    my $image_size;
    my $dir = getcwd;
    my $can_push_to_db = check_db;

    # Get the image size
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

    if ($hdd =~ /\.xz/) {
        # We want to monitor the size of uncompressed images.
        my $cmd = "nice ionice unxz -k $hdd -c > hdd_uncompressed";
        record_info('unxz', "Extracting compressed file to get its size.\n$cmd");
        system($cmd);
        $image_size = -s 'hdd_uncompressed';
        system("rm hdd_uncompressed");
        ($image = $hdd) =~ s/\.xz//;
    } else {
        $image = $hdd;
        $image_size = -s $hdd;
    }
    my $size_mb = $image_size / 1024 / 1024;
    record_info('Image', "Image: $image\nSize: $size_mb");
    $self->push_to_influxdb(table => 'image_size', value => $size_mb, extra => {type => 'uncompressed'}) if $can_push_to_db;

    # Get list of packages installed in the system
    my $packages = script_output('rpm -qa --queryformat "%{SIZE} %{NAME}\n" |sort -n -r');
    my @rpm_array = split(/\n/, $packages);
    my $num_packages = scalar @rpm_array;
    record_info('rpm total', "Total number of installed packages: $num_packages");
    record_info('rpm list', $packages);
    if ($can_push_to_db) {
        $self->push_to_influxdb(table => 'num_packages', value => $num_packages);
        # Push each rpm size
        my @lines = split /\n/, $packages;
        foreach my $line (@lines) {
            my ($size) = $line =~ /^\d+/g;
            my ($rpm) = $line =~ /\s(.*)/g;
            $self->push_to_influxdb(table => 'rpms', value => $size, extra => {rpm => $rpm});
        }
    }

    # Get size of directories except those that are irrelevant
    my $cmd = 'du -d 1 --block-size=1K';
    foreach my $dir (qw(/.snapshots /dev /mnt /opt /proc /srv /sys)) {
        $cmd .= " --exclude=$dir";
    }
    $cmd .= ' /';
    my $dirs = script_output($cmd);
    record_info("dirs", "$cmd\n$dirs");
    my @lines = split /\n/, $dirs;
    if ($can_push_to_db) {
        foreach my $line (@lines) {
            my ($size) = $line =~ /^\d+/g;
            my ($dir) = $line =~ /\s(.*)/g;
            $self->push_to_influxdb(table => 'directories', value => $size, extra => {dir => $dir});
        }
    }

    # Get the size of different file types
    # This step applies to BTRFS images. For simplicity, others images will be skipped.
    my $btrfs_summary = script_output('btrfs filesystem df --mbytes --si /', proceed_on_failure => 1);
    if ($btrfs_summary !~ /ERROR|command not found/) {
        record_info('btrfs', "$btrfs_summary");
        my ($data) = $btrfs_summary =~ /Data.*/g;
        my ($data_mb) = $data =~ /(\d+\.\d+)/g;
        my ($system) = $btrfs_summary =~ /System.*/g;
        my ($system_mb) = $system =~ /(\d+\.\d+)/g;
        my ($metadata) = $btrfs_summary =~ /Metadata.*/g;
        my ($metadata_mb) = $metadata =~ /(\d+\.\d+)/g;
        my ($globalreserve) = $btrfs_summary =~ /GlobalReserve.*/g;
        my ($globalreserve_mb) = $globalreserve =~ /(\d+\.\d+)/g;
        if ($can_push_to_db) {
            $self->push_to_influxdb(table => 'btrfs_df', value => $data_mb, extra => {type => 'Data'});
            $self->push_to_influxdb(table => 'btrfs_df', value => $system_mb, extra => {type => 'System'});
            $self->push_to_influxdb(table => 'btrfs_df', value => $metadata_mb, extra => {type => 'Metadata'});
            $self->push_to_influxdb(table => 'btrfs_df', value => $globalreserve_mb, extra => {type => 'GlobalReserve'});
        }
    }
}

sub post_run_hook {
    upload_logs($db_log, failok => 1);
    set_var('_QUIET_SCRIPT_CALLS', 0);
}

sub post_fail_hook {
    upload_logs($db_log, failok => 1);
    set_var('_QUIET_SCRIPT_CALLS', 0);
}

1;
