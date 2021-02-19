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
# - give read access to the SUSE Customer Center credentials to call zypper from in the container
#   proper way to add Access Control List is via `setfacl` which is not available so we just do
#   `chmod` instead!! This grants the current user the required access rights
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
use suse_container_urls 'get_suse_container_urls';
use version_utils qw(get_os_release);
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    my ($image_names, $stable_names) = get_suse_container_urls();
    my ($running_version, $sp, $host_distri) = get_os_release;
    my $runtime = "podman";

    install_podman_when_needed($host_distri);
    allow_selected_insecure_registries(runtime => $runtime);
    my $user      = $testapi::username;
    my $check_msg = 'Checking allocation range of user';
    script_run "grep $user /etc/subuid || echo /etc/subuid has no uid range for $user", output => $check_msg;
    script_run "grep $user /etc/subgid || echo /etc/subgid has no gid range for $user", output => $check_msg;
    assert_script_run "usermod --add-subuids 200000-201000 --add-subgids 200000-201000 $user";
    assert_script_run "grep $user /etc/subuid", fail_message => "subuid range not assigned for $user";
    assert_script_run "grep $user /etc/subgid", fail_message => "subgid range not assigned for $user";
    # Workaround instead of
    # "setfacl -m u:$user:r /etc/zypp/credentials.d/*"
    assert_script_run "chmod -R 666 /etc/zypp/credentials.d/*" if is_sle;
    ensure_serialdev_permissions;
    select_console "user-console";

    # smoke test
    assert_script_run "$runtime images -a";
    for my $iname (@{$image_names}) {
        test_container_image(image => $iname, runtime => $runtime);
        build_container_image(image => $iname, runtime => $runtime);
        test_zypper_on_container($runtime, $iname);
        verify_userid_on_container($runtime, $iname);
    }
    clean_container_host(runtime => $runtime);
    $self->select_serial_terminal();
    assert_script_run "chmod -R 600 /etc/zypp/credentials.d/*" if is_sle;
}

1;
