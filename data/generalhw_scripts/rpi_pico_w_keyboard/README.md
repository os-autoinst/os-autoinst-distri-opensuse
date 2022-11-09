# RPi Pico W Keyboard

This software allows to use a RPi Pico W microcontroller to be connected
to a SUT via USB and emulate a keyboard.
It will connect to the openQA-worker wifi and accept keyboard combinations
compatible to qemu syntax via HTTP that are then sent to the SUT.

## Installation on device

1. Install the Arduino IDE (there is an RPM in the repos, but if it has issues, use the appimage from github)
2. Add the board url in the preferences: `https://github.com/earlephilhower/arduino-pico/releases/download/global/package_rp2040_index.json`
3. Install the Raspberry Pi Pico (RP2040) board files via Board Manager and select `Raspberry Pi Pico W` board
4. Hold the `BOOTSEL` button on the board while connecting it which will put it into programming mode
5. After a few seconds the board will appear under Tools->Port as `UF2 Board` - select that
6. Set the correct wifi password via the `STAPSK` define
7. Press *Upload*
