# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Support for Selenium
# Maintainer: Vladimir Nadvornik <nadvornik@suse.com>

package selenium;

use base Exporter;
use Exporter;

use strict;

our @EXPORT = qw(
  add_chromium_repos
  install_chromium
  enable_selenium_port
  selenium_driver
  wait_for_page_to_load
  wait_for_link
  wait_for_text
  wait_for_xpath
);

use testapi;
use utils 'zypper_call';

use Selenium::Remote::Driver;
use Selenium::Chrome;
use Selenium::Waiter qw/wait_until/;

my $port = 4444;

sub add_chromium_repos {
    my $ret = zypper_call("se chromedriver", exitcode => [0, 104]);
    if ($ret == 104) {
        zypper_call(
            '--gpg-auto-import-keys ar -fc http://download.opensuse.org/repositories/openSUSE:/Backports:/SLE-12/standard/openSUSE:Backports:SLE-12.repo');
        zypper_call(
'--gpg-auto-import-keys ar -fc http://download.opensuse.org/repositories/openSUSE:/Backports:/SLE-12-SP1/standard/openSUSE:Backports:SLE-12-SP1.repo'
        );
        zypper_call(
'--gpg-auto-import-keys ar -fc http://download.opensuse.org/repositories/openSUSE:/Backports:/SLE-12-SP2/standard/openSUSE:Backports:SLE-12-SP2.repo'
        );
        zypper_call('--gpg-auto-import-keys ar -fc http://smt.suse.cz/repo/SUSE/Products/SLE-SDK/12-SP2/x86_64/product/ sdk');
        zypper_call('--gpg-auto-import-keys ref');
    }
}

sub install_chromium {
    zypper_call('in chromium chromedriver');
    script_run("ln -s /usr/lib64/chromium/chromedriver /usr/bin/chromedriver");
}

sub enable_selenium_port {
    # FIXME: this does not work for some reason:
    # assert_script_run("sed -i -e 's|FW_SERVICES_EXT_TCP=\"\\(.*\\)\"|FW_SERVICES_EXT_TCP=\"\\1 $port\"|' /etc/sysconfig/SuSEfirewall2");
    # assert_script_run("rcSuSEfirewall2 restart");
    assert_script_run("rcSuSEfirewall2 stop");
}


my $driver;

sub selenium_driver {

    return $driver if $driver;

    die "Selenium support works only with openvswitch and tap devices" unless check_var('NICTYPE', 'tap');

    my @mac_parts = split(':', get_var('NICMAC'));
    my $sut = "10.1." . hex($mac_parts[4]) . '.' . hex($mac_parts[5]);

    select_console('x11');

    x11_start_program('xterm');
    assert_screen('xterm');

    script_output("
    curl -f -v " . autoinst_url . "/data/selenium-server-standalone-3.4.0.jar > selenium-server-standalone-3.4.0.jar
  ");

    type_string("java -jar selenium-server-standalone-3.4.0.jar -port $port 2>&1 | tee /dev/$serialdev\n");
    save_screenshot;
    wait_serial('Selenium Server is up and running');
    save_screenshot;

    # HACK: this connection is only possible because the SUT initiated
    # connection to 10.0.2.2 before (in script_output) so the openvswitch
    # routing tables are filled
    $driver = Selenium::Chrome->new(remote_server_addr => $sut, port => $port);
    return $driver;
}

sub wait_for_page_to_load {
    my ($timeout) = @_;

    return wait_until {
        $driver->execute_script("return document.readyState") eq 'complete'
    }, timeout => $timeout;
}

sub wait_for {
    my ($type, $target, @args) = @_;
    my %args = (
        -tries              => 5,
        -wait               => 1,
        -reload_after_tries => 5,
        @args
    );

    die 'Unknown wait type' unless grep(/$type/, qw(text link xpath));
    diag "waiting for ${type}: ${target}";
    my $i = 0;
    while ($i < $args{-tries}) {
        save_screenshot;
        my $element;
        if ($type eq 'text') {
            return 1 if $driver->get_page_source() =~ /$target/;
        }
        elsif ($type eq 'link') {
            $element = $driver->find_element_by_partial_link_text($target);
        }
        elsif ($type eq 'xpath') {
            $element = $driver->find_element_by_xpath($target);
        }

        if ($element) {
            $driver->execute_script("arguments[0].scrollIntoView(false);", $element);
            sleep 1;
            save_screenshot;
            return $element;
        }
        if (($i > 0) && ($i % $args{-reload_after_tries} == 0)) {
            print "reload\n";
            $driver->refresh();
            wait_for_page_to_load;
        }
        sleep $args{-wait};
        $i++;
    }
    print $driver->get_page_source();
    die "$target not found on the page";
}

sub wait_for_link {
    return wait_for('link', @_);
}


sub wait_for_text {
    return wait_for('text', @_);
}

sub wait_for_xpath {
    return wait_for('xpath', @_);
}


1;
