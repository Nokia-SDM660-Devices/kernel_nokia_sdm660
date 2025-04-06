#!/bin/bash

KERNEL_NAME="RedCherry-4.4.302-NokiaSDM660"
DATE=$(date +"%d-%m-%Y-%I-%M")
FINAL_ZIP=$KERNEL_NAME-$DATE.zip

# Set defaults
COMPILER=${1:-clang}
LOG_FILE="build.log"
KERNEL_DIR="$(pwd)"

# Clone the repos
function clonning() {
    echo "Cloning toolchain for compiler: $COMPILER" | tee -a "$LOG_FILE"

    if [ ! -d "${KERNEL_DIR}/clang" ]; then
        mkdir -p clang && cd clang || exit 1
        echo "Downloading AOSP clang..." | tee -a "$LOG_FILE"
        wget "https://github.com/userariii/AOSP-clang/releases/download/clang-r498229b/clang-r498229b.tar.gz"
        tar -xvf clang*
        cd .. || exit 1
    else
        echo "Directory 'clang' already exists. Skipping download." | tee -a "$LOG_FILE"
    fi

    if [ ! -d "${KERNEL_DIR}/gcc" ]; then
        git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git --depth=1 gcc
    fi

    if [ ! -d "${KERNEL_DIR}/gcc32" ]; then
        git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git --depth=1 gcc32
    fi

    PATH="${KERNEL_DIR}/clang/bin:${KERNEL_DIR}/gcc/bin:${KERNEL_DIR}/gcc32/bin:$PATH"

    if [ ! -d AnyKernel3 ]; then
        git clone --depth=1 https://github.com/userariii/AnyKernel3.git -b NokiaSDM660
    else
        echo "Directory 'AnyKernel3' already exists. Skipping download." | tee -a "$LOG_FILE"
    fi
}

# Determine the number of threads for compilation
determine_threads() {
    echo -e "Determining no. of threads...\n"
    if [ -f /sys/devices/system/cpu/smt/active ] && [ "$(cat /sys/devices/system/cpu/smt/active)" = "1" ]; then
        export THREADS=$(expr $(nproc --all) \* 2)
    else
        export THREADS=$(nproc --all)
    fi
    echo -e "No. of threads: $THREADS\n"
}

# Clean the build environment
clean_build_environment() {
    echo -e "Cleaning the build environment...\n"
    make O=out clean
    make O=out mrproper
    echo -e "Done!\n"
}

# Configure the kernel
configure_kernel() {
    echo -e "Configuring the kernel...\n"
    make O=out ARCH=arm64 nokia_defconfig
    echo -e "Done!\n"
}

# Build the kernel
build_kernel() {
    echo -e "Building the kernel...\n"
    PATH="${KERNEL_DIR}/clang/bin:${KERNEL_DIR}/gcc/bin:${KERNEL_DIR}/gcc32/bin:$PATH" \
    make -j "$THREADS" O=out \
        ARCH=arm64 \
        CC=clang \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        CROSS_COMPILE=aarch64-linux-android- \
        CROSS_COMPILE_ARM32=arm-linux-androideabi-
    echo -e "Kernel build completed!\n"
}

# Package the kernel into a zip file
package_kernel() {
    echo -e "Packing the kernel into a zip file using AnyKernel3...\n"
    local kernel_image="${KERNEL_DIR}/out/arch/arm64/boot/Image.gz-dtb"
    local anykernel_dir="${KERNEL_DIR}/AnyKernel3"
    local kernel_builds_dir="${KERNEL_DIR}/KERNEL_BUILDS"

    cp "$kernel_image" "$anykernel_dir/" || { echo "Image.gz-dtb not found!"; exit 1; }
    mkdir -p "$kernel_builds_dir"
    cd "$anykernel_dir" || exit 1
    zip -r9 UPDATE-AnyKernel2.zip * -x README UPDATE-AnyKernel2.zip
    mv UPDATE-AnyKernel2.zip "$kernel_builds_dir/$FINAL_ZIP"
    rm -f Image.gz-dtb
    cd "$KERNEL_DIR" || exit 1
    echo -e "Done!\n"
}

# Main function
main() {
    clonning
    determine_threads
    clean_build_environment
    configure_kernel
    build_kernel
    package_kernel
}

main
