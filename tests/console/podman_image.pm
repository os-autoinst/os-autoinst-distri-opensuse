# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test installation and running of the docker image from the registry for this snapshot
# Maintainer: Fabian Vogt <fvogt@suse.com>

use base 'consoletest';
use testapi;
use utils;
use strict;
use warnings;
use suse_container_urls 'get_suse_container_urls';
use version_utils qw(is_sle is_opensuse is_tumbleweed is_leap);

sub run {
    select_console "root-console";

    my ($image_names, $stable_names) = get_suse_container_urls();

    zypper_call "in podman";

    # If there is no other CNI configured...
    if (get_var("CNI", "podman") == "podman") {
        # ... use the minimal podman CNI
        zypper_call "in podman-cni-config";
    }

    if (is_leap("=15.1")) {
        # bsc#1123387
        zypper_call "in apparmor-parser";
    }

    for my $i (0 .. $#$image_names) {
        # Load the image
        assert_script_run("podman pull $image_names->[$i]", 900);
        # Running executables works
        assert_script_run qq{podman run --rm $image_names->[$i] sh -c 'echo "I work" | grep "I work"'};
        # It is the right version
        if (is_sle) {
            my $osversion = get_required_var("VERSION") =~ s/-SP/ SP/r;    # 15 -> 15, 15-SP1 -> 15 SP1
            validate_script_output("podman run --rm $image_names->[$i] sh -c 'cat /etc/os-release'", sub { /PRETTY_NAME="SUSE Linux Enterprise Server $osversion"/ });
        }
        elsif (is_opensuse) {
            my $version = get_required_var('VERSION');
            validate_script_output qq{podman run --rm $image_names->[$i] cat /etc/os-release}, sub { /PRETTY_NAME="openSUSE (Leap )?${version}.*"/ };
        }
        # zypper lr
        assert_script_run("podman run --rm $image_names->[$i] zypper lr -s", 120);
        # zypper ref
        assert_script_run("podman run --name refreshed $image_names->[$i] sh -c 'zypper -v ref | grep \"All repositories have been refreshed\"'", 120);
        # Commit the image
        assert_script_run("podman commit refreshed refreshed-image", 120);
        # Remove it
        assert_script_run("podman rm --force refreshed", 120);
        # Verify the image works
        assert_script_run("podman run --rm refreshed-image sh -c 'zypper -v ref | grep \"All repositories have been refreshed\"'", 120);

        # Remove the image again to save space
        assert_script_run("podman image rm --force $image_names->[$i] refreshed-image");
    }
}

1;
