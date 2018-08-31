# Crabgrass Utilities - README

This repository holds various scripts and tools that make working with [Crabgrass](https://github.com/riseuplabs/crabgrass-core), AGPL software libre for network organizing, easier. It includes:

* [`cg-make-snapshot.sh`](#cg-make-snapshot-sh), a Bash shell script for creating static HTML snapshots (mirrors) of a Crabgrass group.

## `cg-make-snapshot.sh`

`cg-make-snapshot.sh` makes creating offline backups of Crabgrass groups easier. It can:

* find and mirror subgroups ("committees" and "councils")
* mirror any Crabgrass instance (not just the one at `we.riseup.net`)
* restrict itself to making network requests only over the [Tor](https://torproject.org/) anonymizing network (and, when combined with a custom `--base-url`, can connect to Onion sites hosting a Crabgrass instance)
* automatically commit snapshot changes to a source code management repository (like Git)

### Dependencies

The following should be in your search `$PATH`:

* `wget`
* If you choose to enable the `--scm` features, you further need:
    * the SCM binary of your choice (e.g., `git`), and
    * `sed`, for parsing complex arguments passed through to the underlying SCM backend.

### Example uses

Make a snapshot of the Crabgrass group `my-group` that you belong to:

```sh
./cg-make-snapshot.sh my-group
```

Make a snapshot of the Crabgrass group `my-group` from the perspective of the user with the username `exampleuser`:

```sh
./cg-make-snapshot.sh --user exampleuser my-group
```

Make a snapshot of the Crabgrass group `my-group` and all its committees' contents, too:

```sh
./cg-make-snapshot.sh --subgroup my-group
```

Make a snapshot of the Crabgrass group `my-other-group` and its subgroups when `my-other-group` lives on a personal Crabgrass server located at `cg.example.com`:

```sh
./cg-make-snapshot.sh --base-url https://cg.example.com --subgroup my-other-group
```

Make a snapsot of the Crabgrass group `frequently-updated-group` and its subgroups and save only the changes since the last snapshot into a Git repository located at `/opt/local/var/backup/crabgrass` that is committed to as the author known as `"A U Thor <a@thor.com>"`, and do this all in an unattended fashion (by specifying the user `backups` on the command line and reading the password from the `~/.crabgrass.secret` file on disk), asking `wget` to be `--quiet` during operation, while only making network requests using Tor:

```sh
./cg-make-snapshot.sh --download-directory /opt/local/var/backup/crabgrass \
    --user backups --password "$(cat $HOME/.crabgrass.secret)" \
    --subgroup --tor --quiet \
    --scm --scm-args '--author="A U Thor <a@thor.com>" -m "Automated backup."' \
    frequently-updated-group >/dev/null 2>&1
```

This last example is suitable for use in a `cron` script, for example, to automate your Crabgrass backups, as it produces zero output (by redirecting `stdout` and `stderr` to `/dev/null`).

### Known issues

* `./cg-make-snapshot.sh` duplicates pages when links to content in the Crabgrass group point at the same page but are addressed differently. (For instance, when using `[page->+12345]` in one place and `[page->https://we.riseup.net/my-group/page]` in another.
* `./cg-make-snapshot.sh` must be provided with the access credentials of a legitimate user. (Cannot create "anonymous" snapshots.)
    * See issue #1.
* There is no option to control whether `./cg-make-snapshot.sh` copies the administration settings pages of a group along with its contents.
    * See issue #2.
