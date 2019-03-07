# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test sle2docker installation and  usage
#    Cover the following aspects of sle2docker:
#      * package and sle docker image can be installed
#      * images can be listed, activated
#      * sle docker container is able to run
# Maintainer: Petr Cervinka <pcervinka@suse.com>


use base "consoletest";
use testapi;
use utils;
use registration "install_docker_when_needed";
use strict;
use warnings;
use version_utils 'is_sle';

sub run {
    return record_soft_failure('bsc#1123502 - missing Container module on SLE12-SP5') if is_sle('=12-sp5');

    select_console('root-console');

    install_docker_when_needed();

    # install sle2docker and sle docker image
    zypper_call("in sle2docker sles12sp2-docker-image");

    # list images and check that sles image is available
    validate_script_output("sle2docker list", sub { m/sles12sp2-docker/ });

    # activate images
    assert_script_run("sle2docker activate --all");

    # check that number of images visible to docker was increased
    validate_script_output("docker info", sub { m/Images\: 2/ });

    # Check for bsc#1064010
    my $docker_images_output = script_output("docker images");
    my $docker_images        = $docker_images_output =~ /sles12sp2-docker/;
    if ($docker_images) {
        record_soft_failure("bsc#1064010");
        # run hello world from sles with applied workaround and delete the container
        validate_script_output("docker  run --rm  suse/sles12sp2-docker /bin/echo Hello world", sub { m/Hello world/ });
    }
    else {
        # run hello world from sles and delete the container
        validate_script_output("docker  run --rm  suse/sles12sp2 /bin/echo Hello world", sub { m/Hello world/ });
    }
    # delete sle images
    assert_script_run("docker rmi --force \$(docker images -a  | grep suse | grep -v latest | awk {'print \$3'})");

    # recheck number of images
    validate_script_output("docker info", sub { m/Images\: 0/ });
}

1;
