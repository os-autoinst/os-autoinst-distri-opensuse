# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test installation and running of the docker image from the registry for this snapshot
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base 'consoletest';
use testapi;
use utils;
use strict;
use registration qw(add_suseconnect_product install_docker_when_needed);
use suse_container_urls qw(get_suse_container_urls);
use version_utils qw(is_sle is_opensuse is_tumbleweed is_leap);

sub run {
    select_console "root-console";

    my ($image_names, $stable_names) = get_suse_container_urls();

    if (is_sle) {
        my $SCC_REGCODE = get_required_var("SCC_REGCODE");

        if (script_run("SUSEConnect --status-text") != 0) {
            assert_script_run("SUSEConnect --cleanup");
            assert_script_run("SUSEConnect -r $SCC_REGCODE");
            add_suseconnect_product("sle-module-containers", substr(get_required_var('VERSION'), 0, 2));
        }
    }

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
        assert_script_run('curl -LO https://storage.googleapis.com/container-diff/latest/container-diff-linux-amd64', 240);
        assert_script_run('chmod +x container-diff-linux-amd64 && sudo mv container-diff-linux-amd64 /usr/local/bin/container-diff');
    }

    for my $i (0 .. $#$image_names) {
        # Load the image
        assert_script_run("docker pull $image_names->[$i]", 1000);
        # Running executables works
        assert_script_run qq{docker container run --entrypoint '/bin/bash' --rm $image_names->[$i] -c 'echo "I work" | grep "I work"'};
        # It is the right version
        if (is_sle) {
            my $osversion = get_required_var("VERSION") =~ s/-SP/ SP/r;    # 15 -> 15, 15-SP1 -> 15 SP1
            validate_script_output("docker container run --entrypoint '/bin/bash' --rm $image_names->[$i] -c 'cat /etc/os-release'", sub { /PRETTY_NAME="SUSE Linux Enterprise Server $osversion"/ });
        }
        elsif (is_opensuse) {
            my $version = get_required_var('VERSION');
            validate_script_output qq{docker container run --rm $image_names->[$i] cat /etc/os-release}, sub { /PRETTY_NAME="openSUSE (Leap )?${version}.*"/ };
        }
        # zypper lr
        assert_script_run("docker container run --entrypoint '/bin/bash' --rm $image_names->[$i] -c 'zypper lr -s'", 120);
        # zypper ref
        assert_script_run("docker container run --name refreshed --entrypoint '/bin/bash' $image_names->[$i] -c 'zypper -v ref | grep \"All repositories have been refreshed\"'", 120);
        # Commit the image
        assert_script_run("docker commit refreshed refreshed-image", 120);
        # Remove it
        assert_script_run("docker rm --force refreshed", 120);
        # Verify the image works
        assert_script_run("docker container run --name refreshed --entrypoint '/bin/bash' --rm refreshed-image -c 'zypper -v ref | grep \"All repositories have been refreshed\"'", 120);

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
}

1;

