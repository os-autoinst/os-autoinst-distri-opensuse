{
  iscsi(iscsi_target_address):: {
    initiator: 'iqn.1996-04.de.suse:01:972154f2547d',
    targets: [
      {
        address: iscsi_target_address,
        port: 3260,
        name: 'iqn.2016-02.openqa.de:for.openqa',
        interface: 'default',
        startup: 'automatic',
      },
    ],
  },
}
