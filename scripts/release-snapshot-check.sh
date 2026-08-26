#!/bin/sh
set -eu

# Pinned GoReleaser version, run via `go run` so nothing is installed
# globally. Bump this together with the matching pin in .goreleaser.yml.
goreleaser_version="v2.17.1"

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
dist_dir="$repo_root/dist"
plugin_binary="steampipe-plugin-youtrack.plugin"

# Steampipe Hub artifact contract (Task 4 depends on these exact names):
# one bare-gzipped plugin binary per platform (`gz` format, not tar.gz —
# the Hub's build pipeline requires this).
expected_platforms="linux_amd64 linux_arm64 darwin_amd64 darwin_arm64"

fail() {
	printf '%s\n' "release-snapshot-check: $*" >&2
	exit 1
}

for command_name in go gzip jq; do
	command -v "$command_name" >/dev/null 2>&1 || fail "required command not found: $command_name"
done
if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
	fail "required command not found: sha256sum or shasum"
fi

verify_checksums() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum -c "$1"
	else
		shasum -a 256 -c "$1"
	fi
}

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/steampipe-youtrack-release-snapshot-check.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

cd "$repo_root"

go run "github.com/goreleaser/goreleaser/v2@${goreleaser_version}" release --snapshot --clean --skip=publish

# --- 1. Exactly the 4 expected archives, with exact names ------------------
for platform in $expected_platforms; do
	[ -f "$dist_dir/steampipe-plugin-youtrack_${platform}.gz" ] ||
		fail "missing expected archive: steampipe-plugin-youtrack_${platform}.gz"
done

actual_archive_count="$(find "$dist_dir" -maxdepth 1 -name '*.gz' | wc -l | tr -d ' ')"
[ "$actual_archive_count" = "4" ] || {
	find "$dist_dir" -maxdepth 1 -name '*.gz' >&2
	fail "expected exactly 4 archives in dist/, found $actual_archive_count"
}

# --- 2. Each archive is a bare gzip stream of the plugin binary -------------
for platform in $expected_platforms; do
	archive="$dist_dir/steampipe-plugin-youtrack_${platform}.gz"
	extract_dir="$work_dir/extract-$platform"
	mkdir -p "$extract_dir"
	gzip -dc "$archive" >"$extract_dir/$plugin_binary"

	[ -s "$extract_dir/$plugin_binary" ] ||
		fail "$archive: decompressed to an empty file"
	# A tar payload carries "ustar" at offset 257; the payload must be the
	# raw binary, so its presence means the archive regressed to tar.gz.
	if dd if="$extract_dir/$plugin_binary" bs=1 skip=257 count=5 2>/dev/null | grep -q ustar; then
		fail "$archive: payload is a tar archive, expected the bare plugin binary"
	fi
done

# --- 3. checksums.txt covers all archives and verifies ---------------------
checksums_file="$dist_dir/checksums.txt"
[ -f "$checksums_file" ] || fail "missing checksums.txt"

for platform in $expected_platforms; do
	archive_name="steampipe-plugin-youtrack_${platform}.gz"
	# Exact filename-field match: checksums.txt also lists the SBOM
	# documents, whose names contain the archive name as a substring, so a
	# plain grep -F would false-positive even without an archive entry.
	awk -v want="$archive_name" '$2 == want { found = 1 } END { exit !found }' "$checksums_file" ||
		fail "checksums.txt: missing entry for $archive_name"
done

if ! (cd "$dist_dir" && verify_checksums checksums.txt) >"$work_dir/checksum-verify.log" 2>&1; then
	cat "$work_dir/checksum-verify.log" >&2
	fail "checksum verification failed"
fi

# --- 4. SBOM per archive, valid SPDX JSON -----------------------------------
for platform in $expected_platforms; do
	archive_name="steampipe-plugin-youtrack_${platform}.gz"
	sbom="$dist_dir/${archive_name}.spdx.json"
	[ -f "$sbom" ] || fail "missing SBOM: ${archive_name}.spdx.json"
	jq -er '.spdxVersion' "$sbom" >/dev/null 2>&1 ||
		fail "${archive_name}.spdx.json: not a valid SPDX JSON document"
done

# --- 5. Injected version took effect ----------------------------------------
# Run the host-platform binary directly (the whole point of this check is to
# fail closed if -X ldflags stop landing); dist/metadata.json records the
# exact snapshot version GoReleaser computed for this run.
metadata_file="$dist_dir/metadata.json"
[ -f "$metadata_file" ] || fail "missing dist/metadata.json"
expected_version="$(jq -er '.version' "$metadata_file")"

host_platform="$(go env GOOS)_$(go env GOARCH)"
case " $expected_platforms " in
*" $host_platform "*) : ;;
*) host_platform="linux_amd64" ;;
esac

binary_dir="$(find "$dist_dir" -maxdepth 1 -type d -name "*_${host_platform}*" | head -n 1)"
[ -n "$binary_dir" ] || fail "could not locate built binary directory for $host_platform under dist/"
binary="$binary_dir/$plugin_binary"
[ -x "$binary" ] || fail "missing or non-executable binary: $binary"

version_output="$("$binary" --version)"
case "$version_output" in
*"$expected_version"*) : ;;
*)
	printf '%s\n' "$version_output" >&2
	fail "binary --version output does not contain injected version $expected_version"
	;;
esac

echo "release-snapshot-check: ok (4 archives, checksums verified, SBOMs present, version=$expected_version)"
