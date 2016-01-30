#!/bin/bash -
#
# File:        cg-make-snapshot.sh
#
# Description: A utility script that takes a static snapshot of any
#              Crabgrass group that you have access to.
#
# Examples:    Use cg-make-snapshot.sh to create a mirror containing
#              the contents of a Crabgrass group.
#
#                  cd $BACKUP_DIR; cg-make-snapshot.sh group-name
#
#              where $BACKUP_DIR is the directory you want to make the
#              new mirror in and "group-name" is what appears in the URL
#              of your Web browser when looking at your group.
#
# License:     GPL3+
#
###############################################################################
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
###############################################################################

# Cleanup on exit, or when interrupted for any reason.
trap 'cleanup' QUIT EXIT

# Constants
readonly PROGRAM=`basename "$0"`
readonly COOKIE_FILE=`mktemp ${PROGRAM}_cookies.XXXXX`
readonly LOGIN_PATH="/session/login"

# TODO: This should be user-settable.
readonly BASE_URL="https://we.riseup.net"

# Function: login
#
# Logs in to the Crabgrass server.
#
# Will create a cookies file for later use in $COOKIE_FILE
#
# $1 username
# $2 password
# $3 login_url
function login () {
    local post_data="login=${1}&password=${2}"
    wget --save-cookies "$COOKIE_FILE" --keep-session-cookies \
        --post-data "$post_data" -O /dev/null \
            "$3"
}

# Function: cleanup
# 
# Removes cookies from the filesystem when the script terminates.
# This is important because the cookie is an authentication token and
# if it is comprmised an attacker could impersonate a legitmate user.
#
# Uses global $COOKIE_FILE
function cleanup () {
    rm -f $COOKIE_FILE
}

# Get Crabgrass parameters.
# (The crabgrass group name is passed to the script in $1.)
# TODO: Provide a non-interactive option so users can automate this.
echo -n "Username: "
read USERNAME
echo -n "Password: "
#read -s PASSWORD
read -s PASSWORD

login $USERNAME $PASSWORD "${BASE_URL}${LOGIN_PATH}"

INCLUDE_PATH="/${1},/groups/${1}"

# Download homepage.
wget --load-cookies "$COOKIE_FILE" --mirror --include "$INCLUDE_PATH" --convert-links \
    --retry-connrefused --page-requisites --html-extension "${BASE_URL}/${1}/"