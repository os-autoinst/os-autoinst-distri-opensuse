# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test installation and running of the docker image from RPM repository for this snapshot
# Maintainer: Fabian Vogt <fvogt@suse.com>

use base 'consoletest';
use testapi;
use utils;
use strict;
use version_utils qw(is_leap is_tumbleweed);
use registration "install_docker_when_needed";

sub run {
    select_console 'root-console';

    my $version = get_required_var('VERSION');

    my $repo_url;
    my $image_name;
    my $image_path;

    install_docker_when_needed();

    if (is_tumbleweed) {
        $image_name = 'opensuse/tumbleweed:current';
        $image_path = '/usr/share/suse-docker-images/native/*-image*.tar.xz';

        # For Tumbleweed, the image is wrapped inside an RPM
        zypper_call "in opensuse-tumbleweed-image";
    }
    else {
        die 'Only know about Tumbleweed';
    }

    # Load the image
    assert_script_run "docker load -i $image_path";
    # Show that the image got registered
    assert_script_run "docker images $image_name";
    # Running executables works
    assert_script_run qq{docker container run --rm $image_name echo "I work" | grep "I work"};
    # It is the correct openSUSE version
    validate_script_output qq{docker container run --rm $image_name cat /etc/os-release}, sub { /PRETTY_NAME="openSUSE (Leap )?${version}( .*)?"/ };
    # Zypper and network are working
    assert_script_run qq{docker container run --rm $image_name zypper -v ref | grep "All repositories have been refreshed"};

    # Interactive session works
    type_string <<"EOF";
docker container run --rm -it $image_name /bin/bash; echo DOCKER-\$?- > /dev/$serialdev
exit 42
EOF
    wait_serial 'DOCKER-42-' || die 'Interactive test failed';

    # Remove the image again to save space
    assert_script_run "docker image rm --force $image_name";
}

1;
