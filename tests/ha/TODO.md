- Add a 'remove node' test after fencing (for 2 nodes cluster or more, so the node02 will always be removed), need to be tested with both hostname and IP address
- Add a 'remove all resources but stonith' test to be able to clear the cluster configuration at the end. This will let us the option to re-use the VMs for SAPA HANA tests for example
- Add a DRBD active/active test + cLVM ontop of a DRBD device
- Add upgrade/update test from SPn-1 to SPn version of SLE:
  * update SPn-1 to latest version
  * upgrade SPn-1 to SPn
  * execute all HA tests to validate the upgrade
