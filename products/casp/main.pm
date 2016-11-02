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
    remove_desktop_needles("lxde");
    remove_desktop_needles("kde");
    remove_desktop_needles("gnome");
    remove_desktop_needles("xfce");
    remove_desktop_needles("minimalx");
    remove_desktop_needles("textmode");

    unregister_needle_tags("ENV-INSTLANG-de_DE");
    unregister_needle_tags("ENV-VERSION-12");
    unregister_needle_tags("ENV-VERSION-12-SP1");
    unregister_needle_tags("ENV-SP2ORLATER-0");

    unregister_needle_tags("ENV-FLAVOR-Desktop-DVD");
    unregister_needle_tags('ENV-FLAVOR-JeOS-for-kvm');
    unregister_needle_tags('ENV-ARCH-s390x');
    unregister_needle_tags('ENV-OFW-0');
    unregister_needle_tags('ENV-OFW-1');

    #    unregister_needle_tags("ENV-VIDEOMODE-text");
    #    unregister_needle_tags("ENV-VERSION-12-SP2");
    #    unregister_needle_tags("ENV-FLAVOR-Server-DVD");
}
$needle::cleanuphandler = \&cleanup_needles;

my $distri = testapi::get_var("CASEDIR") . '/lib/susedistribution.pm';
require $distri;
testapi::set_distribution(susedistribution->new());

# Installer workflow is defined in fate#321754
sub load_inst_tests() {
    loadtest "installation/welcome.pm";
    if (get_var('SCC_REGISTER', '') eq 'installation') {
        loadtest "installation/scc_registration.pm";
    }
    else {
        loadtest "installation/skip_registration.pm";
    }
    loadtest "installation/addon_products_sle.pm";
    loadtest "installation/system_role.pm";
    loadtest "installation/partitioning.pm";
    loadtest "installation/partitioning_finish.pm";
    loadtest "installation/releasenotes.pm";
    loadtest "installation/installer_timezone.pm";
    loadtest "installation/user_settings.pm";
    loadtest "installation/user_settings_root.pm";
    loadtest "installation/installation_overview.pm";
    loadtest "installation/start_install.pm";
    loadtest "installation/install_and_reboot.pm";
}

if (check_var("FLAVOR", "VMX")) {
    loadtest "boot/boot_to_desktop.pm";
}
else {
    loadtest "installation/bootloader.pm";
    load_inst_tests();
}
loadtest "installation/first_boot.pm";

1;
# vim: set sw=4 et:
