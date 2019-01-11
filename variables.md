## Supported list of variables which control test suites

Below you can find the list of variables which control tests behavior, including schedule.
Please, find [os-autoinst backend variables](https://github.com/os-autoinst/os-autoinst/blob/master/doc/backend_vars.asciidoc) which complement the list of variables below.

NOTE: This list is not complete and may contain outdated info. If you face such a case, please, create pull request with required changes.

Variable        | Type      | Default value | Details
---             | ---       | ---           | ---
ADDONS          | string    |               | Comma separated list of addons to be added using DVD. Also used to indicate addons in the SUT.
ADDONURL        | string    |               | Comma separated list of addons. Includes addon names to get url defined in ADDONURL_*. For example: ADDONURL=sdk,we ADDONURL_SDK=https://url ADDONURL_WE=ftp://url
ADDONURL_*      | string    |               | Define url for the addons list defined in ADDONURL
AUTOCONF        | boolean   | false         | Toggle automatic configuration
AUTOYAST        | string    |               | Full url to the AY profile or relative path if in [data directory of os-autoinst-distri-opensuse repo](https://github.com/os-autoinst/os-autoinst-distri-opensuse/tree/master/data). If value starts with `aytests/`, these profiles are provided by suport server, source code is available in [aytests repo](https://github.com/yast/aytests-tests)
AUTOYAST_PREPARE_PROFILE | boolean | false | Enable variable expansion in the autoyast profile.
AUTOYAST_VERIFY | string | | Script to be executed to validate installation. Can be url, relative path if in [data directory of os-autoinst-distri-opensuse repo](https://github.com/os-autoinst/os-autoinst-distri-opensuse/tree/master/data) or test module name to be scheduled after installation is conducted.
AUTOYAST_VERIFY_TIMEOUT  | boolean | false | Enable validation of pop-up windows timeout.
BASE_VERSION | string | | |
BETA | boolean | false | Enables checks and processing of beta warnings. Defines current stage of the product under test.
BTRFS | boolean | false | Indicates btrfs filesystem. Deprecated, use FILESYSTEM instead.
BUILD | string  |       | Indicates build number of the product under test.
CASEDIR | string | | Path to the directory which contains tests.
CHECK_RELEASENOTES | boolean | false | Loads `installation/releasenotes` test module.
CHECK_RELEASENOTES_ORIGIN | boolean | false | Loads `installation/releasenotes_origin` test module.
DESKTOP | string | | Indicates expected DM, e.g. `gnome`, `kde`, `textmode`, `xfce`, `lxde`. Does NOT prescribe installation mode. Installation is controlled by `VIDEOMODE` setting
DEV_IMAGE | boolean | false | This setting is used to set veriables properly when SDK or Development-Tools are required.
DISABLE_ONLINE_REPOS | boolean | false | Enables `installation/disable_online_repos` test module, relevant for openSUSE only. Test module explicitly disables online repos not to be used during installation.
DISABLE_SLE_UPDATES | boolean | false | Disables online updates for the installation. Is true if `QAM_MINIMAL` is true for SLE.
DISTRI | string | | Defines distribution. Possible values: `sle`, `opensuse`, `casp`, `caasp`, `kubic`.
DOCKER_IMAGE_TEST | boolean | false | Enables docker test suite.
DOCRUN | boolean | false |
DUALBOOT | boolean | false | Enables dual boot configuration during the installation.
DUD | string | | Defines url or relative path to the DUD file if in [data directory of os-autoinst-distri-opensuse repo](https://github.com/os-autoinst/os-autoinst-distri-opensuse/tree/master/data)
DUD_ADDONS | string | | Comma separated list of addons added using DUD.
DVD |||
ENCRYPT | boolean | false | Enables or indicates encryption of the disks. Can be combine with `FULL_LVM_ENCRYPT`, `ENCRYPT_CANCEL_EXISTING`, `ENCRYPT_ACTIVATE_EXISTING` and `UNENCRYPTED_BOOT`.
EVERGREEN |||
EXTRABOOTPARAMS | string | | Concatenates content of the string as boot options applied to the bootloader.
EXTRATEST | boolean | false | Enables execution of extra tests, see `load_extra_tests`
FLAVOR | string | | Defines flavor of the product under test, e.g. `staging-.-DVD`, `Krypton`, `Argon`, `Gnome-Live`, `DVD`, `Rescue-CD`, etc.
FULLURL | string | | Full url to the factory repo. Is relevant for openSUSE only.
FULL_LVM_ENCRYPT | boolean | false | Enables/indicates encryption using lvm. boot partition may or not be encrypted, depending on the product default behavior.
HASLICENSE | boolean | true if SLE, false otherwise | Enables processing and validation of the license agreements.
HDDVERSION | string | | Indicates version of the system installed on the HDD.
HTTPPROXY  |||
EXPECTED_INSTALL_HOSTNAME | string | | Contains expected hostname YaST installer got from the environment (DHCP, 'hostname=' as a kernel cmd line argument)
INSTALL_SOURCE | string | | Specify network protocol to be used as installation source e.g. MIRROR_HTTP
INSTALLATION_VALIDATION | string | | Comma separated list of modules to be used for installed system validation, should be used in combination with INSTALLONLY, to schedule only relevant test modules.
INSTALLONLY | boolean | false | Indicates that test suite conducts only installation. Is recommended to be used for all jobs which create and publish images
INSTLANG | string | en_US | Installation locale settings.
IPXE | boolean | false | Indicates ipxe boot.
ISO_MAXSIZE | integer | | Max size of the iso, used in `installation/isosize.pm`.
KEEP_ONLINE_REPOS | boolean | false | openSUSE specific variable, not to replace original repos in the installed system with snapshot mirrors which are not yet published.
LAPTOP |||
LIVECD | boolean | false | Indicates live image being used.
LIVE_INSTALLATION | boolean | false | If set, boots the live media and starts the builtin NET installer.
LIVE_UPGRADE | boolean | false | If set, boots the live media and starts the builtin NET installer in upgrade mode.
LIVETEST | boolean | false | Indicates test of live system.
LVM | boolean | false | Use lvm for partitioning.
LVM_THIN_LV | boolean | false | Use thin provisioning logical volumes for partitioning,
MACHINE | string | | Define machine name which defines worker specific configuration, including WORKER_CLASS.
MEDIACHECK | boolean | false | Enables `installation/mediacheck` test module.
MEMTEST | boolean | false | Enables `installation/memtest` test module.
MIRROR_{protocol} | string | | Specify source address
MOZILLATEST |||
NAME | string | | Name of the test run including distribution, build, machine name and job id.
NET | boolean | false | Indicates net installation.
NETBOOT | boolean | false | Indicates net boot.
NETDEV | string | | Network device to be used when adding interface on zKVM.
NFSSERVER | boolean | false | Indicates/enables nfs server in `console/yast2_nfs_server`.
NICEVIDEO |||
NOAUTOLOGIN | boolean | false | Indicates disabled auto login.
NOIMAGES |||
NOLOGS | boolean | false | Do not collect logs if set to true. Handy during development.
PERF_KERNEL | boolean | false | Enables kernel performance testing.
PERF_INSTALL | boolean | false | Enables kernel performance testing installation part.
PERF_SETUP | boolean | false | Enables kernel performance testing deployment part.
PERF_RUNCASE | boolean | false | Enables kernel performance testing run case part.
RAIDLEVEL | integer | | Define raid level to be configured. Possible values: 0,1,5,6,10.
REGRESSION | string | | Define scope of regression testing, including ibus, gnome, documentation and other.
REMOTE_REPOINST | boolean | | Use linuxrc features to install OS from specified repository (install) while booting installer from DVD (instsys)
REPO_* | string | | Url pointing to the mirrored repo. REPO_0 contains installation iso.
RESCUECD | boolean | false | Indicates rescue image to be used.
RESCUESYSTEM | boolean | false | Indicates rescue system under test.
SCC_ADDONS | string | | Coma separated list of modules to be enabled using SCC/RMT.
SELECT_FIRST_DISK | boolean | false | Enables test module to select first disk for the installation. Is used for baremetal machine tests with multiple disks available, including cases when server still has previous installation.
SKIP_CERT_VALIDATION | boolean | false | Enables linuxrc parameter to skip certificate validation of the remote source, e.g. when using self-signed https url.
SLE_PRODUCT | string | | Defines SLE product. Possible values: `sles`, `sled`, `sles4sap`. Is mainly used for SLE 15 installation flow.
SOFTFAIL_BSC1063638 | boolean | false | Enable bsc#1063638 detection.
STAGING | boolean | false | Indicates staging environment.
SPECIFIC_DISK | boolean | false | Enables installation/partitioning_olddisk test module.
SPLITUSR | boolean | false | Enables `installation/partitioning_splitusr` test module.
SUSEMIRROR | string | | Mirror url of the installation medium.
SYSAUTHTEST | boolean | false | Enable system authentication test (`sysauth/sssd`)
TEST | string | | Name of the test suite.
TOGGLEHOME | boolean | false | Changes the state of partitioning to have or not to have separate home partition in the proposal.
UEFI | boolean | false | Indicates UEFI in the testing environment.
UPGRADE | boolean | false | Indicates upgrade scenario.
USBBOOT | boolean | false | Indicates booting to the usb device.
USEIMAGES |||
VALIDATE_INST_SRC | boolean | false | Validate installation source in /etc/install.inf
VERSION | string | | Contains major version of the product. E.g. 15-SP1 or 15.1
VIDEOMODE | string | | Indicates/defines video mode used for the installation. Empty value uses default, other possible values `text`, `ssh-x` for installation ncurses and x11 over ssh respectivelyю
VIRSH_OPENQA_BASEDIR | string | /var/lib | The OPENQA_BASEDIR configured on the svirt host (only relevant for the svirt backend).
UNENCRYPTED_BOOT | boolean | false | Indicates/defines existence of unencrypted boot partition in the SUT.
WAYLAND | boolean | false | Enables wayland tests in the system.
XDMUSED | boolean | false | Indicates availability of xdm.
Y2UITEST_NCURSES | boolean | false | Enables yast2 tests of modules with ncurses.
Y2UITEST_GUI | boolean | false | Enables yast2 tests of modules with x11.
ZDUP | boolean | false | Prescribes zypper dup scenario.
ZDUPREPOS | string | | Defines repo to be added/used for zypper dup call.
