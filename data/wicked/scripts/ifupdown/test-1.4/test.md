Team on physical interfaces

---

### tree:
```
    eth1,eth2   -m->    team0
```

---

### ifup:

#### wicked ifup eth1

    - setup    eth1                requested
      - setup    team0             required master reference
    - skip     eth2                unrequested / not required by setup interfaces

#### wicked ifup eth2

    - setup    eth2                requested
      - setup    team0             required master reference
    - skip     eth1                unrequested / not required by setup interfaces

#### wicked ifup team0

    - setup    team0               requested
      - setup    eth1              via ports trigger
      - setup    eth2              via ports trigger

    trigger: ports=disabed

    - setup    team0               requested
    - skip     eth1                unrequested / not required by setup interfaces
    - skip     eth2                unrequested / not required by setup interfaces

---

### ifdown:

#### wicked ifdown eth1

    - shutdown eth1                requested
    - skip     eth2                unrequested / no reference to shutdown interfaces
    - skip     team0               unrequested / no reference to shutdown interfaces

#### wicked ifdown eth2

    - shutdown eth2                requested
    - skip     eth1                unrequested / no reference to shutdown interfaces
    - skip     team0               unrequested / no reference to shutdown interfaces

#### wicked ifdown team0

    - shutdown team0               requested
      - shutdown eth1              depends on master shutdown
      - shutdown eth2              depends on master shutdown

