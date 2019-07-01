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

  chk_permissions
  # Switch to /usr/local/src and download the source package.
  cd /usr/local/src
  wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz

  # Extract the archive and move into the folder.
  tar -xvzf openssl-${OPENSSL_VERSION}.tar.gz
  cd openssl-${OPENSSL_VERSION}

  sudo ./config --prefix=/usr/local/openssl-${OPENSSL_VERSION} --openssldir=/usr/local/openssl-${OPENSSL_VERSION}
  sudo make
  # Continue with install only if test succeeds
  make test && sudo make install

  # # We need to check what kind of system you are running, 32-Bit or 64-Bit.
  # if $(uname -m | grep '64'); then
  # 	# Configure, compile and install into /usr/local/openssl-${OPENSSL_VERSION}
  # 	# This is done so that you could have multiple installations on your system.
  # 	sudo ./configure darwin64-x86_64-cc --prefix=/usr/local/openssl-${OPENSSL_VERSION}
  # 	sudo make
  # 	sudo make install
  # else
  # 	# If you are on a 32-Bit system we are doing this below.
  # 	sudo ./configure darwin-i386-cc --prefix=/usr/local/openssl-${OPENSSL_VERSION}
  # 	sudo make
  # 	sudo make install
  # fi


  # Create a symbolic link that points /usr/local/openssl to /usr/local/openssl-${OPENSSL_VERSION}
  # This need to be done and if you have more than one installation of OpenSSL on your system you could easily switch just create a symbolic link.
  sudo ln -s openssl-${OPENSSL_VERSION} /usr/local/openssl

  # Execute the following lines to update your Bash startup script.
  echo 'export PATH=/usr/local/openssl/bin:$PATH' >> ~/.bash_profile
  echo 'export MANPATH=/usr/local/openssl/ssl/man:$MANPATH' >> ~/.bash_profile
  echo 'export LD_LIBRARY_PATH=/usr/local/openssl/lib' >> ~/.bash_profile


  # Load the new shell configurations.
  source ~/.bash_profile


  # Execute the following lines to install the certificates.
  # sudo security find-certificate -a -p /Library/Keychains/System.keychain > /usr/local/openssl/ssl/cert.pem
  # sudo security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain >> /usr/local/openssl/ssl/cert.pem


  # We will also remove any remaining garbage on your system.
  cd /usr/local/src
  sudo rm openssl-${OPENSSL_VERSION}.tar.gz
  sudo rm -rf openssl-${OPENSSL_VERSION}
}
header
main $@
exit 0
