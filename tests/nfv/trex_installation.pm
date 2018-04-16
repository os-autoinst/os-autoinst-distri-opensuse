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
use serial_terminal 'select_virtio_console';

sub run {
    my $trex_version = get_required_var('TG_VERSION');
    my $tarball      = "$trex_version.tar.gz";
    my $url          = "http://trex-tgn.cisco.com/trex/release/$tarball";
    my $trex_dest    = "/tmp/trex-core";

    select_virtio_console();

    assert_script_run("wget $url");
    assert_script_run("tar -xzf $tarball");
    assert_script_run("mv $trex_version $trex_dest");

    # Copy sample config file to default localtion
    assert_script_run("cp $trex_dest/cfg/simple_cfg.yaml /etc/trex_cfg.yaml");
}

1;
