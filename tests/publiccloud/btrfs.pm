# SUSE's openQA tests
#
# Copyright SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test BTRFS filesystem on SLE 16+
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use utils;
use serial_terminal qw(select_serial_terminal);
use version_utils qw(is_sle is_sle_micro);

our $root_dir = '/root';

my $btrfs_binary = '/sbin/btrfs';
my $snapper_binary = 'snapper';

sub test_btrfs_scrub {
    my ($self) = @_;

    record_info("BTRFS", "Testing btrfs scrub");

    assert_script_run(qq{$btrfs_binary scrub start -B -R /});
    script_retry(qq{$btrfs_binary scrub status / | grep -E "Status:\\s+finished"}, retry => 30, delay => 20, timeout => 600);
    assert_script_run(qq{$btrfs_binary scrub status / | grep -E "Error summary:\\s+no errors found"});
}

sub print_snapper_list_configs {
    my ($self) = @_;
    record_info("snapper list-configs", script_output(qq{$snapper_binary list-configs}));
}

sub print_snapper_list {
    my ($self) = @_;
    record_info("snapper list", script_output(qq{$snapper_binary list}));
}

sub reboot_instance {
    my ($self, $instance) = @_;
    $instance->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600), scan_ssh_host_key => 1);
}

sub test_snapper_rollback {
    my ($self, $instance) = @_;

    record_info("ROLLBACK", "Testing snapper rollback");

    my $rollback_test_file = "rollback_test_file";
    my $rollback_test_file_content = "rollback-test";

    if (script_run(qq{$snapper_binary list-configs | grep -E "root\\s+| /"}) != 0) {
        assert_script_run(qq{umount /.snapshots});
        assert_script_run(qq{rm -r /.snapshots});
        assert_script_run(qq{$snapper_binary create-config /});
        $self->reboot_instance($instance);
    }

    $self->print_snapper_list_configs();

    $self->print_snapper_list();

    assert_script_run(qq{$snapper_binary create -d "baseline snapshot"});
    $self->print_snapper_list();

    assert_script_run(qq{echo "$rollback_test_file_content" | tee /etc/$rollback_test_file});
    record_info("FILE", script_output(qq{cat /etc/$rollback_test_file}));
    assert_script_run(qq{$snapper_binary create -d "snapshot after change"});
    assert_script_run(qq{test -f /etc/$rollback_test_file});
    $self->print_snapper_list();

    assert_script_run(qq{$snapper_binary diff 2..3 | grep -- "--- /.snapshots/2/snapshot/etc/$rollback_test_file"});
    assert_script_run(qq{$snapper_binary diff 2..3 | grep -- "+++ /.snapshots/3/snapshot/etc/$rollback_test_file"});
    assert_script_run(qq{$snapper_binary diff 2..3 | grep -- "@@ -0,0 +1 @@"});
    assert_script_run(qq{$snapper_binary diff 2..3 | grep -- "+$rollback_test_file_content"});

    assert_script_run(qq{$snapper_binary rollback 2});
    $self->print_snapper_list();

    $self->reboot_instance($instance);

    assert_script_run(qq{! test -f /etc/$rollback_test_file});
    $self->print_snapper_list();

    assert_script_run(qq{$snapper_binary delete 2-3});
    $self->print_snapper_list();
}

sub test_snapper_undochange {
    my ($self) = @_;

    record_info("UNDOCHANGE", "Testing snapper undochange");

    my $undochanges_test_file = "undochanges_test_file";
    my $undochanges_test_file_content = "undochanges-test";

    my $undochanges_test_file_path = "/root/$undochanges_test_file";

    my $cfg_missing = script_run(qq{$snapper_binary list-configs | grep -E "root\\s+| /root"}) != 0;
    assert_script_run(qq{$snapper_binary create-config /root}) if $cfg_missing;
    $self->print_snapper_list_configs();

    $self->print_snapper_list();

    assert_script_run(qq{$snapper_binary create -d "baseline snapshot"});
    $self->print_snapper_list();

    assert_script_run(qq{echo "$undochanges_test_file_content" > $undochanges_test_file_path});
    record_info("FILE", script_output(qq{cat $undochanges_test_file_path}));
    assert_script_run(qq{$snapper_binary create -d "snapshot after change"});
    assert_script_run(qq{test -f $undochanges_test_file_path});
    $self->print_snapper_list();

    my $previous_snapshot_path = "/root/.snapshots/1/snapshot/$undochanges_test_file";
    my $next_snapshot_path = "/root/.snapshots/2/snapshot/$undochanges_test_file";
    assert_script_run(qq{$snapper_binary diff 1..2 | grep -- "--- $previous_snapshot_path"});
    assert_script_run(qq{$snapper_binary diff 1..2 | grep -- "+++ $next_snapshot_path"});
    assert_script_run(qq{$snapper_binary diff 1..2 | grep -- "@@ -0,0 +1 @@"});
    assert_script_run(qq{$snapper_binary diff 1..2 | grep -- "+$undochanges_test_file_content"});
    assert_script_run(qq{$snapper_binary undochange 1..2 | grep -- "create:0 modify:0 delete:1"});

    assert_script_run(qq{! test -f $undochanges_test_file_path});
    $self->print_snapper_list();

    assert_script_run(qq{$snapper_binary delete 1-2});
    $self->print_snapper_list();

    assert_script_run(qq{$snapper_binary delete-config});
    $self->print_snapper_list_configs();
}

sub test_snapper {
    my ($self, $instance) = @_;

    quit_packagekit() unless (is_sle_micro());
    zypper_call("in snapper policycoreutils-python-utils");

    assert_script_run(qq{semanage permissive -a snapperd_t});
    record_soft_failure("bsc#1251801 snapperd is not working properly with SELinux enforcing");

    $self->test_snapper_undochange();
    $self->test_snapper_rollback($instance);

    assert_script_run(qq{semanage permissive -d snapperd_t});
    record_soft_failure("bsc#1251801 snapperd is not working properly with SELinux enforcing");
}

sub run {
    my ($self, $args) = @_;
    die "Test is only for SLE 16+" unless is_sle("16+");

    select_serial_terminal();

    $self->test_btrfs_scrub();
    $self->test_snapper($args->{my_instance});
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

1;
