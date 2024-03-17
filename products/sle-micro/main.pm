use strict;
use warnings;
use needle;
use File::Basename;
use scheduler 'load_yaml_schedule';
use Carp;
BEGIN {
    unshift @INC, dirname(__FILE__) . '/../../lib';
}
use utils;
use testapi;
use main_common qw(init_main is_updates_test_repo unregister_needle_tags join_incidents_to_repo);
use main_micro_alp;
use DistributionProvider;

init_main();

my $distri = testapi::get_required_var('CASEDIR') . '/lib/susedistribution.pm';
require $distri;
testapi::set_distribution(susedistribution->new());

$needle::cleanuphandler = sub {
    unregister_needle_tags('ENV-BACKEND-ipmi');
    unregister_needle_tags('ENV-FLAVOR-JeOS-for-kvm');
    unregister_needle_tags('ENV-JEOS-1');
    unregister_needle_tags('ENV-OFW-0');
    unregister_needle_tags('ENV-OFW-1');
    unregister_needle_tags('ENV-UEFI-1') unless get_var('UEFI');
    unregister_needle_tags('ENV-PXEBOOT-0');
    unregister_needle_tags('ENV-PXEBOOT-1');
    unregister_needle_tags("ENV-DISTRI-sle");
    unregister_needle_tags("ENV-VERSION-15");
    unregister_needle_tags("ENV-VERSION-12");
    unregister_needle_tags("ENV-VERSION-12-SP1");
    unregister_needle_tags("ENV-VERSION-12-SP2");
    unregister_needle_tags("ENV-VERSION-12-SP3");
    unregister_needle_tags("ENV-VERSION-11-SP4");
    unregister_needle_tags("ENV-12ORLATER-1");
    unregister_needle_tags("ENV-FLAVOR-Server-DVD");
};


# Handle updates from repos defined in OS_TEST_TEMPLATE combined with the list
# of issues defined in OS_TEST_ISSUES.
# OS_TEST_ISSUES is set by openQABot and metadata repo used in maintenance
# (https://gitlab.suse.de/qa-maintenance/metadata)
# OS_TEST_TEMPLATE must be set at openQA job level.
# The array of repositories will be stored in MAINT_TEST_REPO for futher
# installation by the maintenance jobs.
if (is_updates_test_repo && !get_var('MAINT_TEST_REPO')) {
    my %incidents;
    my %u_url;
    $incidents{OS} = get_var('OS_TEST_REPOS', get_var('INCIDENT_REPO'));

    if (exists $incidents{OS} && !$incidents{OS}) {
        carp '"OS_TEST_REPOS" or "INCIDENT_REPO" variable is empty!';
    } else {
        my $repos = join_incidents_to_repo(\%incidents);
        set_var('MAINT_TEST_REPO', $repos);
    }
}

testapi::set_distribution(DistributionProvider->provide());

# set failures
#$testapi::distri->set_expected_serial_failures(create_list_of_serial_failures());
#$testapi::distri->set_expected_autoinst_failures(create_list_of_autoinst_failures());

if (load_yaml_schedule) {
    if (YuiRestClient::is_libyui_rest_api) {
        YuiRestClient::set_libyui_backend_vars;
        YuiRestClient::init_logger;
    }
    return 1;
}

main_micro_alp::load_tests();

1;
