# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test rootless mode on podman.
# - add a user on the /etc/subuid and /etc/subgid to allow automatically allocation subuid and subgid ranges.
# - check uids allocated to user (inside the container are mapped on the host)
# - give read access to the SUSE Customer Center credentials to call zypper from in the container.
#   This grants the current user the required access rights
# - Test rootless container:
#   * container is launched with default root user
#   * container is launched with existing user id
#   * container is launched with keep-id of the user who run the container
# - Restore /etc/zypp/credentials.d/ credentials
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use utils;
use containers::common;
use containers::container_images;
use containers::urls 'get_suse_container_urls';
use version_utils qw(get_os_release);
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    my ($image_names, $stable_names) = get_suse_container_urls();
    my ($running_version, $sp, $host_distri) = get_os_release;
    my $podman = containers::runtime->new(engine => 'podman');

    install_podman_when_needed($host_distri);
    allow_selected_insecure_registries($podman);
    my $user         = $testapi::username;
    my $subuid_start = get_user_subuid($user);
    if ($subuid_start eq '') {
        record_soft_failure 'bsc#1179261 - YaST creates incomplete user accounts';
        $subuid_start = 200000;
        my $subuid_range = $subuid_start + 1000;
        assert_script_run "usermod --add-subuids $subuid_start-$subuid_range --add-subgids $subuid_start-$subuid_range $user";
    }
    assert_script_run "grep $user /etc/subuid", fail_message => "subuid range not assigned for $user";
    assert_script_run "grep $user /etc/subgid", fail_message => "subgid range not assigned for $user";
    assert_script_run "setfacl -m u:$user:r /etc/zypp/credentials.d/*" if is_sle;
    ensure_serialdev_permissions;
    select_console "user-console";

    # smoke test
    $podman->_rt_assert_script_run("images -a");
    for my $iname (@{$image_names}) {
        test_container_image($podman, image => $iname);
        build_container_image($podman, $iname);
        test_zypper_on_container($podman, $iname);
        verify_userid_on_container($podman, $iname, $subuid_start);
    }
    $podman->cleanup_system_host();
}

sub get_user_subuid {
    my ($user) = shift;
    my $start_range = script_output("awk -F':' '\$1 == \"$user\" {print \$2}' /etc/subuid",
        proceed_on_failure => 1);
    return $start_range;
}

sub post_run_hook {
    my $self = shift;
    $self->select_serial_terminal();
    assert_script_run "setfacl -x u:$testapi::username /etc/zypp/credentials.d/*" if is_sle;
    $self->SUPER::post_run_hook;
}

sub post_fail_hook {
    my $self = shift;
    $self->save_and_upload_log('cat /etc/{subuid,subgid}', "/tmp/permissions.txt");
    assert_script_run("tar -capf /tmp/proc_files.tar.xz /proc/self");
    upload_logs("/tmp/proc_files.tar.xz");
    if (is_sle) {
        $self->save_and_upload_log('ls -la /etc/zypp/credentials.d', "/tmp/credentials.d.perm.txt");
        assert_script_run "setfacl -x u:$testapi::username /etc/zypp/credentials.d/*";
    }
}

1;
