#!/bin/bash
source "$(dirname "$BASH_SOURCE")"/defaults-gpl.sh
FF_CONFIGURE+=" --enable-shared --disable-static --disable-opencl --disable-mediafoundation --disable-amf --disable-indevs --disable-network"
