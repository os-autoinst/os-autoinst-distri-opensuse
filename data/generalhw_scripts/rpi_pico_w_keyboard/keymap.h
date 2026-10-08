/*
# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-3.0-or-later
*/

#include <Keyboard.h>

// Translate qemu key commands to arduino Keyboard.h keycodes
// see https://www.arduino.cc/reference/en/language/functions/usb/keyboard/keyboardmodifiers/
// and https://en.wikibooks.org/wiki/QEMU/Monitor#sendkey_keys
uint8_t get_key(String key) {
  if (key.length() == 1)         return key.c_str()[0];
  
  else if (key == "ctrl")        return KEY_LEFT_CTRL;
  else if (key == "ctrl_r")      return KEY_RIGHT_CTRL;
  else if (key == "alt")         return KEY_LEFT_ALT;
  else if (key == "alt_r")       return KEY_RIGHT_ALT;
  else if (key == "shift")       return KEY_LEFT_SHIFT;
  else if (key == "shift_r")     return KEY_RIGHT_SHIFT;
  else if (key == "super")       return KEY_LEFT_GUI;    // "windows key"
  else if (key == "super_r")     return KEY_RIGHT_GUI;   // "windows key"
  

  else if (key == "up")          return KEY_UP_ARROW;
  else if (key == "down")        return KEY_DOWN_ARROW;
  else if (key == "left")        return KEY_LEFT_ARROW;
  else if (key == "right")       return KEY_RIGHT_ARROW;

  else if (key == "backspace")   return KEY_BACKSPACE;
  else if (key == "tab")         return KEY_TAB;
  else if (key == "ret")         return KEY_RETURN;
  else if (key == "menu")        return KEY_MENU;
  else if (key == "esc")         return KEY_ESC;

  else if (key == "insert")      return KEY_INSERT;
  else if (key == "delete")      return KEY_DELETE;
  else if (key == "pgup")        return KEY_PAGE_UP;
  else if (key == "pgdn")        return KEY_PAGE_DOWN;
  else if (key == "home")        return KEY_HOME;
  else if (key == "end")         return KEY_END;
  
  else if (key == "print")       return KEY_PRINT_SCREEN;
  else if (key == "scroll_lock") return KEY_SCROLL_LOCK;
  else if (key == "caps_lock")   return KEY_CAPS_LOCK;
  else if (key == "num_lock")    return KEY_NUM_LOCK;

  else if (key == "kp_divide")   return KEY_KP_SLASH;
  else if (key == "kp_multiply") return KEY_KP_ASTERISK;
  else if (key == "kp_subtract") return KEY_KP_MINUS;
  else if (key == "kp_add")      return KEY_KP_PLUS;
  else if (key == "kp_enter")    return KEY_KP_ENTER;
  else if (key == "kp_decimal")  return KEY_KP_DOT;
  else if (key == "kp_0")        return KEY_KP_0;
  else if (key == "kp_1")        return KEY_KP_1;
  else if (key == "kp_2")        return KEY_KP_2;
  else if (key == "kp_3")        return KEY_KP_3;
  else if (key == "kp_4")        return KEY_KP_4;
  else if (key == "kp_5")        return KEY_KP_5;
  else if (key == "kp_6")        return KEY_KP_6;
  else if (key == "kp_7")        return KEY_KP_7;
  else if (key == "kp_8")        return KEY_KP_8;
  else if (key == "kp_9")        return KEY_KP_9;

  else if (key == "f1")          return KEY_F1;
  else if (key == "f2")          return KEY_F2;
  else if (key == "f3")          return KEY_F3;
  else if (key == "f4")          return KEY_F4;
  else if (key == "f5")          return KEY_F5;
  else if (key == "f6")          return KEY_F6;
  else if (key == "f7")          return KEY_F7;
  else if (key == "f8")          return KEY_F8;
  else if (key == "f9")          return KEY_F9;
  else if (key == "f10")         return KEY_F10;
  else if (key == "f11")         return KEY_F11;
  else if (key == "f12")         return KEY_F12;
  else if (key == "f13")         return KEY_F13;
  else if (key == "f14")         return KEY_F14;
  else if (key == "f15")         return KEY_F15;
  else if (key == "f16")         return KEY_F16;
  else if (key == "f17")         return KEY_F17;
  else if (key == "f18")         return KEY_F18;
  else if (key == "f19")         return KEY_F19;
  else if (key == "f20")         return KEY_F20;
  else if (key == "f21")         return KEY_F21;
  else if (key == "f22")         return KEY_F22;
  else if (key == "f23")         return KEY_F23;
  else if (key == "f24")         return KEY_F24;

  else if (key == "minus")       return '-';
  else if (key == "equal")       return '=';
  else if (key == "comma")       return ',';
  else if (key == "dot")         return '.';
  else if (key == "slash")       return '/';
  else if (key == "asterisk")    return '*';
  else if (key == "spc")         return ' ';
  
  return 0x00;  
}
