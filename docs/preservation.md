# Preservation, verification and the first Git commit

## What the bundle contains

A dated bundle is created under `preservation/bundles/`. It contains a ZIP,
detached SHA-256 checksum, per-file checksums, bundle metadata and an extraction
verification report. The ZIP contains `project/` and `preservation_metadata/`.
All saved output runs are included despite their Git-ignore rule.

The snapshot deliberately excludes `.git`, local libraries/caches, OS clutter,
previous bundles and the unrelated personal prompt collection. Exclusions and
conversation-export presence are recorded. It is not a backup of the running IDE,
scratch directory or complete Git history. No R workspace dump is required to
recreate the analysis; historical run artefacts and manifests are retained.

The per-file manifest covers the project payload. It does not hash itself; the
detached archive checksum covers the ZIP, including its embedded metadata. Hashes
detect corruption against a trusted reference, not malicious replacement of both
an archive and all its checksum files. Keep a second copy separately.

## Add and check conversation exports

Follow `docs/conversations/README.md` to save JSON and HTML in that directory.
Inspect the HTML and test importing the JSON. This manual step is not completed
by the bundle script. The initial snapshot is explicitly marked pending until
the files are added; file presence alone still does not prove export completeness.

## Create a new bundle

Source `scripts/create_preservation_bundle.R`, then call
`create_preservation_bundle(project_root, scratch_directory)` with explicit paths.
The scratch directory must exist, be writable and be outside the project. The
tool uses readr, jsonlite, digest and the optional cross-platform zip package;
their versions are recorded in bundle metadata. The zip package is a preservation
utility, not a new dependency of the analytical workflow or its existing lockfile.
No packages are installed or updated automatically.

Each call makes a new UTC-dated output directory. Files are copied to scratch,
hashed and checked for changes during copying. The ZIP is then extracted into a
different scratch directory and every project-payload hash is verified. Failure
does not imply a valid bundle; use only a bundle with a passed verification file.
Temporary staging/extraction files remain in the supplied scratch area, not in
the project or analytical outputs.

To verify a copied ZIP, source the same script and call
`verify_preservation_archive(archive, scratch_directory, expected_sha256)`.
Use the expected hash from the detached `.sha256` file stored with your trusted
copy. The function validates archive paths before extracting and checks the
embedded per-file manifest. Open several important files as an additional check.

The bundler does not execute the analytical workflow, export Assistant history,
stage files, commit, push, upload, delete or redact anything. A Git commit made
later is not retroactively part of an older snapshot.

## Review and make the first commit

Use the Positron terminal at the project root. These commands are instructions,
not actions already performed. First inspect `git status --short`. Review source,
inputs/licensing, documentation and conversation exports for personal information.
Do not use `git add .`: it would risk adding unrelated personal files.

After reviewing, stage only the intended project files:

```sh
git add .gitignore README.md renv.lock run_population.R Inputs R scripts config reference tests docs
git diff --cached --stat
git diff --cached --check
git status --short
```

`docs/` includes the conversation exports once added. Include them only after
privacy review. Outputs and dated bundles remain ignored and are preserved by
the ZIP instead. `Useful prompts.txt` should remain untracked unless you make a
separate explicit decision to include it. No remote repository is configured by
these commands.

When the staged selection is correct:

```sh
git commit -m "Preserve reviewed population workflow and handover"
git log -1 --oneline
git status --short
```

If Git requests your identity, set your chosen name/email for this repository
using local configuration; do not invent an identity or change global settings
without deciding to do so. A successful local commit is not an off-machine
backup. Use approved private remote storage or another protected backup copy.

After the commit, make another dated bundle so its metadata records the commit
hash. It still excludes Git internals/history: back up the repository separately,
for example with an approved private remote, if retaining Git history is required.
