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
use containers::utils 'registry_url';
use version_utils qw(get_os_release);
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    my ($untested_images, $released_images) = get_suse_container_urls();
    my ($running_version, $sp, $host_distri) = get_os_release;
    my $runtime = "podman";

    install_podman_when_needed($host_distri);
    allow_selected_insecure_registries(runtime => $runtime);
    my $user         = $testapi::username;
    my $subuid_start = get_user_subuid($user);
    if ($subuid_start eq '') {
        record_soft_failure 'bsc#1185342 - YaST does not set up subuids/-gids for users';
        $subuid_start = 200000;
        my $subuid_range = $subuid_start + 1000;
        assert_script_run "usermod --add-subuids $subuid_start-$subuid_range --add-subgids $subuid_start-$subuid_range $user";
    }
    assert_script_run "grep $user /etc/subuid", fail_message => "subuid range not assigned for $user";
    assert_script_run "grep $user /etc/subgid", fail_message => "subgid range not assigned for $user";
    assert_script_run "setfacl -m u:$user:r /etc/zypp/credentials.d/*" if is_sle;
    ensure_serialdev_permissions;
    select_console "user-console";

    return if softfail_and_skip_on_bsc1182874();

    for my $iname (@{$released_images}) {
        test_container_image(image => $iname, runtime => $runtime);
        build_and_run_image(base => $iname, runtime => $runtime);
        test_zypper_on_container($runtime, $iname);
        verify_userid_on_container($runtime, $iname, $subuid_start);
    }
    clean_container_host(runtime => $runtime);
}

sub softfail_and_skip_on_bsc1182874 {
    my $alpine = registry_url('alpine');
    if (script_run("podman run $alpine", timeout => 180) != 0) {
        record_soft_failure "bsc#1182874 - container fails to run in rootless mode";
        return 1;
    }
    return 0;
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
    $self->SUPER::post_fail_hook;
}

1;
