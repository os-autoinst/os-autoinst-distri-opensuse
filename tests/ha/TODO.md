- Change cLVM test to use a bigger size in 'dd'
- Change OCFS2 test to use clustered VG/LV if cLVM test is used (detection?)
- Improve DRBD test by adding a filesystem ontop of it and write/compare data,
  and by also adding (c)LVM ontop of DRBD device
- Add cluster-md test
- Add upgrade/update test from SPn-1 to SPn version of SLE:
  * update SPn-1 to latest version
  * upgrade SPn-1 to SPn
  * execute all HA tests to validate the upgrade
