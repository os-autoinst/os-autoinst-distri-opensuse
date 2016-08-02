# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use strict;
use testapi;

sub validatelr {
    my ($args) = @_;

    my $alias           = $args->{alias} || "";
    my $product         = $args->{product};
    my $product_channel = $args->{product_channel} || "";
    my $version         = get_var('VERSION');
    if (get_var('ZDUP')) {
        $version = "";
    }
    if (get_var('FLAVOR') =~ m{SAP}) {
        $version .= "-SAP";
    }
    # Repo is checked for enabled/disabled state. If the information about the
    # expected state is not delivered to validatelr(), we use some heuristics to
    # determine the expected state: If the installation medium is a physical
    # medium and the system is registered to SCC the repo should be disabled
    # if the system is SLE 12 SP2 and later; enabled otherwise, see PR#11460 and
    # FATE#320494.
    my $enabled_repo = $args->{enabled_repo}
      || (($args->{uri} =~ m{(cd|dvd|hd):///} and check_var('SCC_REGISTER', 'installation') and !check_var('VERSION', '12') and !check_var('VERSION', '12-SP1')) ? "No" : "Yes");
    my $uri = $args->{uri};

    if (check_var('DISTRI', 'sle')) {
        # SLES12 does not have 'SLES12-Source-Pool' SCC channel
        unless (($version eq "12") and ($product_channel eq "Source-Pool")) {
            assert_script_run "zypper lr --uri | awk -F '|' -v OFS=' ' '{ print \$2,\$3,\$4,\$NF }' | tr -s ' ' | grep \"$product$version\[\[:alnum:\]\[:punct:\]\]*-*$product_channel $product$version\[\[:alnum:\]\[:punct:\]\[:space:\]\]*-*$product_channel $enabled_repo $uri\"";
        }
    }
    elsif (check_var('DISTRI', 'opensuse')) {
        # boo#988736: control.xml on the Leap media contains two repos of the name 'repo-source'
        # This should be removed once Leap 42.1 is not being supported.
        if ($product eq "openSUSE-Leap-42.1-Source-Non-Oss") {
            script_run "zypper lr --uri | awk -F '|' -v OFS=' ' '{ print \$2,\$3,\$4,\$NF }' | tr -s ' ' | grep \"$alias\[\[:alnum:\]\[:punct:\]\]* $product\[\[:alnum:\]\[:punct:\]\]* $enabled_repo $uri\"";
        }
        else {
            assert_script_run "zypper lr --uri | awk -F '|' -v OFS=' ' '{ print \$2,\$3,\$4,\$NF }' | tr -s ' ' | grep \"$alias\[\[:alnum:\]\[:punct:\]\]* $product\[\[:alnum:\]\[:punct:\]\]* $enabled_repo $uri\"";
        }
    }
}

sub run() {
    select_console 'root-console';

    assert_script_run "zypper lr";
    save_screenshot;
    script_run "clear";
    assert_script_run "zypper lr -d";
    save_screenshot;
    script_run "clear";

    # Repositories are being validated for (whole) SLE and openSUSE staging
    if (check_var('DISTRI', 'sle') or (check_var('DISTRI', 'opensuse') and get_var('STAGING'))) {
        # SLE & openSUSE: Check repositories from installation medium's 'control.xml' file
        script_run '
        for i in $(find /dev/disk/by-label/*); do
            mkdir dir_$(basename $i);
            mount -v $i dir_$(basename $i) -o ro;
            ls -l dir_$(basename $i);
            cp -v dir_$(basename $i)/control.xml control.xml_$(basename $i);
            umount dir_$(basename $i);
        done;
        ls -l';
        if (my $control_files = script_output("find . -name 'control.xml_*' | tr -s '\\n' ' '")) {
            assert_script_run 'zypper -nv install perl-XML-LibXML';
            type_string 'cat > xml.pl <<__END
use strict;
use XML::LibXML;
use XML::LibXML::XPathContext;

my \$filename = \$ARGV[0];
my \$dom = XML::LibXML->load_xml(location => \$filename);
my \$xpc = XML::LibXML::XPathContext->new(\$dom);
\$xpc->registerNs("yast2ns", "http://www.suse.com/1.0/yast2ns");
my (\$meta) = \$xpc->findnodes("//yast2ns:extra_urls") or die "<extra_urls> is not present";

for my \$el (\$xpc->findnodes(".//yast2ns:extra_url", \$meta)) {
    my (\$p_alias) = \$xpc->findnodes(".//yast2ns:alias", \$el);
    my \$t_alias = \$p_alias->textContent();

    my (\$p_name) = \$xpc->findnodes(".//yast2ns:name", \$el);
    my \$t_name = \$p_name->textContent();

    my (\$p_enabled) = \$xpc->findnodes(".//yast2ns:enabled", \$el);
    my \$t_enabled = \$p_enabled->textContent();

    my (\$p_baseurl) = \$xpc->findnodes(".//yast2ns:baseurl", \$el);
    my \$t_baseurl = \$p_baseurl->textContent();

    print "\$t_alias \$t_name \$t_enabled \$t_baseurl ";
}
__END' . "\n";
            for my $xml_file (split(/ /, $control_files)) {
                # 'control.xml' files does not necessarily need to contain repository
                # definition (i.e. <extra_urls> tag)
                my $xml_data_str = script_output "perl xml.pl $xml_file || true";
                my @xml_data = split(/ /, $xml_data_str);
                while (@xml_data) {
                    validatelr(
                        {
                            alias        => shift @xml_data,
                            product      => shift @xml_data,
                            enabled_repo => (shift @xml_data eq "true") ? "Yes" : "No",
                            uri          => shift @xml_data
                        });
                }
            }
        }
        else {
            # At this point no repository definition was found in control.xml
            # files of installation media. It's fine if it's a network installation.
            # On SLE we rely on "Channels Checking Table" anyway.
            if (check_var('DISTRI', 'opensuse') and (get_var('FLAVOR') =~ m{DVD})) {
                assert_script_run 'false', 0, "Can't find repository definitions in 'control.xml' files (if any).";
            }
        }

        # On SLE we follow "SLE Channels Checking Table"
        # (https://wiki.microfocus.net/index.php?title=SLE12_SP2_Channels_Checking_Table)
        my (%h_addons, %h_addonurl, %h_scc_addons);
        my @addons_keys   = split(/,/, get_var('ADDONS',   ''));
        my @addonurl_keys = split(/,/, get_var('ADDONURL', ''));
        my $scc_addon_str = '';
        foreach (split(/,/, get_var('SCC_ADDONS', ''))) {
            $scc_addon_str .= "SLE-" . uc($_) . ',';
        }
        my @scc_addons_keys = split(/,/, $scc_addon_str);
        @h_addons{@addons_keys}         = ();
        @h_addonurl{@addonurl_keys}     = ();
        @h_scc_addons{@scc_addons_keys} = ();

        my $base_product;
        if (check_var('DISTRI', 'sle')) {
            if (get_var('FLAVOR') =~ m{Desktop-DVD}) {
                $base_product = "SLED";
            }
            else {
                $base_product = "SLES";
            }
        }

        # On system with ONLINE_MIGRATION variable set, we don't have SLE media
        # repository of VERSION N but N-1 (i.e. on SLES12-SP2 we have SLES12-SP1
        # repository. For the sake of sanity, the base product repo is not being
        # verified in such a scenario.
        if (!get_var("ONLINE_MIGRATION")) {
            # This is where we verify base product repos for openSUSE, SLES, SLED,
            # and HA
            if (check_var('FLAVOR', 'Server-DVD')) {
                my $uri = "cd:///";
                if (check_var("BACKEND", "ipmi") || check_var("BACKEND", "generalhw")) {
                    $uri = "http[s]*://.*suse";
                }
                elsif (get_var('USBBOOT')) {
                    $uri = "hd:///.*usbstick";
                }
                elsif (check_var('ARCH', 's390x') and check_var('BACKEND', 'svirt')) {
                    $uri = "ftp://";
                }
                validatelr(
                    {
                        product      => "SLES",
                        enabled_repo => get_var('ZDUP') ? "No" : undef,
                        uri          => $uri
                    });
            }
            elsif (check_var('FLAVOR', 'SAP-DVD')) {
                validatelr({product => "SLE-", uri => "cd:///"});
            }
            elsif (check_var('FLAVOR', 'Server-DVD-HA')) {
                validatelr({product => "SLES", uri => "cd:///"});
                validatelr({product => 'SLE-*HA', uri => get_var('ADDONURL_HA') || "dvd:///"});
                if (exists $h_addonurl{geo} || exists $h_addons{geo}) {
                    validatelr({product => 'SLE-*HAGEO', uri => get_var('ADDONURL_GEO') || "dvd:///"});
                }
                delete @h_addonurl{"ha", "geo"};
                delete @h_addons{"ha",   "geo"};
            }
            elsif (check_var('FLAVOR', 'Desktop-DVD')) {
                # Note: verification of AMD (SLED12) and NVIDIA (SLED12, SP1, and SP2) repos is missing
                validatelr({product => "SLED", uri => "cd:///"});
            }
            elsif (check_var('DISTRI', 'opensuse')) {
                if (get_var('FLAVOR') =~ m{DVD}) {
                    # On Leap 42.1 is installation media repo enabled (FATE#320494 is not implemented there)
                    validatelr(
                        {
                            alias        => "openSUSE",
                            product      => "openSUSE",
                            enabled_repo => (check_var('VERSION', '42.2') or get_var('ZDUP')) ? "No" : "Yes",
                            uri => get_var('USBBOOT') ? "hd:///.*usbstick" : "cd:///"
                        });
                }
                elsif (get_var('FLAVOR') =~ m{NET}) {
                    validatelr(
                        {
                            alias        => "openSUSE",
                            product      => "openSUSE",
                            enabled_repo => "Yes",
                            uri          => "http://.*opensuse"
                        });
                }
            }
        }

        # URI Addons
        for my $addonurl_prod (keys %h_addonurl) {
            my $addonurl_tmp;
            if ($addonurl_prod eq "sdk") {
                $addonurl_tmp = $addonurl_prod;
            }
            else {
                $addonurl_tmp = "sle" . $addonurl_prod;
            }
            validatelr({product => uc $addonurl_tmp, uri => get_var("ADDONURL_" . uc $addonurl_prod)});
        }

        # DVD Addons; FATE#320494 (PR#11460): disable installation source after installation if we register system
        for my $addon (keys %h_addons) {
            if ($addon ne "sdk") {
                $addon = "sle" . $addon;
            }
            validatelr(
                {
                    product      => uc $addon,
                    enabled_repo => get_var('SCC_REGCODE_' . uc $addon) ? "No" : "Yes",
                    uri          => "dvd:///"
                });
        }

        # Verify SLES, SLED, Addons and their online SCC sources, if SCC_REGISTER is enabled
        if (check_var('SCC_REGISTER', 'installation')) {
            for my $scc_product ($base_product, keys %h_scc_addons) {
                for my $product_channel ("Pool", "Updates", "Debuginfo-Pool", "Debuginfo-Updates", "Source-Pool") {
                    validatelr(
                        {
                            product         => $scc_product,
                            product_channel => $product_channel,
                            enabled_repo    => ($product_channel =~ m{(Debuginfo|Source)}) ? "No" : "Yes",
                            uri             => "http[s]*://.*suse"
                        });
                }
            }
        }

        # zdup upgrade repo verification
        if (get_var('ZDUP')) {
            my $uri;
            if (get_var('TEST') =~ m{zdup_offline}) {
                $uri = "dvd:///";
            }
            else {
                if (my $susemirror = get_var('SUSEMIRROR')) {
                    $uri = $susemirror;
                }
                else {
                    $uri = "ftp://openqa.suse.de/SLE-";
                }
            }
            validatelr(
                {
                    product      => "repo1",
                    enabled_repo => "Yes",
                    uri          => $uri
                });
        }
    }
}

1;
# vim: set sw=4 et:
