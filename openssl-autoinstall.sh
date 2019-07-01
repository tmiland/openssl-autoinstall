#!/usr/bin/env bash


## Author: Tommy Miland (@tmiland) - Copyright (c) 2019


######################################################################
####                    OpenSSL AutoInstall                       ####
####            Automatic install script for OpenSSL              ####
####                   Maintained by @tmiland                     ####
######################################################################


version='1.0.0'

#------------------------------------------------------------------------------#
#
# MIT License
#
# Copyright (c) 2019 Tommy Miland
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#------------------------------------------------------------------------------#
## Uncomment for debugging purpose
#set -o errexit
#set -o pipefail
#set -o nounset
#set -o xtrace

# Make sure that the script runs with root permissions
chk_permissions() {
  if [[ "$EUID" != 0 ]]; then
    echo -e "${RED}${ERROR} This action needs root permissions.${NC} Please enter your root password...";
    cd "$CURRDIR"
    su -s "$(which bash)" -c "./$SCRIPT_FILENAME"
    cd - > /dev/null

    exit 0;
  fi
}

if [[ $(lsb_release -si) == "Debian" || $(lsb_release -si) == "Ubuntu" ]]; then
  export DEBIAN_FRONTEND=noninteractive
  SUDO="sudo"
  UPDATE="apt-get -o Dpkg::Progress-Fancy="1" update -qq"
  INSTALL="apt-get -o Dpkg::Progress-Fancy="1" install -qq"
  PKGCHK="dpkg -s"
  # Pre-install packages
  PRE_INSTALL_PKGS="apt-transport-https git curl sudo"
  # Build-dep packages
  BUILD_DEP_PKGS="build-essential ca-certificates wget libssl-dev libpcre3 libpcre3-dev autoconf unzip automake libtool tar zlib1g-dev uuid-dev lsb-release make"
else
  echo -e "${RED}${ERROR} Error: Sorry, your OS is not supported.${NC}"
  exit 1;
fi

# Detect absolute and full path as well as filename of this script
cd "$(dirname $0)"
CURRDIR=$(pwd)
SCRIPT_FILENAME=$(basename $0)
cd - > /dev/null
sfp=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || greadlink -f "${BASH_SOURCE[0]}" 2>/dev/null)
if [ -z "$sfp" ]; then sfp=${BASH_SOURCE[0]}; fi
SCRIPT_DIR=$(dirname "${sfp}")
# Icons used for printing
ARROW='➜'
DONE='✔'
ERROR='✗'
WARNING='⚠'
# Colors used for printing
RED='\033[0;31m'
BLUE='\033[0;34m'
BBLUE='\033[1;34m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
DARKORANGE="\033[38;5;208m"
CYAN='\033[0;36m'
DARKGREY="\033[48;5;236m"
NC='\033[0m' # No Color
# Text formatting used for printing
BOLD="\033[1m"
DIM="\033[2m"
UNDERLINED="\033[4m"
INVERT="\033[7m"
HIDDEN="\033[8m"
# Script name
SCRIPT_NAME="openssl-autoinstall.sh"
# If you want to download a new version just change the OpenSSL version below.
OPENSSL_VERSION="1.1.1c"

# Header
header() {
  echo -e "${GREEN}\n"
  echo ' ╔═══════════════════════════════════════════════════════════════════╗'
  echo ' ║                        '${SCRIPT_NAME}'                     ║'
  echo ' ║                 Automatic install script for OpenSSL              ║'
  echo ' ║                      Maintained by @tmiland                       ║'
  echo ' ║                          version: '${version}'                           ║'
  echo ' ╚═══════════════════════════════════════════════════════════════════╝'
  echo -e "${NC}"
}

main() {
  if [[ $(lsb_release -si) == "Debian" || $(lsb_release -si) == "Ubuntu" ]]; then

    # Setup Dependencies
    if ! ${PKGCHK} $PRE_INSTALL_PKGS >/dev/null 2>&1; then
      ${UPDATE}
      for i in $PRE_INSTALL_PKGS; do
        ${INSTALL} $i 2> /dev/null
      done
    fi

    if ! ${PKGCHK} $BUILD_DEP_PKGS >/dev/null 2>&1; then
      ${SUDO} ${UPDATE}
      for i in $BUILD_DEP_PKGS; do
        ${SUDO} ${INSTALL} $i 2> /dev/null # || exit 1 #--allow-unauthenticated
      done
    fi

    chk_permissions
    # Switch to /usr/local/src and download the source package.
    cd /usr/local/src
    wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz

    # Extract the archive and move into the folder.
    tar -xvzf openssl-${OPENSSL_VERSION}.tar.gz
    cd openssl-${OPENSSL_VERSION}

    ${SUDO} ./config --prefix=/usr/local/openssl-${OPENSSL_VERSION} --openssldir=/usr/local/openssl-${OPENSSL_VERSION}
    make
    # Continue with install only if test succeeds
    make test && ${SUDO} make install

    # Create a symbolic link that points /usr/local/openssl to /usr/local/openssl-${OPENSSL_VERSION}
    # This need to be done and if you have more than one installation of OpenSSL on your system you could easily switch just create a symbolic link.
    ${SUDO} ln -s openssl-${OPENSSL_VERSION} /usr/local/openssl

    # Execute the following lines to update your Bash startup script.
    echo 'export PATH=/usr/local/openssl/bin:$PATH' >> ~/.bash_profile
    echo 'export MANPATH=/usr/local/openssl/ssl/man:$MANPATH' >> ~/.bash_profile
    echo 'export LD_LIBRARY_PATH=/usr/local/openssl/lib' >> ~/.bash_profile

    # Load the new shell configurations.
    source ~/.bash_profile

    # Execute the following lines to install the certificates.
    # ${SUDO} security find-certificate -a -p /Library/Keychains/System.keychain > /usr/local/openssl/ssl/cert.pem
    # ${SUDO} security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain >> /usr/local/openssl/ssl/cert.pem

    # Take out the garbage
    cd /usr/local/src
    ${SUDO} rm openssl-${OPENSSL_VERSION}.tar.gz
    ${SUDO} rm -rf openssl-${OPENSSL_VERSION}
    echo -e "${GREEN}${DONE} OpenSSL has been successfully installed!${NC}"
    openssl version -a
  else
    echo -e "${RED}${ERROR} Error: Sorry, your OS is not supported.${NC}"
    exit 1;
  fi
}
header
main $@
exit 0
