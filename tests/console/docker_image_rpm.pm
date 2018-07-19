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

sub run {
    select_console 'root-console';

    my $version = get_required_var('VERSION');

    my $image_name;
    my $image_path;

    if (is_tumbleweed) {
        $image_name = 'opensuse/tumbleweed:current';
        $image_path = '/usr/share/suse-docker-images/native/*-image*.tar.xz';

        # For Tumbleweed, the image is wrapped inside an RPM
        zypper_call "in docker opensuse-tumbleweed-image";
    }
    elsif (is_leap('15.0+')) {
        $image_name = "opensuse-leap-$version:current";
        $image_path = "/usr/share/suse-docker-images/native/opensuse-leap${version}-image.tar.xz";

        # For Leap, the docker image is the ISO asset
        my $image_filename = get_required_var('ISO');
        $image_filename =~ s/^.*\///;
        my $image_url = autoinst_url("/assets/other/$image_filename");
        assert_script_run "curl $image_url --create-dirs -o $image_path";
    }
    else {
        die 'Only know about Tumbleweed and Leap 15.0+ docker images';
    }

    # Start the docker daemon, normally done by previous test modules already
    systemctl 'start docker';
    systemctl 'status docker';
    assert_script_run 'docker info';

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
