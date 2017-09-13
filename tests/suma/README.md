SUSE Manager Retail test suite

2x installation jobs - suma_install and suma_minion_install
1x suma_master parent
1x suma_minion branch (2xNIC)
1x suma_minion terminal

Installation jobs - have SUMA_IMAGE_BUILD variable and SUMA_SALT_MINION variable for minion install job

all jobs expects SUMA_TESTS variable containing names of test modules to load
minion branch has SUMA_SALT_MINION variable set to 'branch'
minion terminal has SUMA_SALT_MINION variable set to 'terminal'

Selenium testing
================

Selenium is a tool used for browser automation.
Selenium and perl client is already used for tests of openQA itself.
SUMA tests based on Selenium and Cucumber: https://github.com/SUSE/spacewalk-testsuite-base

Possible configurations:

1. Selenium::Remote::Driver -> PhantomJS

2. Selenium::Remote::Driver -> selenium-server-standalone-3.4.0.jar -> chromedriver -> Chromium

3. Selenium::Remote::Driver -> selenium-server-standalone-3.4.0.jar -> geckodriver -> Firefox


- PhantomJS is rather unstable, no rendering
- geckodriver is not packaged
- chromedriver and Chromium is packaged for opensuse and backported for SLE

so option 2 has been chosen.

Usage:

use selenium;
my $driver = selenium_driver();
$driver->find_element('saltboot', 'link_text')->click();


See man Selenium::Remote::Driver for details



Suma installation:
# openqa-client --host sleposbuilder4.suse.cz isos post DISTRI=sle FLAVOR=Server-DVD ARCH=x86_64 VERSION=12-SP2 BUILD_SLE=GM  ISO=SLE-12-SP2-Server-DVD-x86_64-GM-DVD1.iso ISO_2_URL=http://dist.suse.de/install/SUSE-Manager-3.1-GM/SUSE-Manager-Server-3.1-DVD-x86_64-Build0147-Media1.iso SCC_REGCODE=XXXXXX SCC_REGISTER=suma_retail_installation SCC_MIRROR_ID=XXXXXX SCC_MIRROR_PASS=XXXXXX TEST=suma_install

Schedule command example:
# openqa-client --host sleposbuilder.suse.cz isos post DISTRI=sle FLAVOR=Server-DVD ARCH=x86_64 VERSION=12-SP2 ISO=SLE-12-SP2-Server-DVD-x86_64-GM-DVD1.iso ISO_2_URL=http://dist.suse.de/install/SUSE-Manager-3.1-GM/SUSE-Manager-Server-3.1-DVD-x86_64-Build0147-Media1.iso TEST=suma_minion,suma_minion_terminal,suma_minion_terminal2 SUMA_TESTS=branch_network_formula,dhcpd_formula,bind_formula,tftp_formula,vsftpd_formula,build_image,pxe_formula,saltboot_formula,saltboot_orchestrate,saltboot_orchestrate_reboot
