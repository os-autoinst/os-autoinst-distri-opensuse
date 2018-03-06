# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test installation and running of the docker image for this snapshot
# Maintainer: Fabian Vogt <fvogt@suse.com>

use base 'consoletest';
use testapi;
use utils;
use strict;

sub run {
    select_console 'root-console';

    check_var('VERSION', 'Tumbleweed') || die 'Only have docker images for Tumbleweed';

    my $rpm_name   = 'opensuse-tumbleweed-image';
    my $image_name = 'opensuse/tumbleweed:current';

    # Install the image
    zypper_call "in docker $rpm_name";
    # Start the docker daemon, normally done by previous test modules already
    systemctl 'start docker';
    systemctl 'status docker';
    assert_script_run 'docker info';

    # Load the image
    assert_script_run 'docker load -i /usr/share/suse-docker-images/native/*-image*.tar.xz';
    # Show that the image got registered
    assert_script_run "docker images $image_name";
    # Running executables works
    assert_script_run qq{docker container run --rm $image_name echo "I work" | grep "I work"};
    # It is openSUSE Tumbleweed
    assert_script_run qq{docker container run --rm $image_name cat /etc/os-release | grep 'PRETTY_NAME="openSUSE Tumbleweed"'};
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
    zypper_call "rm $rpm_name";
}

1;
# vim: set sw=4 et:
