#!/bin/bash
# Runs inside a Rocky Linux 8 container, the same old system official Blender releases are built on,
# so the result starts on older Linux systems too.
#   KIND=main    builds Enso Engine itself (GPU kernels come from the other jobs)
#   KIND=nvidia  builds only the Cycles NVIDIA kernels named in TARGETS
#   KIND=amd     builds only the Cycles AMD kernels for the cards in HIP_ARCHS
set -e
KIND="${KIND:-main}"
echo "PART: $KIND $TARGETS $HIP_ARCHS"
dnf -y -q install 'dnf-command(config-manager)' 'dnf-command(versionlock)' > /dev/null
dnf config-manager --set-enabled powertools
dnf -y -q install epel-release > /dev/null
dnf -y -q install scl-utils gcc-toolset-14 > /dev/null
dnf -y -q install git make gcc-c++ ccache wget python3 patchelf findutils which unzip xz \
  mesa-libEGL-devel mesa-libGL-devel mesa-libGLU-devel libxkbcommon-devel \
  libX11-devel libXcursor-devel libXi-devel libXinerama-devel libXrandr-devel libXt-devel libXxf86vm-devel \
  libXfixes-devel libXrender-devel alsa-lib-devel pulseaudio-libs-devel jack-audio-connection-kit-devel > /dev/null
cd /tmp
wget -q https://github.com/Kitware/CMake/releases/download/v3.31.12/cmake-3.31.12-linux-x86_64.sh
sh cmake-3.31.12-linux-x86_64.sh --prefix=/usr --skip-license > /dev/null
rm -f cmake-3.31.12-linux-x86_64.sh

# Rocky 8's own ninja is too old for Blender (needs 1.10 or newer), so build a current one.
git clone -q --depth 1 --branch v1.12.1 https://github.com/ninja-build/ninja.git /tmp/ninja-src
cmake -S /tmp/ninja-src -B /tmp/ninja-src/b -DBUILD_TESTING=OFF -DCMAKE_BUILD_TYPE=Release > /dev/null
cmake --build /tmp/ninja-src/b -j"$(nproc)" > /dev/null
install -m 755 /tmp/ninja-src/b/ninja /usr/local/bin/ninja
export PATH=/usr/local/bin:$PATH
echo "NINJA $(ninja --version)"

# OptiX headers (published by NVIDIA). The engine needs them for the OptiX render device,
# the NVIDIA kernel job needs them for the OptiX kernels.
git clone -q --depth 1 --branch v9.1.0 https://github.com/NVIDIA/optix-dev.git /opt/optix \
  || git clone -q --depth 1 https://github.com/NVIDIA/optix-dev.git /opt/optix
test -f /opt/optix/include/optix.h

GPU_FLAGS=""
if [ "$KIND" = "nvidia" ]; then
  dnf config-manager --add-repo http://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/cuda-rhel8.repo
  dnf versionlock add 'cuda-*-12-8*' > /dev/null
  dnf -y -q install cuda-toolkit-12-8 > /dev/null
  export PATH=/usr/local/cuda-12.8/bin:/usr/local/cuda/bin:$PATH
  export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
  echo "NVIDIA COMPILER: $(nvcc --version | tail -1)"
  GPU_FLAGS="-DWITH_CYCLES_CUDA_BINARIES=ON -DWITH_CYCLES_HIP_BINARIES=OFF -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda-12.8"
elif [ "$KIND" = "amd" ]; then
  rpm --import https://repo.radeon.com/rocm/rocm.gpg.key
  cat > /etc/yum.repos.d/graphics-7.2.1.repo <<REPO
[graphics-7.2.1]
name=graphics-7.2.1
baseurl=https://repo.radeon.com/graphics/7.2.1/el/8.10/main/x86_64/
enabled=1
priority=50
gpgcheck=1
gpgkey=https://repo.radeon.com/rocm/rocm.gpg.key
REPO
  cat > /etc/yum.repos.d/rocm-7.2.1.repo <<REPO
[ROCm-7.2.1]
name=ROCm-7.2.1
baseurl=https://repo.radeon.com/rocm/el8/7.2.1/main
enabled=1
gpgcheck=1
exclude=rock-dkms
gpgkey=https://repo.radeon.com/rocm/rocm.gpg.key
REPO
  dnf -y -q install hipcc7.2.1 hip-devel7.2.1 rocm-llvm7.2.1 rocm-core7.2.1 rocm-device-libs7.2.1 > /dev/null
  update-alternatives --set rocm /opt/rocm-7.2.1 || true
  export PATH=/opt/rocm-7.2.1/bin:$PATH
  export HIP_PATH=/opt/rocm-7.2.1
  echo "AMD COMPILER: $(hipcc --version 2>&1 | grep -i -m1 'HIP version')"
  GPU_FLAGS="-DWITH_CYCLES_CUDA_BINARIES=OFF -DWITH_CYCLES_HIP_BINARIES=ON -DWITH_CYCLES_DEVICE_HIPRT=ON -DHIP_ROOT_DIR=/opt/rocm-7.2.1 -DCYCLES_HIP_BINARIES_ARCH=$HIP_ARCHS"
else
  GPU_FLAGS="-DWITH_CYCLES_CUDA_BINARIES=OFF -DWITH_CYCLES_HIP_BINARIES=OFF"
fi

set +e
source scl_source enable gcc-toolset-14
set -e
echo "BUILD SYSTEM: $(cat /etc/rocky-release)"
gcc --version | head -1
ldd --version | head -1
free -g | head -2
df -h / | tail -1
git config --global --add safe.directory '*'

mkdir -p /w/build
cd /w/build
cmake -G Ninja -DCMAKE_MAKE_PROGRAM=/usr/local/bin/ninja -C /w/src/build_files/cmake/config/blender_release.cmake \
  -DCMAKE_BUILD_TYPE=Release -DWITH_COMPILER_CCACHE=ON -DWITH_GHOST_WAYLAND_APP_ID=enso-engine \
  -DOPTIX_ROOT_DIR=/opt/optix -DWITH_CYCLES_PARALLEL_DEVICE_KERNEL_BUILD=ON $GPU_FLAGS /w/src > /w/configure_log.txt 2>&1 \
  || { tail -60 /w/configure_log.txt; exit 1; }
grep -i -E "optix|cuda|hip|oneapi" /w/configure_log.txt | head -20
echo "CYCLES GPU SETTINGS"
grep -E "^(WITH_CYCLES_(CUDA_BINARIES|HIP_BINARIES|ONEAPI_BINARIES|DEVICE_[A-Z]+)|CUDA_NVCC_EXECUTABLE|HIP_HIPCC_EXECUTABLE|OPTIX_INCLUDE_DIR|CYCLES_(CUDA|HIP)_BINARIES_ARCH)[:A-Z_]*=" CMakeCache.txt || true
ccache -M 4G > /dev/null

# Parallel jobs: GPU kernels need a lot of memory each, so fit them to the machine.
MEM_GB=$(free -g | awk '/Mem:/{print $2}')
if [ "$KIND" = "main" ]; then
  J=$(nproc); WHAT="install"
else
  J=$(( MEM_GB / 5 )); [ "$J" -lt 1 ] && J=1; [ "$J" -gt "$(nproc)" ] && J=$(nproc)
  WHAT="$TARGETS"
fi
echo "BUILDING: $WHAT with $J jobs ($MEM_GB GB memory, $(nproc) cores)"

set +e
ninja -j"$J" $WHAT 2>&1 | tee /w/build_log.txt | grep --line-buffered -E "^\[[0-9]+/[0-9]+\]|error|Error|FAILED|Killed" | awk 'NR % 25 == 1 || /rror|FAILED|Killed/ || /kernel_/'
RC=${PIPESTATUS[0]}
set -e

if [ "$KIND" != "main" ]; then
  mkdir -p /w/kernels
  find /w/build/intern/cycles/kernel -name "kernel_*.zst" -exec cp {} /w/kernels/ \;
  echo "KERNELS MADE"; ls -la /w/kernels
fi
ccache -s | head -8
chown -R "$HOST_UID:$HOST_GID" /w/build /w/build_log.txt /w/configure_log.txt /w/kernels /ccache 2>/dev/null || true
exit $RC
