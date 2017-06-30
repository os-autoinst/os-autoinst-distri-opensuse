SUSE Manager Retail test suite

2x installation jobs - suma_install and suma_minion_install
1x suma_master parent
1x suma_minion branch (2xNIC)
1x suma_minion terminal

Installation jobs - have SUMA_IMAGE_BUILD variable and SUMA_SALT_MINION variable for minion install job

all jobs expects SUMA_TESTS variable containing names of test modules to load
minion branch has SUMA_SALT_MINION variable set to 'branch'
minion terminal has SUMA_SALT_MINION variable set to 'terminal'


Schedule command example:
# openqa-client --host sleposbuilder.suse.cz isos post DISTRI=sle FLAVOR=Server-DVD ARCH=x86_64 VERSION=12-SP2 ISO=SLE-12-SP2-Server-DVD-x86_64-GM-DVD1.iso ISO_2_URL=http://mirror.suse.cz/install/SUSE-Manager-3.1-Beta3/SUSE-Manager-Server-3.1-DVD-x86_64-Build0093-Media1.iso TEST=suma_minion,suma_minion_terminal SUMA_TESTS=dhcpd_formula
