#!/usr/bin/env bash


## Author: Tommy Miland (@tmiland) - Copyright (c) 2019


######################################################################
####                    OpenSSL AutoInstall                       ####
####            Automatic install script for OpenSSL              ####
####                   Maintained by @tmiland                     ####
######################################################################


version="1.0.2"

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

# Detect absolute and full path as well as filename of this script
cd "$(dirname $0)"
CURRDIR=$(pwd)
SCRIPT_FILENAME=$(basename $0)
cd - > /dev/null
sfp=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || greadlink -f "${BASH_SOURCE[0]}" 2>/dev/null)
if [ -z "$sfp" ]; then sfp=${BASH_SOURCE[0]}; fi
SCRIPT_DIR=$(dirname "${sfp}")

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
# Repo name
REPO_NAME="tmiland/openssl-autoinstall"
# Script name
SCRIPT_NAME="openssl-autoinstall.sh"
# If you want to download a new version just change the OpenSSL version below.
OPENSSL_VERSION="1.1.1d"
# Set update check
UPDATE_SCRIPT="check"

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

##
# Download files
##
download_file () {
  declare -r url=$1
  declare -r tf=$(mktemp)
  local dlcmd=''
  dlcmd="wget -O $tf"
  $dlcmd "${url}" &>/dev/null && echo "$tf" || echo '' # return the temp-filename (or empty string on error)
}
##
# Open files
##
open_file () { #expects one argument: file_path
  if [ "$(uname)" == 'Darwin' ]; then
    open "$1"
  elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    xdg-open "$1"
  else
    echo -e "${RED}${ERROR} Error: Sorry, opening files is not supported for your OS.${NC}"
  fi
}
# Get latest release tag from GitHub
get_latest_release_tag() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" |
  grep '"tag_name":' |
  sed -n 's/[^0-9.]*\([0-9.]*\).*/\1/p'
}

RELEASE_TAG=$(get_latest_release_tag ${REPO_NAME})

# Get latest release download url
get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" |
  grep '"browser_download_url":' |
  sed -n 's#.*\(https*://[^"]*\).*#\1#;p'
}

LATEST_RELEASE=$(get_latest_release ${REPO_NAME})

# Get latest release notes
get_latest_release_note() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" |
  grep '"body":' |
  sed -n 's/.*"\([^"]*\)".*/\1/;p'
}

RELEASE_NOTE=$(get_latest_release_note ${REPO_NAME})

# Get latest release title
get_latest_release_title() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" |
  grep -m 1 '"name":' |
  sed -n 's/.*"\([^"]*\)".*/\1/;p'
}

RELEASE_TITLE=$(get_latest_release_title ${REPO_NAME})

# Header
header() {
  echo -e "${GREEN}\n"
  echo ' ╔═══════════════════════════════════════════════════════════════════╗'
  echo ' ║                      '${SCRIPT_NAME}'                       ║'
  echo ' ║                Automatic install script for OpenSSL               ║'
  echo ' ║                      Maintained by @tmiland                       ║'
  echo ' ║                          version: '${version}'                           ║'
  echo ' ╚═══════════════════════════════════════════════════════════════════╝'
  echo -e "${NC}"
  echo -e "Documentation for this script is available here: ${ORANGE}\n${ARROW} https://github.com/tmiland/openssl-autoinstall${NC}\n"
}

# Update banner
show_update_banner () {
  header
  echo "Welcome to the ${SCRIPT_NAME} script."
  echo ""
  echo "There is a newer version of ${SCRIPT_NAME} available."
  echo ""
  echo ""
  echo -e "${GREEN}${DONE} New version:${NC} "${RELEASE_TAG}" - ${RELEASE_TITLE}"
  echo ""
  echo -e "${ORANGE}${ARROW} Notes:${NC}\n"
  echo -e "${BLUE}${RELEASE_NOTE}${NC}"
  echo ""
}
##
# Returns the version number of ${SCRIPT_NAME} file on line 14
##
get_updater_version () {
  echo $(sed -n '14 s/[^0-9.]*\([0-9.]*\).*/\1/p' "$1")
}
##
# Update script
##
# Default: Check for update, if available, ask user if they want to execute it
update_updater () {
  echo -e "${GREEN}${ARROW} Checking for updates...${NC}"
  # Get tmpfile from github
  declare -r tmpfile=$(download_file "$LATEST_RELEASE")
  if [[ $(get_updater_version "${SCRIPT_DIR}/$SCRIPT_FILENAME") < "${RELEASE_TAG}" ]]; then
    if [ $UPDATE_SCRIPT = 'check' ]; then
      show_update_banner
      echo -e "${RED}${ARROW} Do you want to update [Y/N?]${NC}"
      read -p "" -n 1 -r
      echo -e "\n\n"
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        mv "${tmpfile}" "${SCRIPT_DIR}/${SCRIPT_FILENAME}"
        chmod u+x "${SCRIPT_DIR}/${SCRIPT_FILENAME}"
        "${SCRIPT_DIR}/${SCRIPT_FILENAME}" "$@" -d
        exit 1 # Update available, user chooses to update
      fi
      if [[ $REPLY =~ ^[Nn]$ ]]; then
        return 1 # Update available, but user chooses not to update
      fi
    fi
  else
    echo -e "${GREEN}${DONE} No update available.${NC}"
    return 0 # No update available
  fi
}
##
# Ask user to update yes/no
##
if [ $# != 0 ]; then
  while getopts ":ud" opt; do
    case $opt in
      u)
        UPDATE_SCRIPT='yes'
        ;;
      d)
        UPDATE_SCRIPT='no'
        ;;
      \?)
        echo -e "${RED}\n ${ERROR} Error! Invalid option: -$OPTARG${NC}" >&2
        usage
        ;;
      :)
        echo -e "${RED}${ERROR} Error! Option -$OPTARG requires an argument.${NC}" >&2
        exit 1
        ;;
    esac
  done
fi

update_updater $@
cd "$CURRDIR"
# https://github.com/tmiland/latest-release

# Exit Script
exit_script() {
  header
  echo -e "
   This script runs on coffee ☕

   ${GREEN}${DONE}${NC} ${BBLUE}Paypal${NC} ${ARROW} ${ORANGE}https://paypal.me/milanddata${NC}
   ${GREEN}${DONE}${NC} ${BBLUE}BTC${NC}    ${ARROW} ${ORANGE}3MV69DmhzCqwUnbryeHrKDQxBaM724iJC2${NC}
   ${GREEN}${DONE}${NC} ${BBLUE}BCH${NC}    ${ARROW} ${ORANGE}qznnyvpxym7a8he2ps9m6l44s373fecfnv86h2vwq2${NC}
  "
  echo -e "Documentation for this script is available here: ${ORANGE}\n${ARROW} https://github.com/tmiland/openssl-autoinstall${NC}\n"
  echo -e "${ORANGE}${ARROW} Goodbye.${NC} ☺"
  echo ""
  exit
}

main() {
  echo ""
  echo "Choose your OpenSSL implementation :"
  echo ""
  echo "   1) System's OpenSSL ($(openssl version | cut -c9-14))"
  echo ""
  echo "   2) OpenSSL $OPENSSL_VERSION from source"
  echo ""
  echo "   3) Exit"
  echo ""
  while [[ $SSL != "1" && $SSL != "2" && $SSL != "3" ]]; do
    read -p "Select an option [1-3]: " SSL
  done
  case $SSL in
    2)
      OPENSSL=y
      ;;
    3)
      exit_script
      ;;
  esac
  echo ""
  read -n1 -r -p "OpenSSL is ready to be installed, press any key to continue..."
  echo ""
  if [[ "$OPENSSL" = 'y' ]]; then
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
          ${SUDO} ${INSTALL} $i 2> /dev/null
        done
      fi

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
  fi
}
header
chk_permissions
main $@
exit 0
