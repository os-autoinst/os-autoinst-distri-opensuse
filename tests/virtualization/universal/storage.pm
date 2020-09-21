# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Storage pool / volume test
# Maintainer: Pavel Dostal <pdostal@suse.cz>, Felix Niederwanger <felix.niederwanger@suse.de>, Jan Baier <jbaier@suse.cz>

use base "virt_feature_test_base";
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;
use virt_utils;
use version_utils;

sub run_test {
    my ($self) = @_;

    record_info "Prepare";
    assert_script_run "mkdir -p /pool_testing";
    script_run "virsh pool-destroy testing";
    script_run "virsh vol-delete --pool testing $_-storage" foreach (keys %virt_autotest::common::guests);
    script_run "virsh vol-delete --pool testing $_-clone"   foreach (keys %virt_autotest::common::guests);
    script_run "virsh pool-undefine testing";
    # Ensure the new pool directory is empty
    script_run('rm -f /pool_testing/*');

    record_info "Pool define";
    assert_script_run "virsh pool-define-as testing dir - - - - '/pool_testing'";

    record_info "Pool list";
    assert_script_run "virsh pool-list --all | grep testing";

    record_info "Pool build";
    assert_script_run "virsh pool-build testing";

    record_info "Pool start";
    assert_script_run "virsh pool-start testing";

    record_info "Pool autostart";
    assert_script_run "virsh pool-autostart testing";

    record_info "Pool info";
    assert_script_run "virsh pool-info testing";

    record_info "Create";
    assert_script_run("virsh vol-create-as testing $_-storage 100M", 120) foreach (keys %virt_autotest::common::guests);

    record_info "Listing";
    assert_script_run("ls /pool_testing/",                        120) foreach (keys %virt_autotest::common::guests);
    assert_script_run("virsh vol-list testing | grep $_-storage", 120) foreach (keys %virt_autotest::common::guests);

    record_info "Info";
    assert_script_run("virsh vol-info --pool testing $_-storage", 120) foreach (keys %virt_autotest::common::guests);

    record_info "Dump XML";
    assert_script_run("virsh vol-dumpxml --pool testing $_-storage", 120) foreach (keys %virt_autotest::common::guests);

    record_info "Resize";
    assert_script_run("virsh vol-resize --pool testing $_-storage 200M", 120) foreach (keys %virt_autotest::common::guests);

    record_info "Attached";
    my $target = (is_xen_host) ? "xvdx" : "vdx";
    assert_script_run("virsh attach-disk --domain $_ --source `virsh vol-path --pool testing $_-storage` --target $target", 120) foreach (keys %virt_autotest::common::guests);
    assert_script_run("virsh detach-disk $_ $target", 120) foreach (keys %virt_autotest::common::guests);

    record_info "Clone";
    assert_script_run("virsh vol-clone --pool testing $_-storage $_-clone", 120) foreach (keys %virt_autotest::common::guests);
    assert_script_run("virsh vol-info --pool testing $_-clone",             120) foreach (keys %virt_autotest::common::guests);

    record_info "Remove";
    assert_script_run("virsh vol-delete --pool testing $_-clone",   120) foreach (keys %virt_autotest::common::guests);
    assert_script_run("virsh vol-delete --pool testing $_-storage", 120) foreach (keys %virt_autotest::common::guests);

    record_info "Pool destroy";
    assert_script_run "virsh pool-destroy testing";
    assert_script_run "virsh pool-delete testing";
    assert_script_run "virsh pool-undefine testing";
}

1;
