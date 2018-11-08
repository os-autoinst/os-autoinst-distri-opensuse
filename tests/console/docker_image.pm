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
use version_utils qw(is_sle is_opensuse is_tumbleweed is_leap);

sub run {
    select_console "root-console";

    my $version      = get_required_var('VERSION');
    my @image_names  = ();
    my @stable_names = ();
    if (is_sle("=12-SP3")) {
        push @image_names,  "registry.suse.de/suse/sle-12-sp3/docker/update/cr/images/suse/sles12sp3:latest";
        push @stable_names, "registry.suse.com/suse/sles12sp3:latest";
    }
    elsif (is_sle("=15")) {
        push @image_names,  "registry.suse.de/suse/sle-15/update/cr/images/suse/sle15:latest";
        push @stable_names, "registry.suse.com/suse/sle15:latest";
    }
    elsif (is_tumbleweed) {
        push @image_names,  "registry.opensuse.org/opensuse/factory/totest/containers/opensuse/tumbleweed:latest";
        push @stable_names, "docker.io/opensuse/tumbleweed";
    }
    elsif (is_leap(">15.0")) {
        push @image_names, "registry.opensuse.org/opensuse/leap/${version}/images/totest/containers/opensuse/leap:${version}";
        #push @stable_names, "docker.io/opensuse/leap:${version}";
        push @stable_names, "docker.io/opensuse/leap:15.0";
    }
    else {
        die("No image locations defined for this distro.");
    }

    if (is_sle) {
        my $SCC_REGCODE = get_required_var("SCC_REGCODE");

        if (script_run("SUSEConnect --status-text") != 0) {
            assert_script_run("SUSEConnect --cleanup");
            assert_script_run("SUSEConnect -r $SCC_REGCODE");
            add_suseconnect_product("sle-module-containers", substr($version, 0, 2));
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

    assert_script_run(
        "curl -LO https://storage.googleapis.com/container-diff/latest/container-diff-linux-amd64 &&
        chmod +x container-diff-linux-amd64 && mv container-diff-linux-amd64 /usr/local/bin/container-diff"
    );

    for my $i (0 .. $#image_names) {
        # Load the image
        assert_script_run("docker pull $image_names[$i]", 600);
        # Running executables works
        assert_script_run qq{docker container run --entrypoint '/bin/bash' --rm $image_names[$i] -c 'echo "I work" | grep "I work"'};
        # It is the right version
        if (is_sle("=12-SP3")) {
            validate_script_output("docker container run --entrypoint '/bin/bash' --rm $image_names[$i] -c 'cat /etc/os-release'", sub { /PRETTY_NAME="SUSE Linux Enterprise Server 12 SP3"/ });
        }
        elsif (is_sle("=15")) {
            validate_script_output("docker container run --entrypoint '/bin/bash' --rm $image_names[$i] -c 'cat /etc/os-release'", sub { /PRETTY_NAME="SUSE Linux Enterprise Server 15"/ });
        }
        elsif (is_opensuse) {
            validate_script_output qq{docker container run --rm $image_names[$i] cat /etc/os-release}, sub { /PRETTY_NAME="openSUSE (Leap )?${version}.*"/ };
        }
        # zypper lr
        assert_script_run("docker container run --entrypoint '/bin/bash' --rm $image_names[$i] -c 'zypper lr -s'", 120);
        # zypper ref
        assert_script_run("docker container run --entrypoint '/bin/bash' --rm $image_names[$i] -c 'zypper -v ref | grep \"All repositories have been refreshed\"'", 120);

        # container-diff
        my $image_file = $image_names[$i] =~ s/\/|:/-/gr;
        assert_script_run("docker pull $image_names[$i]",  600);
        assert_script_run("docker pull $stable_names[$i]", 600);
        assert_script_run("container-diff diff daemon://$image_names[$i] daemon://$stable_names[$i] --type=rpm --type=file --type=history > /tmp/container-diff-$image_file.txt", 300);
        upload_logs("/tmp/container-diff-$image_file.txt");

        # Remove the image again to save space
        assert_script_run("docker image rm --force $image_names[$i]");
    }
}

1;
