# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Close the gap between a bare SLE 16.0 MinimalVM image and what
# publiccloud/prepare_tools expects to find on the tools image. On 15-SP7 that
# baseline comes from the AutoYaST profile data/autoyast_sle15/pc_tools.xml,
# which a MinimalVM qcow2 obviously never ran. PoC for poo#206526.
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call systemctl);
use publiccloud::utils qw(get_python_exec);

# The pc_tools.xml package list, translated to SLE 16 names. python311-* became
# python313-*, and ntp is chrony now. Kept in the profile's order so the two can
# be diffed by eye.
my @packages = qw(
  netcat-openbsd git-core chrony gcc sudo wget haveged
  python313-pip python313-devel python313-pytest
  podman docker jq rsync unzip
);

sub run {
    select_serial_terminal;

    # A MinimalVM image is unregistered and has no repos, so everything below
    # depends on this being set.
    if (my $repos = get_var('PUBLIC_CLOUD_BASE_REPO')) {
        zypper_call("ar --refresh $_") for (split(/\s+/, $repos));
    }
    zypper_call('--gpg-auto-import-keys ref');

    # Install one by one: on a PoC the interesting output is *which* of these
    # the 16.0 repos cannot give us, and a single zypper call would stop at the
    # first one.
    my @missing;
    for my $pkg (@packages) {
        push @missing, $pkg if zypper_call("in $pkg", exitcode => [0, 104], timeout => 600) == 104;
    }
    record_info('missing', join("\n", @missing) || 'none', result => @missing ? 'fail' : 'ok');

    my $python_exec = get_python_exec();
    record_info('python', script_output("$python_exec --version; $python_exec -m pip --version"));

    # prepare_tools asserts on both of these straight after the img-proof step.
    systemctl('enable --now docker');
    assert_script_run('podman ps');
    assert_script_run('docker ps');
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
