use strict;
use warnings;
use testapi qw/check_var get_var set_var/;
use needle;
use File::Basename;

BEGIN {
    unshift @INC, dirname(__FILE__) . '/../../lib';
}
use utils;
use main_common;

init_main();

# Reuse SP2 needles for YaST installer
sub cleanup_needles {
    remove_common_needles;
    unregister_needle_tags("ENV-INSTLANG-de_DE");
    unregister_needle_tags("ENV-VERSION-12");
    unregister_needle_tags("ENV-VERSION-12-SP1");
    unregister_needle_tags("ENV-SP2ORLATER-0");

    unregister_needle_tags("ENV-FLAVOR-Desktop-DVD");
    unregister_needle_tags('ENV-FLAVOR-JeOS-for-kvm');
    unregister_needle_tags('ENV-ARCH-s390x');
    unregister_needle_tags('ENV-OFW-0');
    unregister_needle_tags('ENV-OFW-1');
}
$needle::cleanuphandler = \&cleanup_needles;

my $distri = testapi::get_var("CASEDIR") . '/lib/susedistribution.pm';
require $distri;
testapi::set_distribution(susedistribution->new());

# Installer workflow is defined in fate#321754
sub load_inst_tests() {
    loadtest "installation/welcome";
    if (get_var('SCC_REGISTER', '') eq 'installation') {
        loadtest "installation/scc_registration";
    }
    else {
        loadtest "installation/skip_registration";
    }
    loadtest "installation/addon_products_sle";
    loadtest "installation/system_role";
    loadtest "installation/partitioning";
    loadtest "installation/partitioning_finish";
    loadtest "installation/releasenotes";
    loadtest "installation/installer_timezone";
    loadtest "installation/user_settings";
    loadtest "installation/user_settings_root";
    loadtest "installation/installation_overview";
    loadtest "installation/start_install";
    loadtest "installation/install_and_reboot";
}

if (check_var("FLAVOR", "VMX")) {
    loadtest "boot/boot_to_desktop";
}
else {
    loadtest "installation/bootloader";
    load_inst_tests();
}
loadtest "installation/first_boot";
loadtest "casp/login";

1;
# vim: set sw=4 et:
