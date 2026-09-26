#!/usr/bin/env zsh
set -euo pipefail

# Auto-confirm Homebrew's "Do you want to proceed?" upgrade prompt
# Equivalent to passing `--no-ask` / `-y` to `brew upgrade`.
# See `man brew` (Environment section) → HOMEBREW_NO_ASK.
export HOMEBREW_NO_ASK=1

# Usage: ./release.sh <major|minor|patch>
# Example: ./release.sh patch   (v0.1.2 -> v0.1.3)
#          ./release.sh minor   (v0.1.2 -> v0.2.0)
#          ./release.sh major   (v0.1.2 -> v1.0.0)
#          First release (no tags): v0.1.0
#
# Run on a Mac. Bottles arm64. There is no Linux build: super-keys is AppKit.
# The package deployment target is macOS 13, so one arm64 bottle is published
# for every Homebrew macOS from Ventura through the newest supported release.
# Intel Macs have no bottle and compile from source.
#
#   1. Tag and push the release in the SuperKeys repo
#   2. Wait for GitHub to make the source tarball available, then sha256 it
#   3. Generate the Homebrew formula from the template
#   4. Build from source and bottle for this Mac
#   5. Reuse that bottle for every supported arm64 macOS tag
#   6. Commit the formula and bottles in homebrew-tap
#   7. Push homebrew-tap
#   8. Install/upgrade local super-keys from the bottle

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# This repo lives in nohype-ai/apps/SuperKeys. The tap lives in nohype-ai/company/homebrew-tap.
TAP_REPO="$REPO_DIR/../../company/homebrew-tap"
TEMPLATE="$TAP_REPO/Formula/super-keys_template.rb"
FORMULA="$TAP_REPO/Formula/super-keys.rb"
BOTTLES="$TAP_REPO/Bottles"

BUMP="${1:-}"
if [[ "$BUMP" != "major" && "$BUMP" != "minor" && "$BUMP" != "patch" ]]; then
    echo "Usage: $0 <major|minor|patch>"
    echo "Example: $0 patch"
    exit 1
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Error: Run release.sh on a Mac so it can bottle."
    exit 1
fi

if ! command -v brew >/dev/null; then
    echo "Error: Homebrew is required."
    exit 1
fi

# Determine latest version from git tags
LATEST=$(git -C "$REPO_DIR" tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1 || true)
if [[ -z "$LATEST" ]]; then
    VERSION="v0.1.0"
    echo "No existing version tags. First release: $VERSION"
elif [[ ! -f "$FORMULA" ]] || ! grep -q "bottle do" "$FORMULA" || ! grep -q "tags/${LATEST}.tar.gz" "$FORMULA"; then
    VERSION="$LATEST"
    echo "Resuming unfinished $VERSION"
else
    MAJOR=$(echo "$LATEST" | sed 's/^v//' | cut -d. -f1)
    MINOR=$(echo "$LATEST" | sed 's/^v//' | cut -d. -f2)
    PATCH=$(echo "$LATEST" | sed 's/^v//' | cut -d. -f3)

    case "$BUMP" in
        major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
        minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
        patch) PATCH=$((PATCH + 1)) ;;
    esac

    VERSION="v${MAJOR}.${MINOR}.${PATCH}"
    echo "Latest version: $LATEST"
    echo "New version:    $VERSION"
fi
echo ""

if [[ ! -d "$TAP_REPO" ]]; then
    echo "Error: Formula repo not found at $TAP_REPO"
    echo "Expected homebrew-tap at nohype-ai/company/homebrew-tap."
    exit 1
fi
TAP_REPO="$(cd "$TAP_REPO" && pwd)"
TEMPLATE="$TAP_REPO/Formula/super-keys_template.rb"
FORMULA="$TAP_REPO/Formula/super-keys.rb"
BOTTLES="$TAP_REPO/Bottles"

if [[ ! -f "$TEMPLATE" ]]; then
    echo "Error: Formula template not found at $TEMPLATE"
    exit 1
fi

TARBALL_URL="https://github.com/nohype-ai/SuperKeys/archive/refs/tags/${VERSION}.tar.gz"
ROOT_URL="https://raw.githubusercontent.com/nohype-ai/homebrew-tap/main/Bottles"

echo "=== SuperKeys Release: $VERSION ==="
echo ""

# Step 1: Tag the release in the SuperKeys repo and push
echo "Step 1: Tagging $VERSION and pushing to GitHub ..."
cd "$REPO_DIR"
if git rev-parse -q --verify "refs/tags/$VERSION" >/dev/null; then
    echo "  Tag $VERSION already exists, skipping."
else
    git tag "$VERSION"
    git push origin "$VERSION"
    echo "  Tag $VERSION pushed."
fi
echo ""

# Step 2: Wait for GitHub to create the source tarball, then compute sha256
echo "Step 2: Waiting for GitHub to make the source tarball available ..."
MAX_ATTEMPTS=12
WAIT_SECONDS=5
SHA256=""

for attempt in $(seq 1 $MAX_ATTEMPTS); do
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -L "$TARBALL_URL")
    if [[ "$HTTP_STATUS" == "200" ]]; then
        echo "  Tarball available (attempt $attempt). Computing sha256 ..."
        SHA256=$(curl -sL "$TARBALL_URL" | shasum -a 256 | awk '{print $1}')
        break
    fi
    echo "  Not ready yet (HTTP $HTTP_STATUS). Waiting ${WAIT_SECONDS}s ... (attempt $attempt/$MAX_ATTEMPTS)"
    sleep "$WAIT_SECONDS"
done

if [[ -z "$SHA256" ]]; then
    echo "Error: Tarball not available after $((MAX_ATTEMPTS * WAIT_SECONDS))s."
    echo "URL: $TARBALL_URL"
    echo "The repo must be public."
    exit 1
fi

echo "  sha256: $SHA256"
echo ""

# Step 3: Generate super-keys.rb from the template (no bottle yet)
echo "Step 3: Updating Homebrew formula from template ..."
sed -e "s|<VERSION-PLACEHOLDER>|${VERSION}|g" \
    -e "s|<SHA256-PLACEHOLDER>|${SHA256}|g" \
    "$TEMPLATE" > "$FORMULA"
echo "  Formula written to $FORMULA"
echo ""

# Step 4: Build from source and bottle for this Mac
echo "Step 4: Bottling for this Mac ..."
brew tap nohype-ai/tap
BREW_TAP="$(brew --repository nohype-ai/tap)"
mkdir -p "$BREW_TAP/Formula"
cp "$FORMULA" "$BREW_TAP/Formula/super-keys.rb"

if brew list --formula super-keys >/dev/null 2>&1; then
    brew uninstall --ignore-dependencies super-keys
fi
brew install --build-bottle nohype-ai/tap/super-keys

BOTTLE_DIR="$(mktemp -d)"
pushd "$BOTTLE_DIR" >/dev/null
brew bottle --no-rebuild --json --root-url="$ROOT_URL" nohype-ai/tap/super-keys
mkdir -p "$BOTTLES"
python3 - "$BOTTLES" <<'PY'
import glob, json, os, shutil, sys
dest = sys.argv[1]
for path in glob.glob("*.bottle.json"):
    with open(path) as handle:
        data = json.load(handle)
    for spec in data.values():
        for info in spec["bottle"]["tags"].values():
            shutil.copy(info["local_filename"], os.path.join(dest, info["filename"]))
PY
brew bottle --merge --write --no-commit ./*.bottle.json
popd >/dev/null
rm -rf "$BOTTLE_DIR"

cp "$BREW_TAP/Formula/super-keys.rb" "$FORMULA"
echo "  Bottle written to $BOTTLES"
echo ""

# Step 5: The binary's deployment target is macOS 13 (Package.swift). Publish
# the arm64 bottle we just built under every tag from Ventura upward so those
# Macs pour it instead of compiling. Intel stays a source build.
echo "Step 5: Publishing the arm64 bottle for each supported macOS ..."
PKG_VERSION="${VERSION#v}"
SRC_BOTTLE="$BOTTLES/super-keys-${PKG_VERSION}.arm64_golden_gate.bottle.tar.gz"
if [[ ! -f "$SRC_BOTTLE" ]]; then
    echo "Error: arm64_golden_gate bottle not found at $SRC_BOTTLE"
    exit 1
fi
TAGS=$(brew ruby -e '
min = MacOSVersion.new("13")
newest = MacOSVersion.new(HOMEBREW_MACOS_NEWEST_SUPPORTED)
MacOSVersion::SYMBOLS.each do |sym, ver|
  version = MacOSVersion.new(ver)
  next unless version >= min && version <= newest
  puts "arm64_#{sym}"
end
')
python3 - "$FORMULA" "$SRC_BOTTLE" "$BOTTLES" "$PKG_VERSION" "$TAGS" <<'PY'
import hashlib, pathlib, re, shutil, sys
formula_path, src, bottles, version, tags_blob = sys.argv[1:]
tags = tags_blob.split()
if "arm64_golden_gate" not in tags:
    sys.exit("arm64_golden_gate missing from supported macOS tags")
digest = hashlib.sha256(pathlib.Path(src).read_bytes()).hexdigest()
bottles = pathlib.Path(bottles)
for tag in tags:
    dest = bottles / f"super-keys-{version}.{tag}.bottle.tar.gz"
    if dest != pathlib.Path(src):
        shutil.copyfile(src, dest)
formula = pathlib.Path(formula_path)
text = formula.read_text()
match = re.search(
    r'^    sha256 (cellar: :\w+, )arm64_golden_gate: "[0-9a-f]+"\n',
    text,
    re.M,
)
if not match:
    sys.exit("could not find arm64_golden_gate sha256 line in formula")
lines = "".join(
    f'    sha256 {match.group(1)}{tag}: "{digest}"\n' for tag in tags
)
formula.write_text(text[:match.start()] + lines + text[match.end():])
print("  tags: " + " ".join(tags))
PY
echo ""

# Step 6: Commit the bottled formula in the homebrew-tap repo
echo "Step 6: Committing formula update ..."
cd "$TAP_REPO"
git add Formula/super-keys.rb Bottles
git commit -m "Bump super-keys to $VERSION"
echo "  Committed."
echo ""

# Step 7: Push the formula repo
echo "Step 7: Pushing homebrew-tap ..."
git push
echo "  Pushed."
echo ""

echo "=== Release $VERSION complete! ==="

# Step 8: Install from the bottle
echo ""
echo "Step 8: Installing bottled super-keys locally ..."
git -C "$BREW_TAP" fetch origin
git -C "$BREW_TAP" reset --hard origin/main
git -C "$BREW_TAP" clean -fd
# Drop the --build-bottle keg; a normal install should fetch the bottle.
if brew list --formula super-keys >/dev/null 2>&1; then
    brew uninstall --ignore-dependencies super-keys
fi
brew install nohype-ai/tap/super-keys
echo "This version of super-keys is now installed: $(brew list --versions super-keys)"
