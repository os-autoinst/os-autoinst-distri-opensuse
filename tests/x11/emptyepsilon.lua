use("testapi")
use("x11test")

function run(self)
  ensure_installed('emptyepsilon')
  x11_start_program('EmptyEpsilon')
  send_key("alt-f4")
end
