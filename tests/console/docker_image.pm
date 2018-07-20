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
use registration "add_suseconnect_product";
use version_utils "is_sle";

sub run {
    select_console "root-console";

    my $image_name;
    if (is_sle("=12-SP3")) {
        $image_name = "registry.suse.de/suse/sle-12-sp3/update/products/casp30/container/sles12:sp3";
    }
    elsif (is_sle("=15")) {
        $image_name = "registry.suse.de/suse/sle-15/update/cr/images/suse/sle15:current";
    }
    else {
        die("This test only works at SLE12SP3 and SLE15.");
    }

    my $version     = get_required_var("VERSION");
    my $SCC_REGCODE = get_required_var("SCC_REGCODE");

    if (script_run("SUSEConnect --status-text") != 0) {
        assert_script_run("SUSEConnect --cleanup");
        assert_script_run("SUSEConnect -r $SCC_REGCODE");
        add_suseconnect_product("sle-module-containers", substr($version, 0, 2));
    }

    # Allow our internal 'insecure' registry
    zypper_call("in docker");
    assert_script_run("mkdir -p /etc/docker");
    assert_script_run('cat /etc/docker/daemon.json; true');
    assert_script_run(
        'echo "{ \"insecure-registries\" : [\"registry.suse.de\", \"registry.suse.de:443\", \"registry.suse.de:5000\"] }" > /etc/docker/daemon.json');
    assert_script_run('cat /etc/docker/daemon.json');
    systemctl('restart docker');

    # Load the image
    assert_script_run("docker pull $image_name", 120);
    # Running executables works
    assert_script_run("docker container run --rm $image_name echo 'I work' | grep 'I work'");
    # It is the right SLE version
    if (is_sle("=12-SP3")) {
        validate_script_output("docker container run --rm $image_name cat /etc/os-release", sub { /PRETTY_NAME="SUSE Linux Enterprise Server 12 SP3"/ });
    }
    elsif (is_sle("=15")) {
        validate_script_output qq{docker container run --rm $image_name cat /etc/os-release}, sub { /PRETTY_NAME="SUSE Linux Enterprise Server 15"/ };
    }
    # zypper lr
    assert_script_run("docker container run --rm $image_name zypper lr -s");
    # zypper ref
    assert_script_run("docker container run --rm $image_name zypper -v ref | grep 'All repositories have been refreshed'");

    # container-diff
    assert_script_run(
        "curl -LO https://storage.googleapis.com/container-diff/latest/container-diff-linux-amd64 &&
        chmod +x container-diff-linux-amd64 && sudo mv container-diff-linux-amd64 /usr/local/bin/container-diff"
    );
    assert_script_run("container-diff analyze daemon://$image_name --type=rpm > /tmp/container-diff.txt");
    upload_asset("/tmp/container-diff.txt");

    # Remove the image again to save space
    assert_script_run("docker image rm --force $image_name");
}

1;
