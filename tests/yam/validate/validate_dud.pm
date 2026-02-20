# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that a simple test DUD passed by kernel cmd-line parameter was installed and can be executed.
# Check DUD functionality by boot option "inst.dud="
# See https://agama-project.github.io/docs/user/boot_options

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'Yam::Agama::agama_base';
use testapi;

sub run {
    select_console 'root-console';
    # See https://build.opensuse.org/package/show/home:lslezak:dud-test/hello-world
    validate_script_output("hello-world.sh", qr/Hello world!/);

    my $agama_output = script_output("journalctl -u agama-autoinstall");
    if ($agama_output =~ /Configuration\sloaded\sfrom\sfile\:\/\/\/autoinst\.json/ms) {
        diag "DUD profile loaded successfully";
    } else {
        die "Error, JSON profile in DUD file not loaded";
    }

    my $kernel_dud_output = script_output("journalctl -u dracut-pre-pivot");
    if ($kernel_dud_output =~ /Unloading kernel module .+?nfs\.ko/) {
        diag "Kernel module DUD applied successfully";
    } else {
        die "Error, kernel module DUD not loaded";
    }
}

1;
