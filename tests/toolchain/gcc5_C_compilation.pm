# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: C toolchain module test
# Maintainer: Michal Nowak <mnowak@suse.com>

use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    my $self = shift;

    # Fixes https://github.com/linux-test-project/ltp/issues/91
    script_run 'wget ' . data_url('toolchain/794b46d9.patch');
    script_run 'wget ' . data_url('toolchain/ltp-full-20170116.tar.xz');
    script_run 'tar xJf ltp-full-20170116.tar.xz';

    # Some test cases do not play nicely with Btrfs. As we are testing
    # syscalls and not filesystem, workaroung involving Ext4 should be OK.
    assert_script_run 'dd if=/dev/zero of=/tmp/tmpdir.loop bs=1M count=512';
    assert_script_run 'mkfs.ext4 -F /tmp/tmpdir.loop';
    assert_script_run 'mkdir /tmp/tmpdir';
    assert_script_run 'mount /tmp/tmpdir.loop /tmp/tmpdir -o loop';

    script_run 'pushd ltp-full-20170116';
    # workaround for missing patch https://patchwork.kernel.org/patch/8953231/ in SLES 12 SP2
    # (https://github.com/linux-test-project/ltp/issues/89)
    script_run "cp /proc/sys/fs/inotify/max_user_instances ~; echo 512 > /proc/sys/fs/inotify/max_user_instances";
    assert_script_run './configure 2>&1 | tee /tmp/configure.log; if [ ${PIPESTATUS[0]} -ne 0 ]; then false; fi', 600;
    assert_script_run
'make -j$(getconf _NPROCESSORS_ONLN) all 2>&1 | tee /tmp/make_all.log; if [ ${PIPESTATUS[0]} -ne 0 ]; then false; fi',
      3600;
    assert_script_run 'make install 2>&1 | tee /tmp/make_install.log; if [ ${PIPESTATUS[0]} -ne 0 ]; then false; fi',
      600;
    script_run 'pushd /opt/ltp/';

    # gvfsd-trash running is probably causing https://github.com/linux-test-project/ltp/issues/92
    script_run "killall gvfsd-trash; sleep 5; pgrep gvfsd-trash && killall -9 gvfsd-trash";

    assert_script_run
      './runltp -f syscalls -d /tmp/tmpdir 2>&1 | tee /tmp/runltp.log; if [ ${PIPESTATUS[0]} -ne 0 ]; then false; fi',
      2000;
    save_screenshot;
    script_run 'popd';
    script_run 'popd';
    script_run 'cat ~/max_user_instances > /proc/sys/fs/inotify/max_user_instances';
}

sub test_flags() {
    return {important => 1};
}

sub post_fail_hook() {
    my $self = shift;

    script_run 'tar cvvfJ ltp-run-outputdir.tar.xz /opt/ltp/output/';
    upload_logs 'ltp-run-outputdir.tar.xz';
    upload_logs '/tmp/configure.log';
    upload_logs '/tmp/make_all.log';
    upload_logs '/tmp/make_install.log';
    upload_logs '/tmp/runltp.log';
    $self->export_logs();
    script_run 'cd';
    script_run 'umount /tmp/tmpdir';
}

1;
# vim: set sw=4 et:
