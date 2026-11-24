Enso Engine 1.2 for Linux (x64)
Mix 3D Design, mix3ddesign.com

Start it
  Open this folder and run "enso-engine" (or "blender", they are the same program).
  From a terminal:  ./enso-engine

Add it to your applications menu
  Run:  ./add-to-menu.sh
  Remove it again with:  ./remove-from-menu.sh

Settings
  Enso Engine keeps its own settings in ~/.config/enso-engine
  It does not read or change the settings of a normal Blender install.

Requirements
  64 bit Linux with glibc 2.28 or newer (for example Ubuntu 20.04 or newer, Debian 11 or newer,
  Fedora, Arch, openSUSE, Linux Mint 20 or newer) and a graphics card with up to date drivers
  that supports Vulkan 1.2 or OpenGL 4.3.

If the window does not open, start it from a terminal to see the message, and try:
  ./enso-engine --gpu-backend opengl

Enso Engine is free and open source (GPL), based on Blender.
