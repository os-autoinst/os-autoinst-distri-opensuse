# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Validate container image
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use Mojo::Base 'opensusebasetest';
use elemental3;
use testapi;
use serial_terminal qw(select_serial_terminal);

sub extract_fileslist {
    my %args = @_;

    assert_script_run("$args{runtime} pull $args{uri}");
    my $rootfs = script_output(
        "$args{runtime} inspect -f '{{index .RootFS.Layers 0}}' $args{uri} | cut -d: -f2"
    );

    # Extract files from container
    assert_script_run("$args{runtime} save $args{uri} -o $args{name}.tar");
    assert_script_run("tar xvf $args{name}.tar");
    my @files = script_output("tar tf $rootfs.tar");

    # Record files list
    record_info("$args{name} files", @files);

    return (@files);
}

sub run {
    my $arch = get_required_var('ARCH');
    my $tested_container = get_required_var('TESTED_CONTAINER');
    my $k8s = get_var('K8S', 'null');
    my $runtime = get_required_var('CONTAINER_RUNTIMES');
    my $totest_path = get_required_var('TOTEST_PATH');

    # No GUI, easier and quicker to use the serial console
    select_serial_terminal();

    if ($tested_container =~ /elemental/) {
        # Basic tests of Elemental container image
        my $uri = get_container_uri(
            url => $totest_path,
            arch => $arch,
            regex => ".*elemental-\([0-9]\\..*\)-\(.*\)"
        );

        # Check container image with a simple command
        my $cmd = "$runtime run --rm $uri version";
        assert_script_run($cmd);

        # Record the command version
        record_info('Elemental Version', script_output($cmd));
    } elsif ($tested_container =~ /$k8s/) {
        # Basic tests of K8s container image
        my $k8s_version_prefix = get_required_var('K8S_VERSION_PREFIX');
        my $uri = get_container_uri(
            url => $totest_path,
            arch => $arch,
            regex => ".*${k8s}-tar-\(${k8s_version_prefix}.*\)-\(.*\)"
        );

        # Extract files list
        my @files = extract_fileslist(name => $k8s, runtime => $runtime, uri => $uri);

        die("Missing installer!") unless (join(' ', @files) =~ m/install\.sh/);
    } elsif ($tested_container =~ /lcm/) {
        # Basic tests of Lifecycle Manager container image
        my $uri = get_container_uri(
            url => $totest_path,
            arch => $arch,
            regex => ".*elemental-lifecycle-manager-\(.*\)-\(.*\)"
        );

        # Extract files list
        my @files = extract_fileslist(name => 'lcm', runtime => $runtime, uri => $uri);

        die("Missing raw image!") unless (join(' ', @files) =~ m/elemental-lifecycle-manager/);
    } elsif ($tested_container =~ /longhorn/) {
        # Basic tests of Longhorn container image
        my $uri = get_container_uri(
            url => $totest_path,
            arch => $arch,
            regex => ".*longhorn-\(.*\)-\(.*\)"
        );

        # Extract files list
        my @files = extract_fileslist(name => 'longhorn', runtime => $runtime, uri => $uri);

        die("Missing raw image!") unless (join(' ', @files) =~ m/longhorn_.*\.raw/);
    } else {
        # Not supported yet!
        die("Container type '$tested_container' not supported!");
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
