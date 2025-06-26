# SUSE's openQA tests
#
# Copyright 2020-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman & docker
# Summary: Test installation and running of the container image from the registry for this snapshot
# This module is unified to run independented the host os.
# Maintainer: QE-C team <qa-c@suse.de>

use strict;
use warnings;
use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use containers::common;
use containers::container_images;
use containers::urls qw(get_image_uri);
use db_utils qw(push_image_data_to_db);
use containers::utils qw(reset_container_network_if_needed);
use version_utils qw(check_version get_os_release is_sle is_tumbleweed);

sub scc_apply_docker_image_credentials {
    my $regcode = get_var 'SCC_DOCKER_IMAGE';
    assert_script_run "cp /etc/zypp/credentials.d/SCCcredentials{,.bak}";
    assert_script_run "echo -ne \"$regcode\" > /etc/zypp/credentials.d/SCCcredentials";
}

sub scc_restore_docker_image_credentials {
    assert_script_run "cp /etc/zypp/credentials.d/SCCcredentials{.bak,}" if (is_sle() && get_var('SCC_DOCKER_IMAGE'));
}

sub test_rpm_db_backend {
    my ($self, %args) = @_;
    my $image = $args{image};
    my $runtime = $args{runtime};

    die 'Argument $image not provided!' unless $image;
    die 'Argument $runtime not provided!' unless $runtime;

    my ($running_version, $sp, $host_distri) = get_os_release("$runtime run $image");
    # TW and SLE 15-SP3+ uses rpm-ndb in the image
    if ($host_distri eq 'opensuse-tumbleweed' || ($host_distri eq 'sles' && check_version('>=15-SP3', "$running_version-SP$sp", qr/\d{2}(?:-sp\d)?/))) {
        validate_script_output "$runtime run $image rpm --eval %_db_backend", sub { m/ndb/ };
    }
}

sub test_systemd_install {
    my ($self, %args) = @_;
    my $image = $args{image};
    my $runtime = $args{runtime};
    die 'Argument $image not provided!' unless $image;
    die 'Argument $runtime not provided!' unless $runtime;
    # reference values:
    my $leap_vmin = '15.4';
    my $sle_vmin = '15-SP4';
    my $bci_vmin = '15-SP5';
    # release
    my ($image_version, $image_sp, $image_id) = get_os_release("$runtime run --entrypoint '' $image");
    # TW and starting with SLE 15-SP4/Leap15.4 systemd's dependency with udev has been dropped
    if ($image_id eq 'opensuse-tumbleweed' ||
        ($image_id eq 'opensuse-leap' && check_version('>=' . $leap_vmin, "$image_version.$image_sp", qr/\d{2}\.\d/)) ||
        ($image_id eq 'sles' && check_version('>=' . $sle_vmin, "$image_version-SP$image_sp", qr/\d{2}-sp\d/))) {
        # Skip run case:
        return 0 if ($image_id eq 'sles' && check_version('<' . $bci_vmin, "$image_version-SP$image_sp", qr/\d{2}-sp\d/));
        # lock to SLE_BCI repo for SLES versions not under LTSS (LTSS has no BCI repo anymore)
        my $repo = ($image_id eq 'sles' && check_version('>=' . $bci_vmin, "$image_version-SP$image_sp", qr/\d{2}-sp\d/)) ? '-r SLE_BCI' : '';
        assert_script_run("$runtime run $image /bin/bash -c 'zypper al udev && zypper -n in $repo systemd'", timeout => 300);
    }
}

sub run {
    my ($self, $args) = @_;
    select_serial_terminal();

    my $runtime = $args->{runtime};
    my $engine = $self->containers_factory($runtime);
    reset_container_network_if_needed($runtime);

    scc_apply_docker_image_credentials() if (get_var('SCC_DOCKER_IMAGE') && $runtime eq 'docker');
    # Running podman as root with docker installed may be problematic as netavark uses nftables
    # while docker still uses iptables.
    # Use workaround suggested in:
    # - https://fedoraproject.org/wiki/Changes/NetavarkNftablesDefault#Known_Issue_with_docker
    # - https://docs.docker.com/engine/network/packet-filtering-firewalls/#docker-on-a-router
    if (is_tumbleweed && $runtime eq "podman" && get_var("CONTAINER_RUNTIMES") =~ /docker/) {
        script_run "iptables -I DOCKER-USER -j ACCEPT";
    }

    # We may test either one specific image VERSION or comma-separated CONTAINER_IMAGE_VERSIONS
    my $versions = get_var('CONTAINER_IMAGE_VERSIONS', get_required_var('VERSION'));
    for my $version (split(/,/, $versions)) {
        my $image = get_image_uri(version => $version);

        if (get_var('IMAGE_STORE_DATA')) {
            # If wanted, push image information to the DB
            script_retry("$runtime pull -q $image", timeout => 300, delay => 60, retry => 3);
            my $size_b = script_output("$engine inspect --format \"{{.VirtualSize}}\" $image");
            my $size_mb = $size_b / 1000000;
            push_image_data_to_db('containers', $image, $size_mb, flavor => 'base', type => 'VirtualSize');
        }

        record_info "IMAGE", "Testing image: $image Version: $version";
        test_container_image(image => $image, runtime => $engine);
        $self->test_rpm_db_backend(image => $image, runtime => $engine);
        $self->test_systemd_install(image => $image, runtime => $engine);
        my $beta = $version eq get_var('VERSION') ? get_var('BETA', 0) : 0;
        test_opensuse_based_image(image => $image, runtime => $engine, version => $version, beta => $beta) unless ($image =~ /bci/);
    }
    scc_restore_docker_image_credentials() if ($runtime eq 'docker');

    $engine->cleanup_system_host();
}

1;
