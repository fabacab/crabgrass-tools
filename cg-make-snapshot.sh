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
#                  cd $CG_DIR; cg-make-snapshot.sh "group-name"
#
#              where $CG_DIR is the directory you want to make the
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

# For security reasons, explicitly set the internal field separator
# to newline, space, tab
readonly OLD_IFS=$IFS
IFS='
 	'

# CONSTANTS
readonly PROGRAM=`basename "$0"`
readonly VERSION="0.0.2"
readonly COOKIE_FILE=`mktemp ${PROGRAM}_cookies.XXXXX`
readonly LOGIN_PATH="/session/login"

# RETURN VALUES/EXIT STATUS CODES
readonly E_MISSING_ARG=253
readonly E_BAD_OPTION=254
readonly E_UNKNOWN=255

# DEFAULT ARGUMENTS
DEFAULT_DOWNLOAD_DIR="."
DEFAULT_BASE_URL="https://we.riseup.net"

# ARGUMENTS
BASE_URL=""
USERNAME=""
PASSWORD=""
DRY_RUN=""
SUBGROUP=0

# Function: version
#
# Uses globals:
#     $PROGRAM
#     $VERSION
function version () {
    echo "$PROGRAM version $VERSION"
}

# Function: usage
#
# Explains command line arguments.
function usage () {
    echo "Usage is as follows:"
    echo
    echo "$PROGRAM <--version>"
    echo "    Prints the program version number on a line by itself and exits."
    echo
    echo "$PROGRAM <--usage|--help|-?>"
    echo "    Prints this usage output and exits."
    echo
    echo "$PROGRAM [--username|--user|-u <user>] [--password|-p <password>]"
    echo "         [--download-directory <dir>]"
    echo "         [--base-url <url>] [--subgroup] [--dry-run]"
    echo "         <crabgrass_group> [crabgrass_group_2 [crabgrass_group_N...]]"
    echo "    Creates a static backup (an HTML snapshot) of <cg_group>."
    echo "    You can pass additional group names to snapshot them, as well."
    echo
    echo "    If '--user' is specified, does not prompt for a Crabgrass username."
    echo
    echo "    If '--password' is specified, does not prompt for a Crabgrass password."
    echo "    Note that passing password arguments on the command line is insecure and"
    echo "    may reveal your password to users on the system where $PROGRAM runs."
    echo
    echo "    If '--download-directory' is specified, all files will be downloaded to"
    echo "    the given directory. Defaults to: $DEFAULT_DOWNLOAD_DIR"
    echo
    echo "    If '--base-url' is specified, uses the Crabgrass instance running at"
    echo "    the given URL. Defaults to: $DEFAULT_BASE_URL"
    echo
    echo "    If '--subgroup' is specified, looks for committees and/or councils that"
    echo "    are associated with <crabgrass_group> and includes them in the snapshot."
    echo
    echo "    If '--dry-run' is specified, $PROGRAM echos the mirroring commands that"
    echo "    would have been run, but does not actually create a snapshot."
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
    IFS="$OLD_IFS"
}

# Function: login
#
# Logs in to the Crabgrass server.
#
# Will create a cookies file for later use in $COOKIE_FILE
function login () {
    local username="$1"
    local password="$2"
    local login_url="$3"

    local post_data="login=${username}&password=${password}"
    echo
    echo "Logging in as $USERNAME..."
    wget --quiet --save-cookies "$COOKIE_FILE" --keep-session-cookies \
        --post-data "$post_data" -O /dev/null \
            "$login_url"
}

# Function: getSubgroups
#
# Finds the URL paths of the subgroups of a given group.
#
# Outputs each found group on its own line.
function getSubgroups () {
    local group="$1"
    wget --quiet --load-cookies "$COOKIE_FILE" -O - "${BASE_URL}/${group}/" \
        | grep "href=\"/${group}+" \
            | cut -d '"' -f 2 | cut -d '/' -f 2 \
                | grep "$group" | uniq
}

# Function: mirrorGroup
#
# Downloads (mirrors) the given group.
#
# Uses globals:
#     $DRY_RUN
#     $COOKIE_FILE
#     $BASE_URL
function mirrorGroup () {
    local group="$1"
    local include_path="/${group},/groups/${group}"
    echo "Mirroring group $group..."
    $DRY_RUN wget --load-cookies "$COOKIE_FILE" --mirror \
        --include "$include_path" --convert-links --retry-connrefused \
        --directory-prefix "${DOWNLOAD_DIR}" \
        --page-requisites --html-extension "${BASE_URL}/${group}/"
}

function main () {
    # Process command line arguments.
    while test $# -gt 0; do
        if [ x"$1" == x"--" ]; then
            # detect argument termination
            shift
            break
        fi
        case $1 in
            --username | --user | -u )
                shift
                USERNAME="$1"
                shift
                ;;

            --password | -p )
                shift
                PASSWORD="$1"
                shift
                ;;

            --subgroup )
                shift
                SUBGROUP=1
                ;;

            --dry-run )
                shift
                DRY_RUN="echo"
                ;;

            --download-directory )
                shift
                DOWNLOAD_DIR="$1"
                shift
                ;;

            --base-url )
                shift
                BASE_URL="$1"
                shift
                ;;

            --version )
                version
                exit
                ;;

            -? | --usage | --help )
                usage
                exit
                ;;

            -* )
                echo "Unrecognized option: $1" >&2
                usage
                exit $E_BAD_OPTION
                ;;

            * )
                break
                ;;
        esac
    done

    # We still need group names.
    if [ $# -lt 1 ]; then
        usage
        exit $E_MISSING_ARG
    fi

    # Get Crabgrass parameters.
    if [ -z "$USERNAME" ]; then
        read -p "Username: " USERNAME
    fi
    if [ -z "$PASSWORD" ]; then
        read -s -p "Password: " PASSWORD
    fi
    if [ -z "$DOWNLOAD_DIR" ]; then
        DOWNLOAD_DIR="$DEFAULT_DOWNLOAD_DIR"
    fi
    if [ -z "$BASE_URL" ]; then
        BASE_URL="$DEFAULT_BASE_URL"
    fi

    login "$USERNAME" "$PASSWORD" "${BASE_URL}${LOGIN_PATH}"

    for group in "$@"; do
        mirrorGroup "$group"
        if [ 1 -eq $SUBGROUP ]; then
            echo "Finding subgroups for $group..."
            read -r -a subgroups <<< `getSubgroups "$group"`
            for subgroup in ${subgroups[@]}; do
                mirrorGroup "$subgroup"
            done
        fi
    done
}

main "$@"
