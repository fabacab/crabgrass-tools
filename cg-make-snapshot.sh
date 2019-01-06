#!/bin/bash -
#
# File:        cg-make-snapshot.sh
#
# Description: A utility script that takes a static snapshot of any
#              Crabgrass group that you have access to and optionally
#              commits the changes to a given Git repository.
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
IFS=$'\n \t'

# CONSTANTS
# TODO: These should be lower-cased so as not to conflict with
#       with any pre-existing environment variables.
readonly PROGRAM=$(basename "$0")
readonly VERSION="0.1.0"
readonly WGET="$(which wget)"
readonly COOKIE_FILE=$(mktemp "${PROGRAM}_cookies.XXXXX")
readonly LOGIN_PATH="/session/login"

# RETURN VALUES/EXIT STATUS CODES
readonly E_NONWRITABLE_DIR=250
readonly E_MISSING_SCM=251
readonly E_MISSING_WGET=252
readonly E_MISSING_ARG=253
readonly E_BAD_OPTION=254
readonly E_UNKNOWN=255

# DEFAULT ARGUMENTS
DEFAULT_BASE_URL="https://we.riseup.net"
DEFAULT_DOWNLOAD_DIR="."
DEFAULT_SCM="git"

# ARGUMENTS
# The base URL of the Crabgrass instance.
BASE_URL=""
# The username with which to log in to Crabgrass.
USERNAME=""
# The password with which to log in to Crabgrass.
PASSWORD=""
# Whether to merely echo mirroring commands or actually perform them.
DRY_RUN=""
# Custom arguments to pass to the `wget` invocation.
WGET_ARGS=""
# Whether to use `torsocks(1)` to proxy all requests via Tor.
TOR=""
# Whether to mirror Crabgrass subgroups ("committees") as well.
SUBGROUP=0
# Whether or not to enable the SCM features.
USE_SCM=0
# Which source code management system to use, if any.
SCM=""
# Arguments to pass to the chosen SCM backend, if any.
SCM_ARGS=""

# Function: version
#
# Uses globals:
#     $PROGRAM
#     $VERSION
#     $WGET
version () {
    echo "$PROGRAM version $VERSION"
    echo
    echo "Using wget at $WGET"
}

# Function: usage
#
# Explains command line arguments.
usage () {
    echo "Usage is as follows:"
    echo
    echo "$PROGRAM <--version>"
    echo "    Prints the program version number on a line by itself, along with"
    echo "    details about dependent programs, then exits."
    echo
    echo "$PROGRAM <--usage|--help|-?>"
    echo "    Prints this usage output and exits."
    echo
    echo "$PROGRAM [--username|--user|-u <user>] [--password|-p <password>]"
    echo "         [--wget-args <wget_args>] [--download-directory <dir>] [--quiet|-q]"
    echo "         [--base-url <url>] [--subgroup] [--dry-run] [--tor]"
    echo "         [--scm [git] [--scm-args <scm_args>]]"
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
    echo "    If '--wget-args' is specified, the value is passed directly to 'wget' as"
    echo "    a command-line option, allowing for (almost) arbitrary 'wget' invocations."
    echo
    echo "    If '--download-directory' is specified, all files will be downloaded to"
    echo "    the given directory. Defaults to the current working directory ('.'),"
    echo "    and is effectively a shortcut for '--wget-args \"--directory-prefix\"'."
    echo
    echo "    If '--quiet' or '-q' is specified, this argument is passed to wget at"
    echo "    runtime. By default, wget output is very loud. This is a shortcut for"
    echo "    using '--wget-args \"--quiet\", for example.'"
    echo
    echo "    If '--base-url' is specified, uses the Crabgrass instance running at"
    echo "    the given URL. Defaults to: $DEFAULT_BASE_URL"
    echo
    echo "    If '--subgroup' is specified, looks for committees and/or councils that"
    echo "    are associated with <crabgrass_group> and includes them in the snapshot."
    echo
    echo "    If '--dry-run' is specified, $PROGRAM echos the mirroring commands that"
    echo "    would have been run, but does not actually create a snapshot."
    echo
    echo "    If '--tor' is specified, $PROGRAM uses torsocks(1) to proxy all requests"
    echo "    through Tor."
    echo
    echo "    If '--scm' is specified, $PROGRAM will commit the mirror to a source code"
    echo "    version control system. If you use '--scm' you can also use '--scm-args'"
    echo "    to supply additional command line arguments to the chosen SCM backend."
    echo "    Supported SCM backends are: git (default)"
    echo "    If there is interest, I'll consider adding 'cvs', 'svn', 'hg', and 'bzr'."
    echo
    echo "EXAMPLES"
    echo
    echo "Use $PROGRAM to create a mirror containing the contents of"
    echo "the Crabgrass group 'examplegroup'. The username and password"
    echo "with which to log in will be requested interactively. The mirror"
    echo "will be created in the current directory."
    echo
    echo "    $PROGRAM examplegroup"
    echo
    echo
    echo "Mirror 'othergroup' and all its committees, but perform all"
    echo "network requests by traveling over Tor, and don't ask for a"
    echo "username interactively (use the account 'myname'). Still do"
    echo "ask for the password interactively so that it's not exposed"
    echo "via the command line)."
    echo
    echo "    $PROGRAM --tor --subgroup --user myname othergroup"
    echo
    echo
    echo "Mirror 'othergroup' and its committees by downloading files"
    echo "into the /opt/local/var/backup/crabgrass directory and then"
    echo "either create a Git repository at that location or commit"
    echo "the newly downloaded mirror as a new commit to the existing"
    echo "Git repository already storing prior backups there."
    echo
    echo "    $PROGRAM  --subgroup --scm \\"
    echo "        --scm-args '--author=\"A U Thor <a@thor.com>\"' \\"
    echo "        --download-directory /opt/local/var/backup/crabgrass \\"
    echo "        othergroup"
}

# Function: cleanup
# 
# Removes cookies from the filesystem when the script terminates.
# This is important because the cookie is an authentication token and
# if it is compromised an attacker could impersonate a legitmate user.
#
# Uses globals:
#     $COOKIE_FILE
#     $OLD_IFS
cleanup () {
    rm -f $COOKIE_FILE
    IFS="$OLD_IFS"
}

# Function: urlencode
#
# URL-encodes (percent-encodes) the given value.
# This is needed to properly send complex passwords.
urlencode () {
    local string="$1"
    echo -n "$(echo -n "$string" | \
        while IFS='' read -r -d '' -n 1 c; do \
            printf '%%%02X' "'$c"; \
        done; \
    )"
}

# Function: login
#
# Logs in to the Crabgrass server.
#
# Will create a cookies file for later use in $COOKIE_FILE
#
# Uses globals:
#    $TOR
#    $WGET
#    $COOKIE_FILE
#    $BASE_URL
login () {
    local username="$1"
    local password="$2"
    local login_url="$3"
    local html       # Acquired raw HTML
    local csrf_param # CSRF parameter name
    local token      # CSRF token value
    local post_data  # HTTP POST'ed data

    # Load remote site, get needed HTML, parse for token.
    html="$($TOR "$WGET" --save-cookies "$COOKIE_FILE" --keep-session-cookies -O - "$BASE_URL" 2>/dev/null | \
        grep -siE '(meta\s+name="csrf-param"|input\s+type="hidden")'
    )"
    csrf_param="$(echo "$html" | \
        grep -siEo 'meta\s+name="csrf-param"\s+content="\w+"' | \
            cut -d '"' -f 4 \
    )"
    token="$(echo "$html" | \
        grep -siEo "name=\"$csrf_param\"\s+value=\".*\"" | \
            cut -d '"' -f 4 \
    )"

    post_data="${csrf_param}=$(urlencode "$token")&login=${username}&password=$(urlencode "$password")"
    
    echo "Logging in as $USERNAME..."
    $TOR "$WGET" --quiet --load-cookies "$COOKIE_FILE" --save-cookies "$COOKIE_FILE" --keep-session-cookies \
        --post-data "$post_data" -O /dev/null \
            "$login_url"
}

# Function: getSubgroups
#
# Finds the URL paths of the subgroups of a given group.
#
# Outputs each found group on its own line.
getSubgroups () {
    local group="$1"
    $TOR "$WGET" --quiet --load-cookies "$COOKIE_FILE" -O - "${BASE_URL}/${group}/" \
        | grep -E --only-matching "href=\"/${group}\+[^\"]+" \
            | cut -d '"' -f 2 | cut -d '/' -f 2 \
                | grep "$group" | sort | uniq
}

# Function: mirrorGroup
#
# Downloads (mirrors) the given group.
#
# Uses globals:
#     $DRY_RUN
#     $COOKIE_FILE
#     $DOWNLOAD_DIR
#     $BASE_URL
#     $SUBGROUP
mirrorGroup () {
    local group="$1"
    local include_path="/${group},/groups/${group},/assets"
    local url="${BASE_URL}/${group}/"

    if [ 1 -eq $SUBGROUP ]; then
        echo "Finding subgroups for $group..."
        read -r -a subgroups <<< $(getSubgroups "$group")
        echo "Mirroring group $group with all subgroups: ${subgroups[@]} "
        for subgroup in ${subgroups[@]}; do
            include_path="${include_path},/${subgroup},/groups/${subgroup}"
            url="${url} ${BASE_URL}/${subgroup}"
        done
    else 
      echo "Mirroring group $group..."
    fi

    $DRY_RUN $TOR "$WGET" $WGET_ARGS --load-cookies "$COOKIE_FILE" --mirror \
        --include "$include_path" --convert-links --retry-connrefused \
        --reject "edit.html" \
        --directory-prefix "${DOWNLOAD_DIR}" \
        --page-requisites --html-extension ${url}
}

# Function: scmRepositoryStatus
#
# Checks the download directory for the existence and status of the
# source code management repository.
#
# Uses globals:
#     $DOWNLOAD_DIR
#     $SCM
#
# Returns 0 if the repository exists and is in an okay state.
scmRepositoryStatus () {
    local status_code
    cd "$DOWNLOAD_DIR"
    case "$SCM" in
        git )
            git status 2>/dev/null
            status_code=$?
            ;;
    esac
    cd -
    return $status_code
}

# Function: scmInitializeRepository
#
# Creates a new repository using the given SCM backend in the
# download directory.
# Uses globals:
#     $DOWNLOAD_DIR
#     $SCM
scmInitializeRepository () {
    cd "$DOWNLOAD_DIR"
    case "$SCM" in
        git )
            git init
            ;;
    esac
    cd -
}

# Function: scmCommit
#
# Commits a new changeset/patch/version to the given SCM backend.
#
# Params:
#     Any argument passed to this function will be passed to the SCM
#     backend as part of its "commit" or "checkin" routine.
#
# Uses globals:
#     $IFS
#     $OLD_IFS
#     $DOWNLOAD_DIR
#     $COOKIE_FILE
#     $SCM
scmCommit () {
    local string
    local args

    # Parse the string(s?) passed to this function as individual args.
    string=$(echo "$@" | sed -Ee 's/ (-)?-/__NEWARG__\1-/g') # Use `__NEWARG__` as the delimeter.
    # Convert the delimeter into a newline, then immediately treat that as an array in which the
    # newlines are the only field separator (by setting $IFS explicitly).
    IFS=$'\n'
    args=(${string//__NEWARG__/$'\n'})

    cd "$DOWNLOAD_DIR"
    rm -f "$COOKIE_FILE" # Never commit cookies to version control.
    case "$SCM" in
        git )
            git add .
            git commit ${args[@]} # Pass the parsed arguments to the SCM backend.
            ;;
    esac
    cd -

    # Restore IFS.
    IFS="$OLD_IFS"
}

# Function: checkPrerequisites
#
# Ensures we can actually proceed safely.
# If we can't, issues an error code and exits.
#
# Uses globals:
#     $PROGRAM
#     $E_MISSING_WGET
#     $SCM
#     $E_MISSING_SCM
#     $E_NONWRITABLE_DIR
checkPrerequisites () {
    # Check to make sure we have a `wget` available.
    which "$WGET"
    if [ 1 -eq $? ]; then
        echo "FATAL: $PROGRAM cannot find a suitable '$WGET' binary." >&2
        exit $E_MISSING_WGET;
    fi

    which "$SCM"
    if [ 1 -eq $? ]; then
        echo "FATAL: $PROGRAM cannot find a suitable '$SCM' binary." >&2
        exit $E_MISSING_SCM;
    fi

    # Warn on unsupported SCM backends.
    local scms="cvs svn hz bzr"
    for scm in scms; do
        if [ x"$scm" == x"$SCM" ]; then
            echo "WARNING: SCM backend '$1' is not yet implemented." >&2
        fi
    done;

    # Check to ensure the download directory is writable.
    if [ ! -w "$DOWNLOAD_DIR" ]; then
        echo "FATAL: Permission denied to write in download directory '$DOWNLOAD_DIR'" >&2
        exit $E_NONWRITABLE_DIR;
    fi
}

# Function: main
#
# Do the thing!
main () {
    # Process command line arguments.
    while test $# -gt 0; do
        if [ x"$1" == x"--" ]; then
            # detect argument termination
            shift
            break
        fi
        case "$1" in
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

            --tor )
                shift
                TOR="torsocks"
                ;;

            --wget-args )
                shift
                WGET_ARGS="$1"
                shift
                ;;

            --download-directory )
                shift
                DOWNLOAD_DIR="$1"
                shift
                ;;

            --quiet | -q )
                WGET_ARGS="$WGET_ARGS --quiet"
                shift
                ;;

            --base-url )
                shift
                BASE_URL="$1"
                shift
                ;;

            --scm )
                shift
                USE_SCM=1
                case "$1" in
                    cvs )
                        SCM="$1"
                        shift
                        ;;
                    svn )
                        SCM="$1"
                        shift
                        ;;
                    git )
                        SCM="$1"
                        shift
                        ;;
                    hg )
                        SCM="$1"
                        shift
                        ;;
                    bzr )
                        SCM="$1"
                        shift
                        ;;
                esac
                ;;

            --scm-args )
                shift
                SCM_ARGS="$1"
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
                echo "FATAL: Unrecognized option: '$1'. Try '$PROGRAM --help' for help." >&2
                exit $E_BAD_OPTION
                ;;

            * )
                break
                ;;
        esac
    done

    # Collect runtime parameters.
    if [ -z "$DOWNLOAD_DIR" ]; then
        DOWNLOAD_DIR="$DEFAULT_DOWNLOAD_DIR"
    fi
    if [ -z "$SCM" ]; then
        SCM="$DEFAULT_SCM"
    fi

    # Before we go any further, make sure we can, y'know, do things.
    checkPrerequisites

    # We still need group names.
    if [ $# -lt 1 ]; then
        echo "FATAL: Missing group names. Try '$PROGRAM --help' for help." >&2
        exit $E_MISSING_ARG
    fi

    # Get Crabgrass parameters.
    if [ -z "$USERNAME" ]; then
        read -p "Username: " USERNAME
    fi
    if [ -z "$PASSWORD" ]; then
        read -s -p "Password: " PASSWORD
    fi
    if [ -z "$BASE_URL" ]; then
        BASE_URL="$DEFAULT_BASE_URL"
    fi

    login "$USERNAME" "$PASSWORD" "${BASE_URL}${LOGIN_PATH}"

    for group in "$@"; do
        mirrorGroup "$group"
    done

    if [ 1 -eq "$USE_SCM" ]; then
        # Check to see if the download directory is already a repository.
        scmRepositoryStatus
        # If it is not, initialize a new repository there.
        if [ 0 -ne $? ]; then
            scmInitializeRepository
        fi
        # Once it is a repository, commit the newly downloaded mirrored
        # contents using the given SCM arguments passed to us.
        scmCommit $SCM_ARGS
    fi
}

main "$@"
