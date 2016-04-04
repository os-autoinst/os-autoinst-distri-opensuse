package installbasetest;
use base "opensusebasetest";

use utils;
use testapi;

# All steps in the installation are 'fatal'.
sub test_flags() {
    return {fatal => 1};
}

sub set_netboot_mirror {
    type_string_slow(' install=' . get_netboot_mirror);
}

sub set_netboot_proxy {
    type_string_slow(' proxy=' . get_var("HTTPPROXY"));
}

sub set_textmode {
    type_string_slow " textmode=1";
}

sub set_autoupgrade {
    type_string_slow " autoupgrade=1";
}

sub set_fips {
    type_string_slow " fips=1";
}

sub set_autoyast {
    type_string_slow(" autoyast=" . data_url(get_var("AUTOYAST")));
}

sub set_extra_params {
    type_string_slow(' ' . get_var("EXTRABOOTPARAMS"));
}

sub set_network {
    my $netsetup;
    #need this instead of netsetup as default, see bsc#932692
    $netsetup = "ifcfg=*=dhcp";
    #e.g netsetup=dhcp,all
    $netsetup = get_var("NETWORK_INIT_PARAM") if defined get_var("NETWORK_INIT_PARAM");
    #netsetup override for sle11
    $netsetup = "netsetup=dhcp,all" if defined get_var("USE_NETSETUP");
    type_string_slow $netsetup;
}

1;
# vim: set sw=4 et:
