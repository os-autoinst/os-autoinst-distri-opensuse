# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Support for Selenium
# Maintainer: Ondrej Holecek oholecek@suse.com>

package selenium;
use 5.018;

use base 'Exporter';
use Exporter;

our @EXPORT = qw(
  add_chromium_repos
  install_chromium
  enable_selenium_port
  selenium_driver
  wait_for_page_to_load
  wait_for_link
  wait_for_text
  wait_for_xpath
  select_input
);

use testapi;
use utils 'zypper_call';
use opensusebasetest;
use version_utils qw(is_sle is_caasp);

use Selenium::Remote::Driver;
use Selenium::Chrome;
use Selenium::Firefox;
use Selenium::Waiter qw/wait_until/;
use Selenium::Remote::WDKeys;

my $port = 4444;

=head1 openQA - selenium webdriver support

This Selenium module exports subroutines helpers to integrate C<Selenium::Remote::Driver>
into openQA tests

Note: Selenium module works only when openvswitch networking is used!

Chromedriver and chromium are installed on SUT, firewall is enabled. OpenQA worker then initiate
connection to SUT and returns C<Selenium::Remote::Driver> to be used in tests.

Usage:

  use selenium;
  add_chromium_repos;   # for SLES12

  install_chromium;
  enable_selenium_port;

  my $driver = selenium_driver;
  ...
=cut
sub add_chromium_repos {
    my $ret = zypper_call("se chromedriver", exitcode => [0, 104]);
    if ($ret == 104) {
        if (is_sle('<15')) {
            zypper_call(
                '--gpg-auto-import-keys ar -fc http://download.opensuse.org/repositories/openSUSE:/Backports:/SLE-12/standard/openSUSE:Backports:SLE-12.repo');
            zypper_call(
'--gpg-auto-import-keys ar -fc http://download.opensuse.org/repositories/openSUSE:/Backports:/SLE-12-SP1/standard/openSUSE:Backports:SLE-12-SP1.repo'
            );
            zypper_call(
'--gpg-auto-import-keys ar -fc http://download.opensuse.org/repositories/openSUSE:/Backports:/SLE-12-SP2/standard/openSUSE:Backports:SLE-12-SP2.repo'
            );
            zypper_call(
'--gpg-auto-import-keys ar -fc http://download.opensuse.org/repositories/openSUSE:/Backports:/SLE-12-SP3/standard/openSUSE:Backports:SLE-12-SP3.repo'
            );
        }
        elsif (is_sle('>=15')) {
            zypper_call(
                '--gpg-auto-import-keys ar -fc http://download.opensuse.org/repositories/openSUSE:/Backports:/SLE-15/standard/openSUSE:Backports:SLE-15.repo');
        }
        zypper_call('--gpg-auto-import-keys ref');
    }
}

sub install_chromium {
    zypper_call('in chromium chromedriver');
}

sub enable_selenium_port {
    assert_script_run('systemctl stop ' . opensusebasetest::firewall());
}

my $driver;

sub setup_geckodriver {
    my $sut = shift;
    assert_script_sudo 'systemctl stop ' . opensusebasetest::firewall();

    # We need old driver with firefox 52esr
    my $gecko = script_run('rpm -q MozillaFirefox | grep "52.*esr"') ? 'geckodriver22' : 'geckodriver18';
    assert_script_run 'curl -o geckodriver ' . data_url("caasp/$gecko");
    assert_script_run 'chmod +x geckodriver';
    type_string("./geckodriver --host 0.0.0.0 | tee /dev/$serialdev\n");
    wait_still_screen 1;
    send_key 'super-h';

    # Workaround for CaaSP support-server hacks
    my $profile = Selenium::Firefox::Profile->new;
    $profile->set_boolean_preference('browser.download.forbid_open_with' => 1) if is_caasp;

    $driver = Selenium::Firefox->new(
        firefox_profile => $profile,
        remote_server_addr => $sut, port => $port);
}

sub setup_chromedriver {
    my $sut = shift;

    type_string("/usr/lib64/chromium/chromedriver --port=$port --url-base=wd/hub --whitelisted-ips | tee /dev/$serialdev\n");
    save_screenshot;
    wait_serial(qr(Starting ChromeDriver .* on port $port));
    save_screenshot;

    # HACK: this connection is only possible because the SUT initiated
    # connection to 10.0.2.2 before (in script_output) so the openvswitch
    # routing tables are filled
    $driver = Selenium::Chrome->new(remote_server_addr => $sut, port => $port);

    # https://github.com/teodesian/Selenium-Remote-Driver/issues/367
    $driver->{is_wd3} = 0;
}

sub selenium_driver {
    return $driver if $driver;
    my $browser = shift // 'chromium';

    die "Selenium support works only with openvswitch and tap devices" unless check_var('NICTYPE', 'tap');

    my @mac_parts = split(':', get_var('NICMAC'));
    my $sut = "10.1." . hex($mac_parts[4]) . '.' . hex($mac_parts[5]);

    select_console 'x11';
    x11_start_program('xterm');

    if ($browser == 'firefox') {
        setup_geckodriver($sut);
    } else {
        setup_chromedriver($sut);
    }
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

sub select_input {
    my ($id) = @_;
    $driver->mouse_move_to_location(element => wait_for_xpath("//input[\@id=\'$id\']"));
    $driver->click();
    $driver->send_keys_to_active_element(KEYS->{'control'}, 'a');
    $driver->send_keys_to_active_element(KEYS->{'control'});
}

1;
