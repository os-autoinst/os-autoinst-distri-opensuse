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
use publiccloud::utils;
use publiccloud::ssh_interactive 'select_host_console';
use version_utils qw(is_sle is_sle_micro);

our $root_dir = '/root';

my $btrfs_binary = '/sbin/btrfs';
my $snapper_binary = 'snapper';

sub prepare_instance {
    my ($self, $args) = @_;
    unless ($args->{my_provider} && $args->{my_instance}) {
        $args->{my_provider} = $self->provider_factory();
        $args->{my_instance} = $args->{my_provider}->create_instance();
        $args->{my_instance}->wait_for_guestregister() if (is_ondemand());
    }
    return ($args->{my_provider}, $args->{my_instance});
}

sub register_instance {
    my ($self, $instance, $qam) = @_;
    registercloudguest($instance) if (is_byos() && !$qam);
}

sub test_btrfs_scrub {
    my ($self, $instance) = @_;

    $instance->ssh_assert_script_run(cmd => qq{sudo $btrfs_binary scrub start -B -R /});
    $instance->retry_ssh_command(cmd => qq{sudo $btrfs_binary scrub status / | grep -E "Status:\\s+finished"}, retry => 30, delay => 20, timeout => 600);
    $instance->ssh_assert_script_run(cmd => qq{sudo $btrfs_binary scrub status / | grep -E "Error summary:\\s+no errors found"});
}

sub print_snapper_list_configs {
    my ($self, $instance) = @_;
    record_info("snapper list-configs", $instance->ssh_script_output(cmd => qq{sudo $snapper_binary list-configs}));
}

sub print_snapper_list {
    my ($self, $instance) = @_;
    record_info("snapper list", $instance->ssh_script_output(cmd => qq{sudo $snapper_binary list}));
}

sub reboot_instance {
    my ($self, $instance) = @_;
    $instance->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600), scan_ssh_host_key => 1);
}

sub test_snapper_rollback {
    my ($self, $instance) = @_;

    my $rollback_test_file = "rollback_test_file";
    my $rollback_test_file_content = "rollback-test";

    if ($instance->ssh_script_run(
            cmd => qq{sudo $snapper_binary list-configs | grep -E "root\\s+| /"}
    ) != 0) {
        $instance->ssh_assert_script_run(cmd => qq{sudo umount /.snapshots});
        $instance->ssh_assert_script_run(cmd => qq{sudo rm -r /.snapshots});
        $instance->ssh_assert_script_run(cmd => qq{sudo $snapper_binary create-config /});
        reboot_instance($self, $instance);
    }

    print_snapper_list_configs($self, $instance);

    print_snapper_list($self, $instance);

    $instance->ssh_assert_script_run(cmd => qq{sudo $snapper_binary create -d "baseline snapshot"});
    print_snapper_list($self, $instance);

    $instance->ssh_assert_script_run(cmd => qq{echo "$rollback_test_file_content" | sudo tee /etc/$rollback_test_file});
    $instance->ssh_assert_script_run(cmd => qq{sudo $snapper_binary create -d "snapshot after change"});
    $instance->ssh_assert_script_run(cmd => qq{test -f /etc/$rollback_test_file});
    print_snapper_list($self, $instance);

    $instance->ssh_assert_script_run(cmd => qq{sudo $snapper_binary diff 2..3 | grep -- "--- /.snapshots/2/snapshot/etc/$rollback_test_file"});
    $instance->ssh_assert_script_run(cmd => qq{sudo $snapper_binary diff 2..3 | grep -- "+++ /.snapshots/3/snapshot/etc/$rollback_test_file"});
    $instance->ssh_assert_script_run(cmd => qq{sudo $snapper_binary diff 2..3 | grep -- "@@ -0,0 +1 @@"});
    $instance->ssh_assert_script_run(cmd => qq{sudo $snapper_binary diff 2..3 | grep -- "+$rollback_test_file_content"});

    $instance->ssh_assert_script_run(cmd => qq{sudo $snapper_binary rollback 2});
    print_snapper_list($self, $instance);

    reboot_instance($self, $instance);

    $instance->ssh_assert_script_run(cmd => qq{! test -f /etc/$rollback_test_file});
    print_snapper_list($self, $instance);

    $instance->ssh_assert_script_run(cmd => qq{sudo $snapper_binary delete 2-3});
    print_snapper_list($self, $instance);
}

sub test_snapper_undochange {
    my ($self, $instance) = @_;

    my $current_user = $instance->ssh_script_output(cmd => 'whoami');
    my $undochanges_test_file = "undochanges_test_file";
    my $undochanges_test_file_content = "undochanges-test";

    my $cfg_missing = $instance->ssh_script_run(
        cmd => qq{sudo $snapper_binary list-configs | grep -E "root\\s+| /home"}
    ) != 0;
    $instance->ssh_assert_script_run(cmd => qq{sudo $snapper_binary create-config /home}) if $cfg_missing;
    print_snapper_list_configs($self, $instance);

    print_snapper_list($self, $instance);

    $instance->ssh_assert_script_run(cmd => qq{sudo $snapper_binary create -d "baseline snapshot"});
    print_snapper_list($self, $instance);

    $instance->ssh_assert_script_run(cmd => qq{echo "$undochanges_test_file_content" > /home/$current_user/$undochanges_test_file});
    $instance->ssh_assert_script_run(cmd => qq{sudo $snapper_binary create -d "snapshot after change"});
    $instance->ssh_assert_script_run(cmd => qq{test -f /home/$current_user/$undochanges_test_file});
    print_snapper_list($self, $instance);

    $instance->ssh_assert_script_run(cmd => qq{sudo $snapper_binary diff 1..2 | grep -- "--- /home/.snapshots/1/snapshot/$current_user/$undochanges_test_file"});
    $instance->ssh_assert_script_run(cmd => qq{sudo $snapper_binary diff 1..2 | grep -- "+++ /home/.snapshots/2/snapshot/$current_user/$undochanges_test_file"});
    $instance->ssh_assert_script_run(cmd => qq{sudo $snapper_binary diff 1..2 | grep -- "@@ -0,0 +1 @@"});
    $instance->ssh_assert_script_run(cmd => qq{sudo $snapper_binary diff 1..2 | grep -- "+$undochanges_test_file_content"});
    $instance->ssh_assert_script_run(cmd => qq{sudo $snapper_binary undochange 1..2 | grep -- "create:0 modify:0 delete:1"});

    $instance->ssh_assert_script_run(cmd => qq{! test -f /home/$current_user/$undochanges_test_file});
    print_snapper_list($self, $instance);

    $instance->ssh_assert_script_run(cmd => qq{sudo $snapper_binary delete 1-2});
    print_snapper_list($self, $instance);

    $instance->ssh_assert_script_run(cmd => qq{sudo $snapper_binary delete-config});
    print_snapper_list_configs($self, $instance);
}

sub test_snapper {
    my ($self, $instance) = @_;

    kill_packagekit($instance) unless (is_sle_micro());
    zypper_install_remote($instance, "snapper");

    test_snapper_undochange($self, $instance);
    test_snapper_rollback($self, $instance);
}

sub run {
    my ($self, $args) = @_;
    my $qam = get_var("PUBLIC_CLOUD_QAM", 0);

    die "Test is only for SLE 16+" unless is_sle("16+");

    select_host_console();

    ($args->{my_provider}, $args->{my_instance}) = $self->prepare_instance($args);

    my $instance = $args->{my_instance};
    my $provider = $args->{my_provider};

    $self->register_instance($instance, $qam);

    test_btrfs_scrub($self, $instance);
    test_snapper($self, $instance);
}

1;
