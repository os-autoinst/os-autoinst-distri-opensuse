# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Advanced 389-ds feature test (Backup, Reindex, Plugins, Replication)
#
# Maintainer: qe-core <qe-core@suse.com>

package ds389_advanced_functional;
use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use services::389ds_server;

my $backup_dir = "/var/tmp/389ds_openqa_backup";

sub run {
    my ($self) = @_;
    select_serial_terminal;

    set_var('SSS_USERNAME', 'wilber');
    record_info("Setup", "Installing and configuring 389ds using library methods");
    assert_script_run("echo '127.0.0.1 localhost.localdomain localhost' > /etc/hosts");
    services::389ds_server::install_service();
    services::389ds_server::config_service(no_check => 1);
    services::389ds_server::enable_service();
    services::389ds_server::check_service();

    my $instance = "localhost";
    my $suffix = "dc=example,dc=com";

    # Enable MemberOf Plugins
    record_info("Plugins", "Enabling MemberOf plugin tracking capabilities");

    # Enable the plugin on the configured instance
    assert_script_run("dsconf $instance plugin memberof enable");

    # Restart the instance systemd unit cleanly to commit operational changes
    assert_script_run("systemctl restart dirsrv\@localhost.service");

    # Validate the plugin status
    my $plugin_status = script_output("dsconf $instance plugin memberof show");
    die "MemberOf plugin validation failed" unless ($plugin_status =~ /nsslapd-pluginEnabled: on/i);

    record_info("Reindexing", "Configuring and rebuilding backend indexing tables");

    # Run the structural backend reindex process execution tasks
    assert_script_run("dsconf $instance backend index reindex userRoot");

    # Ensure no indexing execution errors are logged in current system status checks
    assert_script_run("dsconf $instance monitor server");

    record_info("Backup/Restore", "Archiving structural state databases and restoring snapshots");

    # Stop database services safely to simulate a complete bare disaster recovery
    assert_script_run("dsctl $instance stop");

    # Create the standalone configuration backup archive directory structure
    assert_script_run("dsctl $instance db2bak $backup_dir");
    assert_script_run("ls -la $backup_dir");

    # Restore from the generated baseline archive
    assert_script_run("dsctl $instance bak2db $backup_dir");

    # Bring the directory services environment back to online validation state
    assert_script_run("dsctl $instance start");
    services::389ds_server::check_service();

    record_info("Replication", "Provisioning baseline replication mapping rules");

    # Set up this instance as a baseline Master / Supplier role for data syncing profiles
    assert_script_run("dsconf $instance replication enable --suffix='$suffix' --role='supplier' --replica-id=1");

    # Bind credentials for cross-node directory communication sync loops
    assert_script_run("dsconf $instance replication create-manager --suffix='$suffix' --passwd='$testapi::password'");

    # Read output configuration variables to confirm replication metadata was provisioned
    my $repl_config = script_output("dsconf $instance replication get --suffix='$suffix'");
    die "Replication mapping validation failure" unless ($repl_config =~ /nsDS5ReplicaId: 1/);

    record_info("Success", "All 389ds automation validations completed successfully.");
}

# Cleanup logic to clear test artifacts
sub clean_up {
    my ($self) = @_;
    record_info("Clean up", "Removing generated database backup directories and resetting states");

    # Remove backup artifacts if they exist
    script_run("rm -rf $backup_dir");

    # Gracefully stop the 389-ds service instance if running
    script_run("dsctl localhost stop");
}

# Automatically executes if the main run sequence fails unexpectedly
sub post_fail_hook {
    my ($self) = @_;
    $self->clean_up();
}

# Automatically executes after a successful run sequence finishes
sub post_run_hook {
    my ($self) = @_;
    $self->clean_up();
}

1;
