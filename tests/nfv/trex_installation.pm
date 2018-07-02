# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Trex traffic generator installation
#
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "opensusebasetest";
use testapi;
use strict;
use utils;
use mmapi;

sub run {
    select_console 'root-ssh';

    my $trex_version = get_required_var('TG_VERSION');
    my $tarball      = "$trex_version.tar.gz";
    my $url          = "http://trex-tgn.cisco.com/trex/release/$tarball";
    my $trex_dest    = "/tmp/trex-core";
    my $trex_conf    = "/etc/trex_cfg.yaml";
    my $PORT_1       = get_required_var('PORT_1');
    my $PORT_2       = get_required_var('PORT_2');

    # Download and extract T-Rex package
    assert_script_run("wget $url", 900);
    assert_script_run("tar -xzf $tarball");
    assert_script_run("mv $trex_version $trex_dest");

    # Copy config file and replace port values
    assert_script_run("curl " . data_url('nfv/trex_cfg.yaml') . " -o $trex_conf");
    assert_script_run("sed -i 's/PORT_0/$PORT_1/' -i $trex_conf");
    assert_script_run("sed -i 's/PORT_1/$PORT_2/' -i $trex_conf");
    assert_script_run("cat $trex_conf");

    # Start daemon
    assert_script_run("cd $trex_dest");
    assert_script_run("./trex_daemon_server start");
}

1;

