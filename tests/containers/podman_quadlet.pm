# SUSE's openQA tests
#
# Copyright 2023-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman
# Summary: Smoke test for builtin podman tool called quadlet
# Maintainer: QE-C team <qa-c@suse.de>

use strict;
use warnings;
use Mojo::Base qw(containers::basetest);
use testapi;
use serial_terminal qw(select_serial_terminal);
use version_utils qw(package_version_cmp);
use Utils::Systemd qw(systemctl);
use utils qw(script_retry);
use containers::utils qw(check_min_runtime_version);

my $has_build;    # tracking if podman version has support for .build files

my $quadlet_dir = '/etc/containers/systemd';
my $unit_name = 'quadlet-test';

my $build_imagetag = "localhost/nginx";
my $src_image = get_var("CONTAINER_IMAGE_TO_TEST", "registry.opensuse.org/opensuse/tumbleweed:latest");
my @systemd_build = ("$quadlet_dir/$unit_name.build", <<_EOF_);
[Build]
ImageTag=$build_imagetag
SetWorkingDirectory=unit
Label=org.test.Key=TESTING
_EOF_
my @containerfile = ("$quadlet_dir/Containerfile", <<_EOF_);
FROM $src_image
RUN zypper in -y nginx
CMD ["nginx", "-g", "daemon off;"]
_EOF_

my @systemd_network = ("$quadlet_dir/$unit_name.network", <<_EOF_);
[Network]
Subnet=172.18.0.0/24
Gateway=172.18.0.1
IPRange=172.18.0.0/28
Label=org.test.Key=TESTING
_EOF_

my @systemd_pod = ("$quadlet_dir/$unit_name.pod", <<_EOF_);
[Pod]
Network=$unit_name.network
_EOF_

my @systemd_container = ("$quadlet_dir/$unit_name.container", <<_EOF_);
[Unit]
Description=Test nginx container
After=network.target

[Service]
Restart=always
# Extend Timeout to allow time to pull the image
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target

[Container]
Volume=$unit_name.volume:/opt
Pod=$unit_name.pod
_EOF_

my @systemd_volume = ("$quadlet_dir/$unit_name.volume", <<_EOF_);
[Volume]
User=root
Group=root
Label=org.test.Key=TESTING
_EOF_

my @files = (\@systemd_build, \@containerfile, \@systemd_network, \@systemd_pod, \@systemd_container, \@systemd_volume);
my @units;

sub check_unit_enabled {
    my $unit = shift;
    my $expected = shift // 'generated';
    validate_script_output("systemctl --no-pager is-enabled $unit", qr/$expected/, proceed_on_failure => 1);
}

sub run {
    my ($self, $args) = @_;

    select_serial_terminal;
    my $podman = $self->containers_factory('podman');
    $podman->cleanup_system_host();

    my $quadlet = '/usr/libexec/podman/quadlet';

    # create files for generator
    assert_script_run("$quadlet -version");
    for my $file (@files) {
        my ($path, $content) = @$file;
        $content =~ s/\n/\\n/g;
        assert_script_run("echo -e '$content' > $path");
    }
    record_info('Unit', script_output("$quadlet -v -dryrun"));

    # check that services are not present yet
    for my $unit (@units) {
        check_unit_enabled($unit, 'not-found');
    }

    # start the generator and check whether the files are generated
    systemctl("daemon-reload");
    for my $unit (@units) {
        check_unit_enabled($unit);
        systemctl("is-active $unit", expect_false => 1);
    }

    # start build unit
    if ($has_build) {
        script_retry("podman pull $src_image", retry => 3, delay => 60, timeout => 180);
        systemctl("start $unit_name-build.service", timeout => 180);
        record_info('Build output', script_output("journalctl --no-pager -u $unit_name-build"));
        validate_script_output('podman images -n', qr/$build_imagetag/);
    }

    # start the container
    systemctl("start $unit_name.service");
    for my $unit (@units) {
        check_unit_enabled($unit);
        systemctl("is-active $unit.service") unless $unit == "$unit_name-build";
    }

    # check if the network exists on host
    my $net_if = script_output("podman network inspect -f '{{.NetworkInterface}}' systemd-$unit_name");
    assert_script_run("ip a show $net_if");

    # container checks
    validate_script_output('podman container list --noheading', qr/systemd-$unit_name/);
    validate_script_output('podman pod list -n', qr/systemd-$unit_name/);
    validate_script_output('podman volume list -n', qr/systemd-$unit_name/);

    # disable service & remove units
    systemctl("disable --now $unit_name.service");
    systemctl("stop $unit_name-volume.service");
    systemctl("stop $unit_name-network.service");
    systemctl("stop $unit_name-build.service") if ($has_build);
    for my $unit (@units) {
        script_retry("! systemctl --no-pager is-active $unit", retry => 10, delay => 30, timeout => 300);
    }
}

sub pre_run_hook {
    my @unit_suffixes = ("", "-pod", "-network", "-volume");

    # support for .build files was added in 5.2.0
    # https://github.com/containers/podman/releases/tag/v5.2.0
    $has_build = check_min_runtime_version('5.2.0');

    if ($has_build) {
        push @unit_suffixes, "-build";
        $systemd_container[1] .= "Image=$unit_name.build\n";
    } else {
        $systemd_container[1] .= "Image=registry.opensuse.org/opensuse/nginx:latest\n";
    }

    @units = map { "$unit_name$_.service" } @unit_suffixes;
}

sub cleanup {
    script_run(sprintf("rm -f %s", join(' ', map { $_->[0] } @files)));
    systemctl("daemon-reload", ignore_failure => 1);
    script_run("podman rmi $build_imagetag");
    script_run("podman rmi $src_image");
    script_run("podman network rm systemd-$unit_name");
    script_run("podman volume rm systemd-$unit_name");
}

sub post_run_hook {
    my $podman = shift->containers_factory('podman');
    $podman->cleanup_system_host();
    cleanup();
}

sub post_fail_hook {
    my $podman = shift->containers_factory('podman');
    $podman->cleanup_system_host();
    cleanup();
}

1;
