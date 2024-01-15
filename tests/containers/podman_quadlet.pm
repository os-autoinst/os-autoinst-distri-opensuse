# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman
# Summary: Smoke test for builtin podman tool called quadlet
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base qw(containers::basetest);
use testapi;
use serial_terminal qw(select_serial_terminal);
use version_utils qw(package_version_cmp);
use Utils::Systemd qw(systemctl);

sub check_unit_states {
    my $expected = shift // 'generated';
    validate_script_output('systemctl --no-pager is-enabled sleeper.service', qr/$expected/, proceed_on_failure => 1);
    validate_script_output('systemctl --no-pager is-enabled sleeper-volume.service', qr/$expected/, proceed_on_failure => 1);
}

sub run {
    my ($self, $args) = @_;

    select_serial_terminal;
    my $podman = $self->containers_factory('podman');
    $podman->cleanup_system_host();

    my $quadlet = '/usr/libexec/podman/quadlet';
    my $unit_name = 'sleeper';
    my $systemd_unit = <<_EOF_;
[Unit]
Description=The sleep container
After=local-fs.target

[Container]
Image=registry.opensuse.org/opensuse/tumbleweed:latest
Exec=sleep 1000
Volume=sleeper.volume:/opt

[Service]
# Restart service when sleep finishes
Restart=always
# Extend Timeout to allow time to pull the image
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target
_EOF_

    my $systemd_vol = <<_EOF_;
[Volume]
User=root
Group=root
Label=org.test.Key=TESTING
_EOF_

    # create files for generator
    assert_script_run("$quadlet -version");
    assert_script_run("echo '$_' >> /etc/containers/systemd/$unit_name.container") foreach (split /\n/, $systemd_unit);
    assert_script_run("echo '$_' >> /etc/containers/systemd/$unit_name.volume") foreach (split /\n/, $systemd_vol);
    record_info('Unit', script_output("$quadlet -v -dryrun"));

    # check that services are not present yet
    check_unit_states('not-found');

    # start the generator and check whether the files are generated
    assert_script_run("systemctl daemon-reload");
    check_unit_states();
    systemctl("is-active sleeper.service", expect_false => 1);
    systemctl("is-active sleeper-volume.service", expect_false => 1);

    # start the container
    assert_script_run("systemctl start sleeper-volume.service");
    assert_script_run("systemctl start sleeper.service");
    check_unit_states();
    systemctl("is-active sleeper.service");
    systemctl("is-active sleeper-volume.service");

    # container checks
    validate_script_output('podman container list', qr/systemd-sleeper/);
    validate_script_output('podman volume list', qr/systemd-sleeper/);
}

sub post_run_hook {
    my $podman = shift->containers_factory('podman');
    $podman->cleanup_system_host();
}
sub post_fail_hook {
    my $podman = shift->containers_factory('podman');
    $podman->cleanup_system_host();
}

1;
