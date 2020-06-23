## Supported list of variables which control test suites

Below you can find the list of variables which control tests behavior, including schedule.
Please, find [os-autoinst backend variables](https://github.com/os-autoinst/os-autoinst/blob/master/doc/backend_vars.asciidoc) which complement the list of variables below.

NOTE: This list is not complete and may contain outdated info. If you face such a case, please, create pull request with required changes.

Variable        | Type      | Default value | Details
---             | ---       | ---           | ---
ADDONS          | string    |               | Comma separated list of addons to be added using DVD. Also used to indicate addons in the SUT.
ADDONURL        | string    |               | Comma separated list of addons. Includes addon names to get url defined in ADDONURL_*. For example: ADDONURL=sdk,we ADDONURL_SDK=https://url ADDONURL_WE=ftp://url
ADDONURL_*      | string    |               | Define url for the addons list defined in ADDONURL
ASSERT_BSC1122804 | boolean | false | In some scenarios it is necessary to check if the mistyped full name still happens.
ASSERT_Y2LOGS   | boolean   | false         | If set to true, we will parse YaST logs after installation and fail test suite in case unknown errors were detected.
AUTOCONF        | boolean   | false         | Toggle automatic configuration
AUTOYAST        | string    |               | Full url to the AY profile or relative path if in [data directory of os-autoinst-distri-opensuse repo](https://github.com/os-autoinst/os-autoinst-distri-opensuse/tree/master/data). If value starts with `aytests/`, these profiles are provided by suport server, source code is available in [aytests repo](https://github.com/yast/aytests-tests)
AUTOYAST_PREPARE_PROFILE | boolean | false | Enable variable expansion in the autoyast profile.
AUTOYAST_VERIFY | string | | Script to be executed to validate installation. Can be url, relative path if in [data directory of os-autoinst-distri-opensuse repo](https://github.com/os-autoinst/os-autoinst-distri-opensuse/tree/master/data) or test module name to be scheduled after installation is conducted.
AUTOYAST_VERIFY_TIMEOUT  | boolean | false | Enable validation of pop-up windows timeout.
AY_EXPAND_VARS | string | | Commas separated list of variable names to be expanded in the provided autoyast profile. For example: REPO_SLE_MODULE_BASESYSTEM,DESKTOP,... Provided variables will replace `{{VAR}}` in the profile with the value of given variable. See also `AUTOYAST_PREPARE_PROFILE`.
BASE_VERSION | string | | |
BETA | boolean | false | Enables checks and processing of beta warnings. Defines current stage of the product under test.
BTRFS | boolean | false | Indicates btrfs filesystem. Deprecated, use FILESYSTEM instead.
BUILD | string  |       | Indicates build number of the product under test.
CASEDIR | string | | Path to the directory which contains tests.
CHECK_RELEASENOTES | boolean | false | Loads `installation/releasenotes` test module.
CHECK_RELEASENOTES_ORIGIN | boolean | false | Loads `installation/releasenotes_origin` test module.
CHECKSUM_* | string | | SHA256 checksum of the * medium. E.g. CHECKSUM_ISO_1 for ISO_1.
CHECKSUM_FAILED | string | | Variable is set if checksum of installation medium fails to visualize error in the test module and not just put this information in the autoinst log file.
CONTAINER_TOTEST | string | | The string can be "totest/" or "", depending on the URL of the image in the container image registry.
CPU_BUGS | boolean | | Into Mitigations testing
DESKTOP | string | | Indicates expected DM, e.g. `gnome`, `kde`, `textmode`, `xfce`, `lxde`. Does NOT prescribe installation mode. Installation is controlled by `VIDEOMODE` setting
DEPENDENCY_RESOLVER_FLAG| boolean | false      | Control whether the resolve_dependecy_issues will be scheduled or not before certain modules which need it.
DEV_IMAGE | boolean | false | This setting is used to set veriables properly when SDK or Development-Tools are required.
DISABLE_ONLINE_REPOS | boolean | false | Enables `installation/disable_online_repos` test module, relevant for openSUSE only. Test module explicitly disables online repos not to be used during installation.
DISABLE_SLE_UPDATES | boolean | false | Disables online updates for the installation. Is true if `QAM_MINIMAL` is true for SLE.
DISTRI | string | | Defines distribution. Possible values: `sle`, `opensuse`, `casp`, `caasp`, `microos`.
DOCRUN | boolean | false |
DUALBOOT | boolean | false | Enables dual boot configuration during the installation.
DUD | string | | Defines url or relative path to the DUD file if in [data directory of os-autoinst-distri-opensuse repo](https://github.com/os-autoinst/os-autoinst-distri-opensuse/tree/master/data)
DUD_ADDONS | string | | Comma separated list of addons added using DUD.
DVD |||
ENCRYPT | boolean | false | Enables or indicates encryption of the disks. Can be combined with `FULL_LVM_ENCRYPT`, `ENCRYPT_CANCEL_EXISTING`, `ENCRYPT_ACTIVATE_EXISTING` and `UNENCRYPTED_BOOT`.
ENCRYPT_CANCEL_EXISTING | boolean | false | Used to cancel activation of the encrypted partitions |
ETC_PASSWD | string | | Sets content for /etc/passwd, can be used to mimic existing users. Is used to test import of existing users on backends which
have no shapshoting support (powerVM, zVM). Should be used together with `ENCRYPT_ACTIVATE_EXISTING` and `ETC_SHADOW`.
ETC_SHADOW | string | | Sets content for /etc/shadow, can be used to mimic existing users. Is used to test import of existing users on backends which
have no shapshoting support (powerVM, zVM). Should be used together with `ENCRYPT_ACTIVATE_EXISTING` and `ETC_PASSWD`.
EVERGREEN |||
EXIT_AFTER_START_INSTALL | boolean | false | Indicates that test suite will be finished after `installation/start_install` test module. So that all the test modules after this one will not be scheduled and executed.
EXPECTED_INSTALL_HOSTNAME | string | | Contains expected hostname YaST installer got from the environment (DHCP, 'hostname=', as a kernel cmd line argument)
EXTRABOOTPARAMS | string | | Concatenates content of the string as boot options applied to the installation bootloader.
EXTRABOOTPARAMS_BOOT_LOCAL | string | | Boot options applied during the boot process of a local installation.
EXTRABOOTPARAMS_DELETE_CHARACTERS | string | | Characters to delete from boot prompt.
EXTRABOOTPARAMS_DELETE_NEEDLE_TARGET | string | | If specified, go back with the cursor until this needle is matched to delete characters from there. Needs EXTRABOOTPARAMS_BOOT_LOCAL and should be combined with EXTRABOOTPARAMS_DELETE_CHARACTERS.
EXTRATEST | boolean | false | Enables execution of extra tests, see `load_extra_tests`
FLAVOR | string | | Defines flavor of the product under test, e.g. `staging-.-DVD`, `Krypton`, `Argon`, `Gnome-Live`, `DVD`, `Rescue-CD`, etc.
SALT_FORMULAS_PATH | string | | Used to point to a tarball with relative path to [/data/yast2](https://github.com/os-autoinst/os-autoinst-distri-opensuse/tree/master/data/yast2) which contains all the needed files (top.sls, form.yml, ...) to support provisioning with Salt masterless mode.
FULLURL | string | | Full url to the factory repo. Is relevant for openSUSE only.
FULL_LVM_ENCRYPT | boolean | false | Enables/indicates encryption using lvm. boot partition may or not be encrypted, depending on the product default behavior.
FUNCTION | string | | Specifies SUT's role for MM test suites. E.g. Used to determine which SUT acts as target/server and initiator/client for iscsi test suite
GRUB_PARAM | string | | A semicolon-separated list of extra boot options. Adds 2 grub meny entries per each item in main grub (2nd entry is the "Advanced options ..." submenu). See `add_custom_grub_entries()`.
GRUB_BOOT_NONDEFAULT | boolean | false | Boot grub menu entry added by `add_custom_grub_entries` (having setup `GRUB_PARAM=debug_pagealloc=on;ima_policy=tcb;slub_debug=FZPU`, `GRUB_BOOT_NONDEFAULT=1` selects 3rd entry, which contains `debug_pagealloc=on`, `GRUB_BOOT_NONDEFAULT=2` selects 5th entry, which contains `ima_policy=tcb`). NOTE: ARCH=s390x on BACKEND=s390x is not supported. See `boot_grub_item()`, `handle_grub()`.
GRUB_SELECT_FIRST_MENU | integer | | Select grub menu entry in main grub menu, used together with GRUB_SELECT_SECOND_MENU. GRUB_BOOT_NONDEFAULT has higher preference when both set. NOTE: ARCH=s390x on BACKEND=s390x is not supported. See `boot_grub_item()`, `handle_grub()`.
GRUB_SELECT_SECOND_MENU | integer | | Select grub menu entry in secondary grub menu (the "Advanced options ..." submenu), used together with GRUB_SELECT_FIRST_MENU. GRUB_BOOT_NONDEFAULT has higher preference when both set. NOTE: ARCH=s390x on BACKEND=s390x is not supported. See `boot_grub_item()`, `handle_grub()`.
HASLICENSE | boolean | true if SLE, false otherwise | Enables processing and validation of the license agreements.
HDDVERSION | string | | Indicates version of the system installed on the HDD.
HTTPPROXY  |||
INSTALL_KEYBOARD_LAYOUT | string | | Specify one of the supported keyboard layout to switch to during installation or to be used in autoyast scenarios e.g.: cz, fr
INSTALL_SOURCE | string | | Specify network protocol to be used as installation source e.g. MIRROR_HTTP
INSTALLATION_VALIDATION | string | | Comma separated list of modules to be used for installed system validation, should be used in combination with INSTALLONLY, to schedule only relevant test modules.
INSTALLONLY | boolean | false | Indicates that test suite conducts only installation. Is recommended to be used for all jobs which create and publish images
INSTLANG | string | en_US | Installation locale settings.
IPXE | boolean | false | Indicates ipxe boot.
ISO_MAXSIZE | integer | | Max size of the iso, used in `installation/isosize.pm`.
IS_MM_SERVER | boolean | | If set, run server-specific part of the multimachine job
KEEP_ONLINE_REPOS | boolean | false | openSUSE specific variable, not to replace original repos in the installed system with snapshot mirrors which are not yet published.
LAPTOP |||
LINUX_BOOT_IPV6_DISABLE | boolean | false | If set, boots linux kernel with option named "ipv6.disable=1" which disables IPv6 from startup.
LINUXRC_KEXEC | integer | | linuxrc has the capability to download and run a new kernel and initrd pair from the repository.<br> There are four settings for the kexec option:<br> 0: feature disabled;<br> 1: always restart with kernel/initrd from repository (without bothering to check if it's necessary);<br>2: restart only if needed - that is, if linuxrc detects that the booted initrd is outdated (this is the default);<br>3: like kexec=2 but without user interaction.<br> *More details [here](https://en.opensuse.org/SDB:Linuxrc)*.
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
NFSCLIENT | boolean | false | Indicates/enables nfs client in `console/yast2_nfs_client` for multi-machine test.
NFSSERVER | boolean | false | Indicates/enables nfs server in `console/yast2_nfs_server`.
NICEVIDEO |||
NICTYPE_USER_OPTIONS | string | | `hostname=myguest` causes a fake DHCP hostname 'myguest' provided to SUT. It is used as expected hostname if `EXPECTED_INSTALL_HOSTNAME` is not set.
NOAUTOLOGIN | boolean | false | Indicates disabled auto login.
NOIMAGES |||
NOLOGS | boolean | false | Do not collect logs if set to true. Handy during development.
OPT_KERNEL_PARAMS | string | Specify optional kernel command line parameters on bootloader settings page of the installer.
PERF_KERNEL | boolean | false | Enables kernel performance testing.
PERF_INSTALL | boolean | false | Enables kernel performance testing installation part.
PERF_SETUP | boolean | false | Enables kernel performance testing deployment part.
PERF_RUNCASE | boolean | false | Enables kernel performance testing run case part.
PKGMGR_ACTION_AT_EXIT | string | "" | Set the default behavior of the package manager when package installation has finished. Possible actions are: close, restart, summary. If PKGMGR_ACTION_AT_EXIT is not set in openQA, test module will read the default value from /etc/sysconfig/yast2.
PXE_PRODUCT_NAME | string | false | Defines image name for PXE booting
QA_TESTSUITE | string | | Comma or semicolon separated a list of the automation cases' name, and these cases will be installed and triggered if you call "start_testrun" function from qa_run.pm
RAIDLEVEL | integer | | Define raid level to be configured. Possible values: 0,1,5,6,10.
REBOOT_TIMEOUT | integer | Set and handle reboot timeout available in YaST installer. 0 disables the timeout and needs explicit reboot confirmation.
REGRESSION | string | | Define scope of regression testing, including ibus, gnome, documentation and other.
REMOTE_REPOINST | boolean | | Use linuxrc features to install OS from specified repository (install) while booting installer from DVD (instsys)
REPO_* | string | | Url pointing to the mirrored repo. REPO_0 contains installation iso.
RESCUECD | boolean | false | Indicates rescue image to be used.
RESCUESYSTEM | boolean | false | Indicates rescue system under test.
ROOTONLY | boolean | false | Request installation to create only the root account, no user account.
RESET_HOSTNAME| boolean | false | If set to true content of /etc/hostname file will be erased
SCC_ADDONS | string | | Comma separated list of modules to be enabled using SCC/RMT.
SCC_DOCKER_IMAGE | string | | The content of /etc/zypp/credentials.d/SCCcredentials used by container-suseconnect-zypp zypper service in SLE base container images
SELECT_FIRST_DISK | boolean | false | Enables test module to select first disk for the installation. Is used for baremetal machine tests with multiple disks available, including cases when server still has previous installation.
SEPARATE_HOME | three-state | undef | Used for scheduling the test module where separate `/home` partition should be explicitly enabled (if `1` is set) or disabled (if `0` is set). If not specified, the test module is skipped.
SES5_CEPH_QA_HEALTH_OK | string | | URL for repo containing ceph-qa-health-ok package.
SKIP_CERT_VALIDATION | boolean | false | Enables linuxrc parameter to skip certificate validation of the remote source, e.g. when using self-signed https url.
SET_CUSTOM_PROMPT | boolean | false | Set a custom, shorter prompt in shells. Saves screen space but can take time to set repeatedly in all shell sessions.
SLE_PRODUCT | string | | Defines SLE product. Possible values: `sles`, `sled`, `sles4sap`. Is mainly used for SLE 15 installation flow.
SOFTFAIL_BSC1063638 | boolean | false | Enable bsc#1063638 detection.
STAGING | boolean | false | Indicates staging environment.
SPECIFIC_DISK | boolean | false | Enables installation/partitioning_olddisk test module.
SPLITUSR | boolean | false | Enables `installation/partitioning_splitusr` test module.
SUSEMIRROR | string | | Mirror url of the installation medium.
SYSAUTHTEST | boolean | false | Enable system authentication test (`sysauth/sssd`)
TEST | string | | Name of the test suite.
TOGGLEHOME | boolean | false | Changes the state of partitioning to have or not to have separate home partition in the proposal.
TUNNELED | boolean | false | Enables the use of normal consoles like "root-consoles" on a remote SUT while configuring the tunnel in a local "tunnel-console"
TYPE_BOOT_PARAMS_FAST | boolean | false | When set, forces `bootloader_setup::type_boot_parameters` to use the default typing interval.
UEFI | boolean | false | Indicates UEFI in the testing environment.
UPGRADE | boolean | false | Indicates upgrade scenario.
USBBOOT | boolean | false | Indicates booting to the usb device.
USEIMAGES |||
VALIDATE_ETC_HOSTS | boolean | false | Validate changes in /etc/hosts when using YaST network module. Is used in yast2_lan and yast2_lan_restart test modules which test module in ncurses and x11 respectively.
VALIDATE_INST_SRC | boolean | false | Validate installation source in /etc/install.inf
VALIDATE_CHECKSUM | boolean | false | Validate checksum of the mediums. Also see CHECKSUM_*.
VERSION | string | | Contains major version of the product. E.g. 15-SP1 or 15.1
VIDEOMODE | string | | Indicates/defines video mode used for the installation. Empty value uses default, other possible values `text`, `ssh-x` for installation ncurses and x11 over ssh respectivelyю
VIRSH_OPENQA_BASEDIR | string | /var/lib | The OPENQA_BASEDIR configured on the svirt host (only relevant for the svirt backend).
UNENCRYPTED_BOOT | boolean | false | Indicates/defines existence of unencrypted boot partition in the SUT.
WAYLAND | boolean | false | Enables wayland tests in the system.
XDMUSED | boolean | false | Indicates availability of xdm.
YAML_SCHEDULE | string | | Defines yaml file containing test suite schedule.
YAML_TEST_DATA | string | | Defines yaml file containing test data.
YAST2_FIRSTBOOT_USERNAME | string | | Defines username for the user to be created with YaST Firstboot
ZDUP | boolean | false | Prescribes zypper dup scenario.
ZDUPREPOS | string | | Comma separated list of repositories to be added/used for zypper dup call, defaults to SUSEMIRROR or attached media, e.g. ISO.
LINUXRC_BOOT | boolean | true | To be used only in scenarios where we are booting an installed system from the installer medium (for example, a DVD) with the menu option "Boot Linux System" (not "boot From Hard Disk"). This option uses linuxrc.
ZYPPER_WHITELISTED_ORPHANS | string | empty | Whitelist expected orphaned packages, do not fail if any are found. Upgrade scenarios are expecting orphans by default. Used by console/orphaned_packages_check.pm
