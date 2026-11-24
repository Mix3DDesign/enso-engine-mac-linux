# Ensō Engine for macOS and Linux

This repository builds the free **Ensō Engine** (an anime and NPR build of Blender 5.3 by
Mix 3D Design) for macOS (Apple Silicon) and Linux, using GitHub Actions.

- Source: [Mix3DDesign/enso-engine](https://github.com/Mix3DDesign/enso-engine), branch `enso-engine`.
- `patches/`: the newest engine changes, applied on top of that source.
- `files/`: files copied over the source after the patches.
- `linux/`: the Linux build (an older Rocky Linux 8 system, so it runs on more computers) and the
  files that go in the Linux download.
- `branding/`: the Ensō icon.

Every push that changes the patches starts both builds. The finished downloads are kept for a
few days under the run's Artifacts.

Ensō Engine is free software under the GNU General Public License (GPL 2.0 or later), like Blender.
Only the free engine is built here.

Website: https://enso.mix3ddesign.com
