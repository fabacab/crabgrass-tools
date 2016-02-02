# Crabgrass Utilities - README

This repository holds various scripts and tools that make working with [Crabgrass](https://github.com/riseuplabs/crabgrass-core), AGPL software libre for network organizing, easier. It includes:

* [`cg-make-snapshot.sh`](#cg-make-snapshot-sh), a Bash shell script for creating static HTML snapshots (mirrors) of a Crabgrass group.

## `cg-make-snapshot.sh`

`cg-make-snapshot.sh` makes creating offline backups of Crabgrass groups easier. It can:

* find and mirror subgroups ("committees" and "councils")
* mirror any Crabgrass instance (not just the one at `we.riseup.net`)

### Dependencies

* `wget`

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
./cg-make-snapshot --base-url https://cg.example.com --subgroup my-other-group
```

### Known issues

* `./cg-make-snapshot.sh` duplicates pages when links to content in the Crabgrass group point at the same page but are addressed differently. (For instance, when using `[page->+12345]` in one place and `[page->https://we.riseup.net/my-group/page]` in another.
* `./cg-make-snapshot.sh` must be provided with the access credentials of a legitimate user. (Cannot create "anonymous" snapshots.)
    * See issue #1.
* There is no option to control whether `./cg-make-snapshot.sh` copies the administration settings pages of a group along with its contents.
    * See issue #2.
