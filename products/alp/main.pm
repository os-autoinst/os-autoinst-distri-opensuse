use strict;
use warnings;
use needle;
use File::Basename;
use scheduler 'load_yaml_schedule';
BEGIN {
    unshift @INC, dirname(__FILE__) . '/../../lib';
}
use utils;
use testapi;
use main_common;
use main_containers qw(load_container_tests is_container_test);
use version_utils qw(is_transactional);
use Utils::Architectures qw(is_s390x);

init_main();

my $distri = testapi::get_required_var('CASEDIR') . '/lib/susedistribution.pm';
require $distri;
testapi::set_distribution(susedistribution->new());


sub load_boot_from_disk_tests {
    if (is_s390x()) {
        loadtest 'installation/bootloader_start';
        loadtest 'boot/boot_to_desktop';
    } else {
        loadtest 'microos/disk_boot';
    }
}

sub load_selfinstall_boot_tests {
    loadtest 'installation/bootloader_uefi';
    loadtest 'microos/selfinstall';
}

sub load_common_tests {
    loadtest 'transactional/enable_selinux';
    loadtest 'microos/networking';
    loadtest 'microos/libzypp_config';
    loadtest 'microos/image_checks';
    loadtest 'microos/one_line_checks';
    loadtest 'microos/services_enabled';
    loadtest 'microos/cockpit_service';
    loadtest 'console/ansible';
}

sub load_transactional_tests {
    loadtest 'transactional/trup_smoke';
    loadtest 'transactional/filesystem_ro' if is_transactional;
    loadtest 'transactional/transactional_update';
    loadtest 'transactional/rebootmgr';
    loadtest 'transactional/health_check';
}

return 1 if load_yaml_schedule;

if (is_kernel_test()) {
    load_kernel_tests();
    return 1;
}

# Handle boot of images
if (get_var('BOOT_HDD_IMAGE')) {
    load_boot_from_disk_tests;
} elsif (get_var('SELFINSTALL')) {
    load_selfinstall_boot_tests;
}

if (get_var('CONTAINER_RUNTIME') eq 'k3s') {
    loadtest('containers/run_container_in_k3s');
    return 1;
}

loadtest 'transactional/host_config';

# Unless specified otherwise load standard tests only
if (is_container_test()) {
    load_container_tests();
} else {
    load_common_tests;
    load_transactional_tests;
}

# Enclosing test cases
loadtest 'console/journal_check';
loadtest 'shutdown/shutdown';

1;
