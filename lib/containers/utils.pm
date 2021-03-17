# SUSE's openQA tests
#
# Copyright © 2020-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic functions for testing docker
# Maintainer: Anna Minou <anna.minou@suse.de>, qa-c@suse.de

package containers::utils;

use base Exporter;
use Exporter;

use base "consoletest";
use testapi;
use utils;
use strict;
use warnings;
use version_utils;

our @EXPORT = qw(basic_container_tests can_build_sle_base);

sub basic_container_tests {
    my ($runtime) = @_;

    # Images from docker.io registry are listed without the 'docker.io/library/'
    # Images from custom registry are listed with the 'server/library/'
    # We also filter images the same way they are listed.
    my $prefix = ($runtime->registry =~ /docker\.io/) ? "" : $runtime->registry . "/library/";

    my $alpine_image_version = '3.6';
    my $alpine               = "${prefix}alpine:$alpine_image_version";
    my $hello_world          = "${prefix}hello-world";
    my $leap                 = "registry.opensuse.org/opensuse/leap";
    my $tumbleweed           = "registry.opensuse.org/opensuse/tumbleweed";

    # Test search feature
    $runtime->_rt_validate_script_output("search --no-trunc tumbleweed", sub { m/Official openSUSE Tumbleweed images/ });

    #   - pull minimalistic alpine image of declared version using tag
    #   - https://store.docker.com/images/alpine
    $runtime->_rt_assert_script_run("image pull $alpine", timeout => 300);
    #   - pull typical docker demo image without tag. Should be latest.
    #   - https://store.docker.com/images/hello-world
    $runtime->_rt_assert_script_run("image pull $hello_world", timeout => 300);
    #   - pull image of last released version of openSUSE Leap
    if (!check_var('ARCH', 's390x')) {
        $runtime->_rt_assert_script_run("image pull $leap", timeout => 600);
    } else {
        record_soft_failure("bsc#1171672 Missing Leap:latest container image for s390x");
    }
    #   - pull image of openSUSE Tumbleweed
    $runtime->_rt_assert_script_run("image pull $tumbleweed", timeout => 600);

    # All images can be listed
    $runtime->_rt_assert_script_run("image ls");
    # Local images can be listed
    $runtime->_rt_assert_script_run("image ls none");
    #   - filter with tag
    $runtime->_rt_assert_script_run("image ls $alpine | grep \"alpine\\s*$alpine_image_version\"");
    #   - filter without tag
    $runtime->_rt_assert_script_run("image ls $hello_world | grep \"hello-world\\s*latest\"");
    #   - all local images
    my $local_images_list = $runtime->_rt_script_output("image ls");
    die($runtime->engine . " image $tumbleweed not found") unless ($local_images_list =~ /opensuse\/tumbleweed\s*latest/);
    die($runtime->engine . " image $leap not found") if (!check_var('ARCH', 's390x') && !$local_images_list =~ /opensuse\/leap\s*latest/);

    # Containers can be spawned
    #   - using 'run'
    $runtime->_rt_assert_script_run("container run --name test_1 $hello_world | grep 'Hello from Docker\!'");
    #   - using 'create', 'start' and 'logs' (background container)
    $runtime->_rt_assert_script_run("container create --name test_2 $alpine /bin/echo Hello world");
    $runtime->_rt_assert_script_run("container start test_2 | grep test_2");
    $runtime->_rt_assert_script_run("container logs test_2 | grep 'Hello world'");
    #   - using 'run --rm'
    $runtime->_rt_assert_script_run("container run --name test_ephemeral --rm $alpine /bin/echo Hello world | grep \"Hello world\"");
    #   - using 'run -d' and 'inspect' (background container)
    my $container_name = 'tw';
    $runtime->_rt_assert_script_run("container run -d --name $container_name $tumbleweed tail -f /dev/null");
    $runtime->_rt_assert_script_run("container inspect --format='{{.State.Running}}' $container_name | grep true");
    my @output_containers = $runtime->enum_containers();
    die('error: missing container test_1') unless (grep(m/test_1/, @output_containers));
    die('error: missing container test_2') unless (grep(m/test_2/, @output_containers));
    die('error: ephemeral container was not removed') if (grep(m/test_ephemeral/, @output_containers));
    die("error: missing container $container_name") unless (grep(m/$container_name/, @output_containers));

    # Containers' state can be saved to a docker image
    if ($runtime->_rt_script_run("container exec $container_name zypper -n in curl", timeout => 300)) {
        record_info('poo#40958 - curl install failure, try with force-resolution.');
        my $output = $runtime->_rt_script_output("container exec $container_name zypper in --force-resolution -y -n curl", timeout => 600);
        die('error: curl not installed in the container') unless (($output =~ m/Installing: curl.*done/) || ($output =~ m/\'curl\' .* already installed/));
    }
    $runtime->_rt_assert_script_run("container commit $container_name tw:saved", timeout => 240);

    # Network is working inside of the containers
    my $output = $runtime->_rt_script_output("container run tw:saved curl -I google.de");
    die("network is not working inside of the container tw:saved") unless ($output =~ m{Location: http://www\.google\.de/});

    # Using an init process as PID 1
    $runtime->_rt_assert_script_run("run --rm --init $tumbleweed ps --no-headers -xo 'pid args' | grep '1 .*init'");

    if (script_run('command -v man') == 0) {
        assert_script_run("man -P cat " . $runtime->engine . " build | grep '$engine-build - Build'");
    }

    # Containers can be stopped
    $runtime->_rt_assert_script_run("container stop $container_name");
    $runtime->_rt_assert_script_run("container inspect --format='{{.State.Running}}' $container_name | grep false");

    # Containers can be deleted
    my $cmd_docker_rm = $runtime->engine . " rm test_1";
    assert_script_run("$cmd_docker_rm");
    @output_containers = $runtime->enum_containers();
    die("error: container was not removed: $cmd_docker_rm") if grep(m/test_1/, @output_containers);
    my $cmd_docker_container_prune = $runtime->engine . " container prune -f";
    assert_script_run("$cmd_docker_container_prune");
    @output_containers = $runtime->enum_containers();
    die("error: container was not removed: $cmd_docker_container_prune") if (grep(m/test_2/, @output_containers));

    # Images can be deleted
    my $cmd_runtime_rmi = $runtime->engine . " rmi -a";
    @output_containers = $runtime->enum_containers();
    my $error_str = sprintf("error: %s image rmi -a ", $runtime->engine);
    die($error_str . $leap)                                 if (grep(m/Untagged:.*opensuse\/leap/,       @output_containers));
    die($error_str . $tumbleweed)                           if (grep(m/Untagged:.*opensuse\/tumbleweed/, @output_containers));
    die($error_str . "tw:saved")                            if (grep(m/Untagged:.*tw:saved/,             @output_containers));
    record_soft_failure($error_str . $alpine)               if (grep(m/Untagged:.*alpine/,               @output_containers));
    record_soft_failure($error_str . "$hello_world:latest") if (grep(m/Untagged:.*hello-world:latest/,   @output_containers));
}

=head2 can_build_sle_base

C<can_build_sle_base> should be used to identify if sle base image runs against a
system that it does not support registration and SUSEConnect.
In this case the build of the base image is not going to work as it lacks the repositories

The call should return false if the test is run on a non-sle host.

=cut
sub can_build_sle_base {
    # script_run returns 0 if true, but true is 1 on perl
    my $has_sle_registration = !script_run("test -e /etc/zypp/credentials.d/SCCcredentials");
    return check_os_release('sles', 'ID') && $has_sle_registration;
}

1;
