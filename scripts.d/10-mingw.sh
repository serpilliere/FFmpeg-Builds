#!/bin/bash

SCRIPT_REPO="https://git.code.sf.net/p/mingw-w64/mingw-w64.git"
SCRIPT_COMMIT="57f796c80bfac3c75725e4e7a086afe43968b3ae"

ffbuild_enabled() {
    [[ $TARGET == win* ]] || return -1
    return 0
}

ffbuild_dockerlayer() {
    to_df "COPY --from=${SELFLAYER} /opt/mingw/. /"
    to_df "COPY --from=${SELFLAYER} /opt/mingw/. /opt/mingw"
}

ffbuild_dockerfinal() {
    to_df "COPY --from=${PREVLAYER} /opt/mingw/. /"
}

ffbuild_dockerdl() {
    echo "retry-tool sh -c \"rm -rf mingw && git clone '$SCRIPT_REPO' mingw\" && cd mingw && git checkout \"$SCRIPT_COMMIT\""
}

ffbuild_dockerbuild() {
    cat <<EOF >/tmp/patch_mingw
--- ./mingw-w64-crt/ssp/stack_chk_guard.c       2024-03-15 09:37:14.885149044 +0100
+++ ./mingw-w64-crt/ssp/stack_chk_guard.c   2024-03-15 09:55:38.354206697 +0100
@@ -22,6 +22,7 @@
   // In the case of msvcrt.dll, our import library provides a small wrapper
   // which tries to load the function dynamically, and falls back on
   // using RtlRandomGen if not available.
+  /*
   if (rand_s(&ui) == 0) {
     __stack_chk_guard = (void*)(intptr_t)ui;
 #if __SIZEOF_POINTER__ > 4
@@ -30,11 +31,14 @@
 #endif
     return;
   }
-
+  */
+  __stack_chk_guard = (void*)0x11223344;
+  /*
   // If rand_s failed (it shouldn't), hardcode a nonzero default stack guard.
 #if __SIZEOF_POINTER__ > 4
   __stack_chk_guard = (void*)0xdeadbeefdeadbeefULL;
 #else
   __stack_chk_guard = (void*)0xdeadbeef;
 #endif
+  */
 }
EOF
    patch -p0 < /tmp/patch_mingw


    cd mingw-w64-headers

    unset CFLAGS
    unset CXXFLAGS
    unset LDFLAGS
    unset PKG_CONFIG_LIBDIR

    GCC_SYSROOT="$(${FFBUILD_CROSS_PREFIX}gcc -print-sysroot)"

    local myconf=(
        --prefix="$GCC_SYSROOT/usr/$FFBUILD_TOOLCHAIN"
        --host="$FFBUILD_TOOLCHAIN"
        --with-default-win32-winnt="0x601"
        --with-default-msvcrt=ucrt
        --enable-idl
    )

    ./configure "${myconf[@]}"
    make -j$(nproc)
    make install DESTDIR="/opt/mingw"

    cd ../mingw-w64-libraries/winpthreads

    local myconf=(
        --prefix="$GCC_SYSROOT/usr/$FFBUILD_TOOLCHAIN"
        --host="$FFBUILD_TOOLCHAIN"
        --with-pic
        --disable-shared
        --enable-static
    )

    ./configure "${myconf[@]}"
    make -j$(nproc)
    make install DESTDIR="/opt/mingw"
}

ffbuild_configure() {
    echo --disable-w32threads --enable-pthreads
}
