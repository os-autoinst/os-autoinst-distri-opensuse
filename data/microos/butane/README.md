### Config usage

1. *script* is intended for combustion use cases, the script should work on all VM platforms
 - current usage:
    * QEMU all archs, however untested in PPC64
    * VMWare

2. config.fcc
 - ignition config for all QEMU VMs

3. vmware.fcc
 - ignition config for VMWare, the only difference between butane configs is the 3rd drive path by id

4. config_vmware.ign
 - JSON version of vmware.fcc as VMWare loads encoded version of this config instead of booting with a config drive as we do it for QEMU
