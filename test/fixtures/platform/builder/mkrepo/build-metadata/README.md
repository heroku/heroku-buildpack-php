SemVer ignores build metadata in version strings, so "1.0.0" and "1.0.0+build2" are equivalent.

We want to allow rebuilds of existing versions, without affecting previous builds (maybe the metadata changed due to changes in the installer or whatever). If we have both "1.0.0" and "1.0.0+build2" versions of a package in a repo, there is no guarantee that the latter will be picked by the solver, since Composer ignores the build metadata, as per SemVer spec.

This test covers mkrepo.sh's filtering of "old builds" that carry the same "main" version number - in the generated repo, only "1.0.0+build2" should remain, and "1.0.0" should not be included.
