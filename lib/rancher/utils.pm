# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic functionality for testing rancher container
# Maintainer: George Gkioulis <ggkioulis@suse.com>

package rancher::utils;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use utils;
use version_utils;

our @EXPORT = qw(setup_rancher_container);

sub setup_rancher_container {
    my %args    = @_;
    my $runtime = $args{runtime};
    die "You must define the runtime!" unless $runtime;

    assert_script_run("$runtime pull docker.io/rancher/rancher:latest", timeout => 600);
    assert_script_run("$runtime run --name rancher_webui --privileged -d --restart=unless-stopped -p 80:80 -p 443:443 rancher/rancher");

    # Check every 30 seconds that the cluster is setup. Times out after 20 minutes
    script_retry("$runtime logs rancher_webui 2>&1 |grep 'Starting networking.k8s.io'", delay => 30, retry => 40);

    assert_script_run("curl -k https://localhost");
    record_info("Rancher UI ready");
}

1;
