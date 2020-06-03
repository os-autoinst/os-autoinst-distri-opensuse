# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test installation and running of the docker image from the registry for this snapshot
# - if on SLE, enable internal registry
# - load image
# - run container
# - run some zypper commands
# - commit the image
# - remove the container, run it again and verify that the new image works
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base 'consoletest';
use testapi;
use utils;
use strict;
use warnings;
use containers::common;
use suse_container_urls 'get_suse_container_urls';
use version_utils qw(is_sle is_opensuse is_tumbleweed is_leap);

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my ($image_names, $stable_names) = get_suse_container_urls();
    my ($plugin, $osversion, $version);

    install_docker_when_needed();

    if (is_sle) {
        # Allow our internal 'insecure' registry
        assert_script_run("mkdir -p /etc/docker");
        assert_script_run('cat /etc/docker/daemon.json; true');
        assert_script_run(
            'echo "{ \"insecure-registries\" : [\"registry.suse.de\", \"registry.suse.de:443\", \"registry.suse.de:5000\"] }" > /etc/docker/daemon.json');
        assert_script_run('cat /etc/docker/daemon.json');
        systemctl('restart docker');
    }

    if (check_var("ARCH", "x86_64")) {
        zypper_call("install container-diff");
    }

    for my $i (0 .. $#$image_names) {
        # Load the image
        assert_script_run("docker pull $image_names->[$i]", 1000);
        # Running executables works
        assert_script_run qq{docker container run --entrypoint '/bin/bash' --rm $image_names->[$i] -c 'echo "I work" | grep "I work"'};
        # It is the right version
        if (is_sle) {
            $osversion = get_required_var("VERSION") =~ s/-SP/ SP/r;    # 15 -> 15, 15-SP1 -> 15 SP1
            validate_script_output("docker container run --entrypoint '/bin/bash' --rm $image_names->[$i] -c 'cat /etc/os-release'", sub { /PRETTY_NAME="SUSE Linux Enterprise Server $osversion"/ });

            if (is_sle('=12-SP3')) {
                $plugin = '/usr/lib/zypp/plugins/services/container-suseconnect';
                assert_script_run "docker container run --entrypoint '/bin/bash' --rm $image_names->[$i] -c '$plugin'";
            } else {
                $plugin = '/usr/lib/zypp/plugins/services/container-suseconnect-zypp';
                assert_script_run "docker container run --entrypoint '/bin/bash' --rm $image_names->[$i] -c '$plugin -v'";
                script_run "docker container run --entrypoint '/bin/bash' --rm $image_names->[$i] -c '$plugin lp'", 420;
                script_run "docker container run --entrypoint '/bin/bash' --rm $image_names->[$i] -c '$plugin lm'", 420;
            }
        } elsif (is_opensuse) {
            $version = get_required_var('VERSION');
            validate_script_output qq{docker container run --rm $image_names->[$i] cat /etc/os-release}, sub { /PRETTY_NAME="openSUSE (Leap )?${version}.*"/ };
        }
        # zypper lr
        script_retry("docker container run --entrypoint '/bin/bash' --rm $image_names->[$i] -c 'zypper lr -s'", timeout => 600, delay => 5, retry => 5);
        # zypper ref
        script_retry("docker container run --name refreshed --entrypoint '/bin/bash' $image_names->[$i] -c 'zypper -v ref | grep \"All repositories have been refreshed\"'; if [[ \"\$?\" != \"0\" ]]; then docker rm --force refreshed; false; fi", timeout => 600, delay => 5, retry => 5);
        # Commit the image
        assert_script_run("docker commit refreshed refreshed-image", 300);
        # Remove it
        assert_script_run("docker rm --force refreshed", 120);
        # Verify the image works
        script_retry("docker container run --entrypoint '/bin/bash' --rm refreshed-image -c 'zypper -v ref | grep \"All repositories have been refreshed\"'", timeout => 600, delay => 5, retry => 5);

        if (check_var("ARCH", "x86_64")) {
            # container-diff
            my $image_file = $image_names->[$i] =~ s/\/|:/-/gr;
            if (script_run("docker pull $stable_names->[$i]", 600) == 0) {
                assert_script_run("container-diff diff daemon://$image_names->[$i] daemon://$stable_names->[$i] --type=rpm --type=file --type=history > /tmp/container-diff-$image_file.txt", 300);
                upload_logs("/tmp/container-diff-$image_file.txt");
                assert_script_run("docker image rm --force $stable_names->[$i]");
            }
            else {
                record_soft_failure("Could not compare $image_names->[$i] to $stable_names->[$i] as $stable_names->[$i] could not be downloaded");
            }
        }

        # Remove the image again to save space
        assert_script_run("docker image rm --force $image_names->[$i] refreshed-image");
    }

    clean_docker_host();
}

1;
