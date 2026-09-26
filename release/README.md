# SuperKeys Homebrew Release

Expects [homebrew-tap](https://github.com/nohype-ai/homebrew-tap) at `nohype-ai/company/homebrew-tap`, with this repo at `nohype-ai/apps/SuperKeys`. The GitHub repo must be public so the tag tarball is fetchable.

**Run `release.sh` on a Mac.** It bottles that Mac. `super-keys` is AppKit, so there is no Linux build. The bottle is committed to `homebrew-tap/Bottles/` and pushed with the formula.

## Release via Script

Release a new patch version:
```zsh
./release.sh patch
```

Release a new minor version:
```zsh
./release.sh minor
```

Release a new major version:
```zsh
./release.sh major
```

No tags yet → first release is `v0.1.0` (any of the three bumps). Re-run the same command if a release stops mid-bottle: it resumes that version instead of bumping.

## Release Manually

1. Tag the release in the SuperKeys repo and push:
   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```

2. Compute the sha256 of the source tarball GitHub just created:
   ```bash
   curl -sL https://github.com/nohype-ai/SuperKeys/archive/refs/tags/v0.1.0.tar.gz | shasum -a 256
   ```

3. Generate `homebrew-tap/Formula/super-keys.rb` from `super-keys_template.rb`: put the version in the URL and the hash in `sha256`.

4. On a Mac, bottle and put the tarball in the tap:
   ```bash
   brew tap nohype-ai/tap
   cp ../../company/homebrew-tap/Formula/super-keys.rb "$(brew --repository nohype-ai/tap)/Formula/super-keys.rb"
   brew reinstall --build-from-source nohype-ai/tap/super-keys
   brew bottle --no-rebuild --json \
     --root-url=https://raw.githubusercontent.com/nohype-ai/homebrew-tap/main/Bottles \
     nohype-ai/tap/super-keys
   ```
   Copy the bottle tarball into `homebrew-tap/Bottles/` under the filename Homebrew will request, and merge the bottle block into `super-keys.rb`.

5. Commit and push the formula and `Bottles/` to the `homebrew-tap` repo. Users who already have the tap will get the update on their next `brew upgrade`.

6. Test the release
   ```zsh
   brew tap nohype-ai/tap

   brew install nohype-ai/tap/super-keys

   # force tap update after new release
   cd $(brew --repository nohype-ai/tap) && git pull

   brew upgrade super-keys

   brew list --versions super-keys
   ```
