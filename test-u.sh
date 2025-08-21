#!/usr/bin/env bash
set -euo pipefail

#=========================================================
# Offline repo mirror builder for AlmaLinux 9 (air-gapped Foreman)
#=========================================================
# What it does:
#  - Mirrors BaseOS, AppStream, CRB (required)
#  - Optionally mirrors EPEL
#  - Optionally installs + mirrors Foreman & Puppet repos (if you provide release RPM URLs)
#  - Supports extra repo IDs
#  - Creates repodata and a README with offline install steps
#
# Usage examples:
#   ./make-foreman-offline-mirror-el9.sh /srv/foreman-mirror
#   ./make-foreman-offline-mirror-el9.sh /mnt/disk/foreman-mirror --with-epel
#   ./make-foreman-offline-mirror-el9.sh /srv/foreman-mirror \
#       --with-epel \
#       --foreman-release-url "https://yum.theforeman.org/releases/3.x/el9/x86_64/foreman-release.rpm" \
#       --puppet-release-url  "https://yum.puppet.com/puppet8-release-el-9.noarch.rpm" \
#       --extra-repos "foreman-plugins,puppetlabs-products"
#
# Notes:
# - If you’re not sure about the Foreman/Puppet URLs yet, skip those flags now and re-run later.
# - This script is hardened for AL9 (DNF4) but auto-detects reposync via dnf/dnf5 if needed.
#=========================================================

#-----------------------------
# Defaults / CLI parsing (robust)
#-----------------------------
DEST_ROOT=""
WITH_EPEL=0
FOREMAN_RELEASE_URL=""
PUPPET_RELEASE_URL=""
EXTRA_REPOS=""   # comma-separated list of additional repo IDs to mirror

need_val() {
  local flag="$1"
  local val="${2:-}"
  if [[ -z "$val" || "$val" =~ ^-- ]]; then
    echo "ERROR: $flag requires a value." >&2
    exit 2
  fi
}

print_usage() {
  cat >&2 <<'USAGE'
Usage: make-foreman-offline-mirror-el9.sh <destination_dir> [options]

Options:
  --with-epel
  --foreman-release-url URL
  --puppet-release-url  URL
  --extra-repos         'repoid1,repoid2'

Examples:
  ./make-foreman-offline-mirror-el9.sh /srv/foreman-mirror
  ./make-foreman-offline-mirror-el9.sh /srv/foreman-mirror --with-epel
  ./make-foreman-offline-mirror-el9.sh /srv/foreman-mirror \
    --with-epel \
    --foreman-release-url "https://yum.theforeman.org/releases/3.x/el9/x86_64/foreman-release.rpm" \
    --puppet-release-url  "https://yum.puppet.com/puppet8-release-el-9.noarch.rpm" \
    --extra-repos "foreman-plugins,puppetlabs-products"
USAGE
}

# First arg must be destination dir (required)
if [[ $# -lt 1 || "$1" =~ ^-- ]]; then
  echo "ERROR: destination directory is required as the first argument." >&2
  print_usage
  exit 2
fi
DEST_ROOT="$1"; shift

# Parse remaining flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-epel)
      WITH_EPEL=1; shift ;;
    --foreman-release-url)
      need_val "$1" "${2:-}"; FOREMAN_RELEASE_URL="$2"; shift 2 ;;
    --puppet-release-url)
      need_val "$1" "${2:-}"; PUPPET_RELEASE_URL="$2";  shift 2 ;;
    --extra-repos)
      need_val "$1" "${2:-}"; EXTRA_REPOS="$2";         shift 2 ;;
    --help|-h)
      print_usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      print_usage; exit 2 ;;
  esac
done

#-----------------------------
# Helpers
#-----------------------------
log() { printf "\n==> %s\n" "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

require_root() {
  [[ $EUID -eq 0 ]] || die "Please run as root (sudo)."
}

check_alma9() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ "${ID:-}" != "almalinux" || "${VERSION_ID:-}" != 9* ]]; then
      die "This script is designed for AlmaLinux 9. Detected: ID=${ID:-?}, VERSION_ID=${VERSION_ID:-?}"
    fi
  else
    die "/etc/os-release not found; cannot verify OS."
  fi
}

install_tools() {
  log "Installing required tools (dnf-plugins-core, dnf5-plugins (if present), createrepo_c, tar)..."
  # dnf5-plugins may not exist on AL9; ignore failure for that package.
  dnf -y install dnf-plugins-core createrepo_c tar || die "Failed to install core prerequisites"
  dnf -y install dnf5-plugins || true
}

select_reposync() {
  # Prefer standalone reposync if present; otherwise fall back to dnf5/dnf.
  if command -v reposync >/dev/null 2>&1; then
    REPOSYNC=(reposync)
  elif command -v dnf5 >/dev/null 2>&1 && dnf5 --help 2>&1 | grep -qi reposync; then
    REPOSYNC=(dnf5 reposync)
  elif command -v dnf >/dev/null 2>&1 && dnf --help 2>&1 | grep -qi reposync; then
    REPOSYNC=(dnf reposync)
  else
    die "No reposync found. Install dnf-plugins-core (DNF4) or dnf5-plugins (DNF5)."
  fi
  log "Using reposync command: ${REPOSYNC[*]}"
}

enable_base_repos() {
  log "Enabling BaseOS/AppStream/CRB..."
  dnf config-manager --set-enabled baseos appstream crb || true
}

maybe_enable_epel() {
  if [[ $WITH_EPEL -eq 1 ]]; then
    log "Installing and enabling EPEL (optional)..."
    dnf -y install epel-release || die "Failed to install epel-release"
    dnf config-manager --set-enabled epel || true
  fi
}

install_release_rpms() {
  # Foreman & Puppet release RPMs are optional and user-provided.
  if [[ -n "$FOREMAN_RELEASE_URL" ]]; then
    log "Installing Foreman release RPM from: $FOREMAN_RELEASE_URL"
    dnf -y install "$FOREMAN_RELEASE_URL" || die "Failed to install Foreman release RPM"
  else
    log "Skipping Foreman release RPM (no URL provided)."
  fi
  if [[ -n "$PUPPET_RELEASE_URL" ]]; then
    log "Installing Puppet release RPM from: $PUPPET_RELEASE_URL"
    dnf -y install "$PUPPET_RELEASE_URL" || die "Failed to install Puppet release RPM"
  else
    log "Skipping Puppet release RPM (no URL provided)."
  fi
}

# Return 0 if repo ID exists (enabled or disabled), else 1
repo_exists() {
  local repoid="$1"
  dnf repolist --all | awk '{print $1}' | grep -qE "^${repoid}(\.|$)"
}

reposync_one() {
  local repoid="$1"
  local dest="$2"

  if ! repo_exists "$repoid"; then
    log "Repo '$repoid' not found or disabled. Skipping."
    return 0
  fi

  log "Syncing '$repoid' -> $dest"
  mkdir -p "$dest"
  # -m/--download-metadata; -p output path; -j parallel; EL9 usually has standalone reposync.
  "${REPOSYNC[@]}" -m --download-metadata -p "$dest" --repoid="$repoid" -j "$(nproc)" || die "reposync failed for $repoid"

  # reposync creates a subdir named like the repoid inside $dest; detect it:
  local subdir
  subdir="$(find "$dest" -maxdepth 1 -type d -name "$repoid*" | head -n1 || true)"
  if [[ -z "$subdir" ]]; then
    # Some setups put packages directly in dest; handle both cases.
    subdir="$dest"
  fi

  log "Running createrepo_c in $subdir"
  createrepo_c --update "$subdir" || die "createrepo_c failed for $repoid"
}

write_readme() {
  local out="$1/README-offline.txt"
  cat > "$out" <<'EOF'
Offline Repos for AlmaLinux 9 (Foreman install)
===============================================

This bundle contains DNF/YUM repositories mirrored from an online AlmaLinux 9 machine:
- BaseOS
- AppStream
- CRB
- (optional) EPEL
- (optional) Foreman
- (optional) Puppet
- (optional) any extra repos you provided

How to use on the air-gapped AlmaLinux 9 server
------------------------------------------------
1) Copy the entire directory (keeping structure) to the target, e.g.:
   /opt/localrepos

2) Create repo files (as root) under /etc/yum.repos.d/ pointing to the local paths.
   Example (/etc/yum.repos.d/local-offline.repo):

   [local-baseos]
   name=Local BaseOS
   baseurl=file:///opt/localrepos/baseos
   enabled=1
   gpgcheck=0

   [local-appstream]
   name=Local AppStream
   baseurl=file:///opt/localrepos/appstream
   enabled=1
   gpgcheck=0

   [local-crb]
   name=Local CRB
   baseurl=file:///opt/localrepos/crb
   enabled=1
   gpgcheck=0

   # (optional) EPEL
   [local-epel]
   name=Local EPEL
   baseurl=file:///opt/localrepos/epel
   enabled=1
   gpgcheck=0

   # (optional) Foreman
   [local-foreman]
   name=Local Foreman
   baseurl=file:///opt/localrepos/foreman
   enabled=1
   gpgcheck=0

   # (optional) Puppet
   [local-puppet]
   name=Local Puppet
   baseurl=file:///opt/localrepos/puppet
   enabled=1
   gpgcheck=0

3) Refresh cache:
   dnf clean all
   dnf makecache

4) Install Foreman installer:
   dnf -y install foreman-installer

5) Run the installer (basic or interactive):
   foreman-installer
   # or
   foreman-installer -i

If package resolution fails, a dependency repo is likely missing.
Rebuild the mirror on the connected host adding the needed repo IDs.
EOF
  log "Wrote $out"
}

tar_bundle() {
  local root="$1"
  local tarfile="$2"
  log "Creating tarball: $tarfile"
  tar -C "$(dirname "$root")" -cf "$tarfile" "$(basename "$root")"
}

#-----------------------------
# Main
#-----------------------------
require_root
check_alma9
install_tools
select_reposync
enable_base_repos
maybe_enable_epel
install_release_rpms

# Normalize destination layout
DEST_ROOT="$(readlink -f "$DEST_ROOT")"
mkdir -p "$DEST_ROOT"

# Map of desired repos -> subdirs
declare -A MAP
MAP[baseos]="baseos"
MAP[appstream]="appstream"
MAP[crb]="crb"

if [[ $WITH_EPEL -eq 1 ]]; then
  MAP[epel]="epel"
fi

# Try to detect plausible Foreman/Puppet repo IDs that may have been added by release RPMs.
# These vary; attempt common names and any user-provided extras.
COMMON_FOREMAN_IDS=(foreman foreman-plugins foreman-client foreman-client-el9)
COMMON_PUPPET_IDS=(puppet puppet8 puppet7 puppetlabs-products puppetlabs-deps puppetlabs-pc1)

for id in "${COMMON_FOREMAN_IDS[@]}"; do
  if repo_exists "$id"; then MAP["$id"]="foreman"; fi
done
for id in "${COMMON_PUPPET_IDS[@]}"; do
  if repo_exists "$id"; then MAP["$id"]="puppet"; fi
done

# User-specified extra repo IDs (comma-separated)
if [[ -n "$EXTRA_REPOS" ]]; then
  IFS=',' read -r -a EXTRA_ARR <<< "$EXTRA_REPOS"
  for id in "${EXTRA_ARR[@]}"; do
    id_trim="$(echo "$id" | xargs)"
    [[ -z "$id_trim" ]] && continue
    if repo_exists "$id_trim"; then
      # Use repo ID as subdir name if not already mapped
      MAP["$id_trim"]="${MAP[$id_trim]:-$id_trim}"
    else
      log "Warning: extra repo '$id_trim' not found; skipping."
    fi
  done
fi

log "Repos to mirror:"
for repoid in "${!MAP[@]}"; do
  printf "  - %s -> %s\n" "$repoid" "${MAP[$repoid]}"
done

# Sync each repo ID to its target dir
declare -A TARGET_DIRS_CREATED
for repoid in "${!MAP[@]}"; do
  target="${DEST_ROOT}/${MAP[$repoid]}"
  reposync_one "$repoid" "$target"
  TARGET_DIRS_CREATED["$target"]=1
done

# Ensure repodata exists on each top-level target dir too (harmless if already present)
for d in "${!TARGET_DIRS_CREATED[@]}"; do
  createrepo_c --update "$d" || true
done

write_readme "$DEST_ROOT"

# Also write a convenience .repo file template
cat > "${DEST_ROOT}/sample-offline.repo" <<'REPO'
[local-baseos]
name=Local BaseOS
baseurl=file:///opt/localrepos/baseos
enabled=1
gpgcheck=0

[local-appstream]
name=Local AppStream
baseurl=file:///opt/localrepos/appstream
enabled=1
gpgcheck=0

[local-crb]
name=Local CRB
baseurl=file:///opt/localrepos/crb
enabled=1
gpgcheck=0

[local-epel]
name=Local EPEL
baseurl=file:///opt/localrepos/epel
enabled=1
gpgcheck=0

[local-foreman]
name=Local Foreman
baseurl=file:///opt/localrepos/foreman
enabled=1
gpgcheck=0

[local-puppet]
name=Local Puppet
baseurl=file:///opt/localrepos/puppet
enabled=1
gpgcheck=0
REPO
log "Wrote ${DEST_ROOT}/sample-offline.repo"

# Pack it up (uncompressed tar keeps it simple; compress if you prefer)
BASENAME="$(basename "$DEST_ROOT")"
PARENT="$(dirname "$DEST_ROOT")"
TS="$(date +%Y%m%d-%H%M%S)"
OUT_TAR="${PARENT}/${BASENAME}-${TS}.tar"
tar_bundle "$DEST_ROOT" "$OUT_TAR"

log "DONE."
log "Mirror directory: $DEST_ROOT"
log "Tarball ready:    $OUT_TAR"
echo
echo "Next steps (connected host): copy the tarball to your removable disk."
echo "On the air-gapped host (AL9): extract to /opt/localrepos, drop sample-offline.repo into /etc/yum.repos.d/, then 'dnf makecache' and install 'foreman-installer'."
