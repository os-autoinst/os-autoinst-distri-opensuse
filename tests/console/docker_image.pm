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

    my @image_names = ();
    if (is_sle("=12-SP3")) {
        my @suffixes = ("container/sles12:sp3", "container-next/sles12/caasp-dex:2.7.1", "container-next/sles12/chartmuseum:0.2.8", "container-next/sles12/dnsmasq-nanny:1.0.0", "container-next/sles12/flannel:0.9.1", "container-next/sles12/haproxy:1.6.0", "container-next/sles12/kubedns:1.0.0", "container-next/sles12/mariadb:10.0", "container-next/sles12/openldap:10.0", "container-next/sles12/pause:1.0.0", "container-next/sles12/portus:2.3.2", "container-next/sles12/pv-recycler-node:1.0.0", "container-next/sles12/salt-api:2016.11.4", "container-next/sles12/salt-master:2016.11.4", "container-next/sles12/salt-minion:2016.11.4", "container-next/sles12/sidecar:1.0.0", "container-next/sles12/tiller:2.8.2", "container-next/sles12/velum:0.0");
        foreach my $suffix (@suffixes) {
            push @image_names, "registry.suse.de/suse/sle-12-sp3/update/products/casp30/$suffix";
        }
    }
    elsif (is_sle("=15")) {
        push @image_names, "registry.suse.de/suse/sle-15/update/cr/images/suse/sle15:current";
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

    assert_script_run(
        "curl -LO https://storage.googleapis.com/container-diff/latest/container-diff-linux-amd64 &&
        chmod +x container-diff-linux-amd64 && sudo mv container-diff-linux-amd64 /usr/local/bin/container-diff"
    );

    foreach my $image_name (@image_names) {
        # Load the image
        assert_script_run("docker pull $image_name", 120);
        # Running executables works
        assert_script_run qq{docker container run --entrypoint '/bin/bash' --rm $image_name -c 'echo "I work" | grep "I work"'};
        # It is the right SLE version
        if (is_sle("=12-SP3")) {
            validate_script_output("docker container run --entrypoint '/bin/bash' --rm $image_name -c 'cat /etc/os-release'", sub { /PRETTY_NAME="SUSE Linux Enterprise Server 12 SP3"/ });
        }
        elsif (is_sle("=15")) {
            validate_script_output("docker container run --entrypoint '/bin/bash' --rm $image_name -c 'cat /etc/os-release'", sub { /PRETTY_NAME="SUSE Linux Enterprise Server 15"/ });
        }
        # zypper lr
        assert_script_run("docker container run --entrypoint '/bin/bash' --rm $image_name -c 'zypper lr -s'");
        # zypper ref
        assert_script_run qq{docker container run --entrypoint '/bin/bash' --rm $image_name -c 'zypper -v ref | grep "All repositories have been refreshed"'};

        # container-diff
        my $image_file = $image_name =~ s/\/|:/-/gr;
        assert_script_run("container-diff analyze daemon://$image_name --type=rpm > /tmp/container-diff-$image_file.txt");
        upload_asset("/tmp/container-diff-$image_file.txt");

        # Remove the image again to save space
        assert_script_run("docker image rm --force $image_name");
    }
}

1;
