#!/bin/sh -x

# Copyright 2014-2016 Viktor Szakats <https://github.com/vszakats>
# See LICENSE.md

export _NAM
export _VER
export _BAS
export _DST

_NAM="$(basename "$0")"
_NAM="$(echo "${_NAM}" | cut -f 1 -d '.')"
_VER="$1"
_cpu="$2"

(
   cd "${_NAM}" || exit

   # Build

   export ARCH="w${_cpu}"
   export LIBSSH2_CFLAG_EXTRAS='-fno-ident -DHAVE_STRTOI64'
   export LIBSSH2_LDFLAG_EXTRAS='-static-libgcc -Wl,--nxcompat -Wl,--dynamicbase'
   [ "${_cpu}" = '64' ] && LIBSSH2_LDFLAG_EXTRAS="${LIBSSH2_LDFLAG_EXTRAS} -Wl,--high-entropy-va -Wl,--image-base,0x152000000"

   export ZLIB_PATH=../../zlib
   [ -d ../libressl ] && export OPENSSL_PATH=../../libressl
   [ -d ../openssl ]  && export OPENSSL_PATH=../../openssl
   if [ -n "${OPENSSL_PATH}" ] ; then
#     export LINK_OPENSSL_STATIC=yes; export OPENSSL_LIBS_STAT='crypto ssl'
      export OPENSSL_LIBPATH="${OPENSSL_PATH}"
      export OPENSSL_LIBS_DYN='crypto.dll ssl.dll'
   else
      export WITH_WINCNG=1
   fi

   export CROSSPREFIX="${_CCPREFIX}"

   (
      cd win32 || exit
      mingw32-make clean
      mingw32-make
   )

   # Make steps for determinism

   readonly _ref='NEWS'

   strip -p --enable-deterministic-archives -g win32/*.a

   ../_peclean.py "${_ref}" 'win32/*.dll'

   touch -c -r "${_ref}" win32/*.dll
   touch -c -r "${_ref}" win32/*.a

   # Create package

   _BAS="${_NAM}-${_VER}-win${_cpu}-mingw"
   [ -d ../libressl ] && _BAS="${_BAS}-libressl"
   _DST="$(mktemp -d)/${_BAS}"

   mkdir -p "${_DST}/docs"
   mkdir -p "${_DST}/include"
   mkdir -p "${_DST}/lib"
   mkdir -p "${_DST}/bin"

   (
      set +x
      for file in docs/* ; do
         if [ -f "${file}" ] && echo "${file}" | grep -v '\.' > /dev/null 2>&1 ; then
            cp -f -p "${file}" "${_DST}/${file}.txt"
         fi
      done
   )
   cp -f -p include/*.h   "${_DST}/include/"
   cp -f -p win32/*.dll   "${_DST}/bin/"
   cp -f -p win32/*.a     "${_DST}/lib/"
   cp -f -p NEWS          "${_DST}/NEWS.txt"
   cp -f -p COPYING       "${_DST}/COPYING.txt"
   cp -f -p README        "${_DST}/README.txt"
   cp -f -p RELEASE-NOTES "${_DST}/RELEASE-NOTES.txt"

   [ -d ../libressl ] && cp -f -p ../libressl/COPYING "${_DST}/COPYING-libressl.txt"
   [ -d ../openssl ]  && cp -f -p ../openssl/LICENSE  "${_DST}/LICENSE-openssl.txt"

   unix2dos -k "${_DST}"/*.txt
   unix2dos -k "${_DST}"/docs/*.txt

   ../_pack.sh "$(pwd)/${_ref}"
   ../_ul.sh
)
