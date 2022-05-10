# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# All of cases is based on the reference:
# https://www.suse.com/documentation/sles-15/singlehtml/book_sle_admin/book_sle_admin.html#id-1.3.3.6.13.6.21
#
# Package: nfs-client yast2-nfs-client nfs-kernel-server yast2-nfs-server
# Summary: setup a nfs client
#     Key Steps:
#       - sets up a nfs service on localhost
#       - adds, edits and deletes a mount point
#       - restores all configs
# Maintainer: Jun Wang <jgwang@suse.com>

use base 'y2_module_basetest';
use strict;
use warnings;
use testapi;
use utils qw(systemctl zypper_call);
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    zypper_call("in nfs-client yast2-nfs-client nfs-kernel-server yast2-nfs-server", exitcode => [0, 102, 103, 106]);

    # sets up a nfs service on localhost
    my $servdir = script_output('mktemp -d');
    assert_script_run("yast nfs-server start; yast nfs-server add mountpoint=$servdir");

    my $tmpdir01 = script_output('mktemp -d');
    my $tmpdir02 = script_output('mktemp -d');

    # adds,edits and deletes a mount point and verify
    assert_script_run("yast nfs add spec=localhost:$servdir file=$tmpdir01");
    validate_script_output('yast nfs list 2>&1', sub { m%$tmpdir01% }, timeout => 90, proceed_on_failure => 1);
    # nfs.service will run "mount -at nfs,nfs4" to mount all points on SLE12SP2~SP4, but NOT on SLE15+
    if (is_sle('<15')) {
        validate_script_output('cat /proc/mounts', sub { m%$tmpdir01% });
    } elsif (is_sle('15+')) {
        validate_script_output('mount -at nfs,nfs4; cat /proc/mounts', sub { m%$tmpdir01% });
    }

    assert_script_run("yast nfs edit spec=localhost:$servdir file=$tmpdir02");
    validate_script_output('yast nfs list 2>&1', sub { m%$tmpdir02% }, timeout => 90, proceed_on_failure => 1);
    if (is_sle('<15')) {
        validate_script_output('cat /proc/mounts', sub { m%$tmpdir02% and (!m%$tmpdir01%) });
    } elsif (is_sle('15+')) {
        validate_script_output('mount -at nfs,nfs4; cat /proc/mounts', sub { m%$tmpdir02% and (!m%$tmpdir01%) });
    }

    assert_script_run("yast nfs delete spec=localhost:$servdir");
    validate_script_output('yast nfs list 2>&1', sub { !m%$tmpdir02% }, timeout => 90, proceed_on_failure => 1);
    if (is_sle('<15')) {
        validate_script_output('cat /proc/mounts', sub { !m%$tmpdir02% });
    } elsif (is_sle('15+')) {
        validate_script_output('mount -at nfs,nfs4; cat /proc/mounts', sub { !m%$tmpdir02% });
    }

    # restores all configs
    assert_script_run("yast nfs-server delete mountpoint=$servdir; yast nfs-server stop");
    assert_script_run("rm -fr $tmpdir01 $tmpdir02 $servdir");
}

1;
