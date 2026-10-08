// Requires codetheweb/tuyapi - https://github.com/codetheweb/tuyapi
// Args:
//   * Tuya ID
//   * Tuya Key
//   * index of the plug on the smartplug to control
//   * state to change to: 'on' or 'off' (anything different from 'on' is processed as 'off')

const TuyAPI = require('tuyapi');

const device = new TuyAPI({
  id: process.argv[2],
  key: process.argv[3]});

const index = process.argv[4] || 1;
if (process.argv[5] === "on") {
  state = true;
}
else {
  state = false;
}

(async () => {
  await device.find();
  await device.connect();

  // Get current status (optional)
  let status = await device.get({dps: index});
  console.log(`Current status of plug#${index}: ${status}.`);

  // Set wanted value and check
  await device.set({set: state, dps: index});
  status = await device.get({dps: index});
  console.log(`New status of plug#${index}: ${status}.`);

  device.disconnect();
})();

