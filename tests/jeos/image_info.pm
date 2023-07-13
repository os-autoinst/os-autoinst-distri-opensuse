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
use serial_terminal 'select_serial_terminal';
use version_utils qw(is_sle is_opensuse is_openstack);
use mmapi qw(get_current_job_id);
use Cwd;
use db_utils qw(push_image_data_to_db check_postgres_db);


sub run {
    my $self = shift;
    set_var('_QUIET_SCRIPT_CALLS', 1);    # Only show record_info frames.
    select_serial_terminal;

    my $hdd;
    my $image_size;
    my $dir = getcwd;
    my $image;

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

    # DB availability check
    unless (check_postgres_db) {
        record_soft_failure("poo#110221 - DB is not available!");
        return 1;
    }

    my $size_mb = $image_size / 1024 / 1024;
    record_info('Image', "Image: $image\nSize: $size_mb");
    my $is_conflict = push_image_data_to_db('minimal-vm', $image, $size_mb, table => 'size', type => 'uncompressed');

    return 1 if ($is_conflict == 409);

    # Get list of packages installed in the system
    my $packages = script_output('rpm -qa --queryformat "%{SIZE} %{NAME}-%{VERSION}-%{RELEASE}\n" |sort -n -r');
    my @rpm_array = split(/\n/, $packages);
    my $num_packages = scalar @rpm_array;
    record_info('rpm total', "Total number of installed packages: $num_packages");
    record_info('rpm list', $packages);
    push_image_data_to_db('minimal-vm', $image, $num_packages, table => 'num_packages');
    # Push each rpm size
    my @lines = split /\n/, $packages;
    foreach my $line (@lines) {
        my ($size) = $line =~ /^\d+/g;
        my ($rpm) = $line =~ /\s(.*)/g;
        push_image_data_to_db('minimal-vm', $image, $size, table => 'rpms', rpm => $rpm);
    }

    # Get size of directories except those that are irrelevant
    my $cmd = 'du -d 1 --block-size=1K';
    foreach my $dir (qw(/.snapshots /dev /mnt /opt /proc /srv /sys)) {
        $cmd .= " --exclude=$dir";
    }
    $cmd .= ' /';
    my $dirs = script_output($cmd);
    record_info("dirs", "$cmd\n$dirs");
    @lines = ();
    @lines = split /\n/, $dirs;
    foreach my $line (@lines) {
        my ($size) = $line =~ /^\d+/g;
        my ($dir) = $line =~ /\s(.*)/g;
        push_image_data_to_db('minimal-vm', $image, $size, table => 'directories', dir => $dir);
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
        push_image_data_to_db('minimal-vm', $image, $data_mb, table => 'btrfs_df', type => 'Data');
        push_image_data_to_db('minimal-vm', $image, $system_mb, table => 'btrfs_df', type => 'System');
        push_image_data_to_db('minimal-vm', $image, $metadata_mb, table => 'btrfs_df', type => 'Metadata');
        push_image_data_to_db('minimal-vm', $image, $globalreserve_mb, table => 'btrfs_df', type => 'GlobalReserve');
    }
}

1;
