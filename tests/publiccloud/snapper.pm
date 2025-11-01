# SUSE's openQA tests
#
# Copyright SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test snapper on SLE 16+
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use utils;
use serial_terminal qw(select_serial_terminal);
use version_utils qw(is_sle_micro);

our $root_dir = '/root';

my $snapper_binary = 'snapper';

sub print_snapper_list_configs {
    my ($self) = @_;
    record_info("SNAP LISTC", script_output(qq{$snapper_binary list-configs}));
}

sub print_snapper_list {
    my ($self) = @_;
    record_info("SNAPPER LIST", script_output(qq{$snapper_binary list}));
}

sub reboot_instance {
    my ($self, $instance) = @_;
    $instance->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600));
}

sub snapper_last_id {
    my ($self) = @_;

    my $ret = script_output(qq{$snapper_binary list | awk 'NR>2 {print \$1}' | tail -n1});

    return $ret;
}

sub test_snapper_rollback {
    my ($self, $instance) = @_;

    record_info("ROLLBACK", "Testing snapper rollback");

    my $rollback_test_file = "rollback_test_file";
    my $rollback_test_file_content = "rollback-test";

    assert_script_run(qq{umount /.snapshots});
    assert_script_run(qq{rm -r /.snapshots});
    assert_script_run(qq{$snapper_binary create-config /});
    $self->reboot_instance($instance);

    $self->print_snapper_list_configs();
    $self->print_snapper_list();

    assert_script_run(qq{$snapper_binary create -d "baseline snapshot"});
    my $base = $self->snapper_last_id();
    record_info("BASE", "snapshot id: $base");
    $self->print_snapper_list();

    assert_script_run(qq{echo "$rollback_test_file_content" | tee /etc/$rollback_test_file});
    record_info("FILE", script_output(qq{cat /etc/$rollback_test_file}));
    assert_script_run(qq{$snapper_binary create -d "snapshot after change"});
    assert_script_run(qq{test -f /etc/$rollback_test_file});
    my $after = $self->snapper_last_id();
    record_info("AFTER", "snapshot id: $after");
    $self->print_snapper_list();

    assert_script_run(qq{$snapper_binary diff $base..$after | grep -- "--- /.snapshots/$base/snapshot/etc/$rollback_test_file"});
    assert_script_run(qq{$snapper_binary diff $base..$after | grep -- "+++ /.snapshots/$after/snapshot/etc/$rollback_test_file"});
    assert_script_run(qq{$snapper_binary diff $base..$after | grep -- "@@ -0,0 +1 @@"});
    assert_script_run(qq{$snapper_binary diff $base..$after | grep -- "+$rollback_test_file_content"});

    assert_script_run(qq{$snapper_binary rollback $base});
    $self->print_snapper_list();

    $self->reboot_instance($instance);

    assert_script_run(qq{! test -f /etc/$rollback_test_file});
    $self->print_snapper_list();

    assert_script_run(qq{$snapper_binary delete $base-$after});
    $self->print_snapper_list();
}

sub test_snapper_undochange {
    my ($self) = @_;

    record_info("UNDOCHANGE", "Testing snapper undochange");

    my $undochanges_test_file = "undochanges_test_file";
    my $undochanges_test_file_content = "undochanges-test";
    my $undochanges_test_file_path = "/root/$undochanges_test_file";

    assert_script_run(qq{$snapper_binary create-config /root});
    $self->print_snapper_list_configs();
    $self->print_snapper_list();

    assert_script_run(qq{$snapper_binary create -d "baseline snapshot"});
    my $base = $self->snapper_last_id();
    record_info("BASE", "snapshot id: $base");
    $self->print_snapper_list();

    assert_script_run(qq{echo "$undochanges_test_file_content" > $undochanges_test_file_path});
    record_info("FILE", script_output(qq{cat $undochanges_test_file_path}));
    assert_script_run(qq{$snapper_binary create -d "snapshot after change"});
    assert_script_run(qq{test -f $undochanges_test_file_path});
    my $after = $self->snapper_last_id();
    record_info("AFTER", "snapshot id: $after");
    $self->print_snapper_list();

    my $previous_snapshot_path = "/root/.snapshots/$base/snapshot/$undochanges_test_file";
    my $next_snapshot_path = "/root/.snapshots/$after/snapshot/$undochanges_test_file";

    assert_script_run(qq{$snapper_binary diff $base..$after | grep -- "--- $previous_snapshot_path"});
    assert_script_run(qq{$snapper_binary diff $base..$after | grep -- "+++ $next_snapshot_path"});
    assert_script_run(qq{$snapper_binary diff $base..$after | grep -- "@@ -0,0 +1 @@"});
    assert_script_run(qq{$snapper_binary diff $base..$after | grep -- "+$undochanges_test_file_content"});

    assert_script_run(qq{$snapper_binary undochange $base..$after | grep -- "create:0 modify:0 delete:1"});

    assert_script_run(qq{! test -f $undochanges_test_file_path});
    $self->print_snapper_list();

    assert_script_run(qq{$snapper_binary delete $base-$after});
    $self->print_snapper_list();

    assert_script_run(qq{$snapper_binary delete-config});
    $self->print_snapper_list_configs();
}

sub run {
    my ($self, $args) = @_;

    select_serial_terminal();

    my $instance = $args->{my_instance};

    quit_packagekit() unless (is_sle_micro());
    zypper_call("in snapper");

    $self->test_snapper_undochange();
    $self->test_snapper_rollback($instance);
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

1;
