# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: container-suseconnect test for multiple container runtimes
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils qw(is_opensuse);
use utils;

my $runtime;

sub run {
    my ($self, $args) = @_;

    my $runtime_name = $args->{runtime};

    select_serial_terminal;

    assert_script_run("curl " . data_url('containers/container-suseconnect/Dockerfile') . " -o ./Dockerfile");

    $runtime = $self->containers_factory($runtime_name);

    my $build_cmd = $runtime_name =~ /podman/i
      ? "buildah bud --layers"
      : "DOCKER_BUILDKIT=1 docker build";

    my $scc_credentials_path = '/etc/zypp/credentials.d/SCCcredentials';
    my $suseconnect_path = '/etc/SUSEConnect';

    my $image_tag = "suseconnect-test-$runtime_name";
    my $container_cmd = "$runtime_name run --rm $image_tag";

    if ($runtime_name =~ /podman/i && script_run("command -v buildah")) {
        record_info("Installing buildah");
        zypper_call('in buildah');
    }

    assert_script_run(
        "$build_cmd " .
          "--build-arg ADDITIONAL_MODULES=sle-module-desktop-applications,sle-module-development-tools " .
          "--secret=id=SCCcredentials,src=$scc_credentials_path " .
          "--secret=id=SUSEConnect,src=$suseconnect_path " .
          "-t $image_tag ."
    );

    validate_script_output("$container_cmd container-suseconnect lp", sub { m/All available products:/ });
    validate_script_output("$container_cmd container-suseconnect lm", sub { m/All available modules:/ });
    validate_script_output("$container_cmd rpm -qa", sub { m/gvim/ });
}

sub cleanup {
    my ($self) = @_;
    script_run("rm -f ./Dockerfile");
    $runtime->cleanup_system_host();
}

sub post_run_hook { shift->cleanup() }
sub post_fail_hook { shift->cleanup() }

1;
