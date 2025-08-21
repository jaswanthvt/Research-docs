#!/usr/bin/env bash
set -euo pipefail

#=========================================================
# Offline repo mirror builder for AlmaLinux 10 (air-gapped Foreman)
#=========================================================
# What it does:
#  - Mirrors BaseOS, AppStream, CRB (required)
#  - Optionally mirrors EPEL
#  - Optionally installs + mirrors Foreman & Puppet repos (if you provide release RPM URLs)
#  - Creates repodata and a README with offline install steps
#
# Usage examples:
#   ./make-foreman-offline-mirror.sh /srv/foreman-mirror
#   ./make-foreman-offline-mirror.sh /mnt/disk/foreman-mirror --with-epel
#   ./make-foreman-offline-mirror.sh /srv/foreman-mirror \
#       --with-epel \
#       --foreman-release-url "https://yum.theforeman.org/releases/3.15/el10/x86_64/foreman-release.rpm" \
#       --puppet-release-url "https://yum.puppet.com/puppet8-release-el-10.noarch.rpm"
#
# If you're not sure about the Foreman/Puppet URLs yet, skip those flags for now.
# You can re-run later just to add those repos.
#=========================================================

#-----------------------------
# Defaults / CLI parsing
#-----------------------------
DEST_ROOT="${1:-}"
shift || true

WITH_EPEL=0
FOREMAN_RELEASE_URL=""
PUPPET_RELEASE_URL=""
EXTRA_REPOS=""   # comma-separated list of additional repo IDs to mirror

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-epel) WITH_EPEL=1; shift ;;
    --foreman-release-url) FOREMAN_RELEASE_URL="${2:-}"; shift 2 ;;
    --puppet-release-url)  PUPPET_RELEASE_URL="${2:-}";  shift 2 ;;
    --extra-repos)         EXTRA_REPOS="${2:-}";         shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "${DEST_ROOT}" ]]; then
  echo "Usage: $0 <destination_dir> [--with-epel] [--foreman-release-url URL] [--puppet-release-url URL] [--extra-repos 'repoid1,repoid2']" >&2
  exit 2
fi

#-----------------------------
# Helpers
#-----------------------------
log() { printf "\n==> %s\n" "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

require_root() {
  [[ $EUID -eq 0 ]] || die "Please run as root (sudo)."
}

check_alma10() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ "${ID:-}" != "almalinux" || "${VERSION_ID:-}" != 10* ]]; then
      die "This script is designed for AlmaLinux 10. Detected: ID=${ID:-?}, VERSION_ID=${VERSION_ID:-?}"
    fi
  else
    die "/etc/os-release not found; cannot verify OS."
  fi
}

install_tools() {
  log "Installing required tools (dnf-plugins-core, createrepo_c, tar)..."
  dnf -y install dnf-plugins-core createrepo_c tar || die "Failed to install prerequisites"
}

enable_base_repos() {
  log "Enabling BaseOS/AppStream/CRB..."
  dnf config-manager --set-enabled baseos appstream crb || true
}

maybe_enable_epel() {
  if [[ $WITH_EPEL -eq 1 ]]; then
    log "Installing and enabling EPEL (optional)..."
    dnf -y install epel-release || die "Failed to install epel-release"
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

# Return 0 if repo ID exists, else 1
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
  # --download-metadata is implied by -m in newer dnf; include both for safety
  reposync -m --download-metadata -p "$dest" --repoid="$repoid" -j "$(nproc)" || die "reposync failed for $repoid"

  # reposync creates a subdir named like the repoid inside $dest; detect it:
  local subdir
  subdir="$(find "$dest" -maxdepth 1 -type d -name "$repoid*" | head -n1 || true)"
  if [[ -z "$subdir" ]]; then
    # Some dists put packages directly in dest; handle both cases.
    subdir="$dest"
  fi

  log "Running createrepo_c in $subdir"
  createrepo_c --update "$subdir" || die "createrepo_c failed for $repoid"
}

write_readme() {
  local out="$1/README-offline.txt"
  cat > "$out" <<'EOF'
Offline Repos for AlmaLinux 10 (Foreman install)
===============================================

This bundle contains DNF/YUM repositories mirrored from an online AlmaLinux 10 machine:
- BaseOS
- AppStream
- CRB
- (optional) EPEL
- (optional) Foreman
- (optional) Puppet
- (optional) any extra repos you provided

How to use on the air-gapped AlmaLinux 10 server
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
check_alma10
install_tools
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
# These vary; we attempt common names and any user-provided extras.
COMMON_FOREMAN_IDS=(foreman foreman-plugins foreman-client)
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
      MAP["$id_trim"]="$id_trim"
    else
      log "Warning: extra repo '$id_trim' not found; skipping."
    fi
  done
fi

log "Repos to mirror:"
for repoid in "${!MAP[@]}"; do
  printf "  - %s -> %s\n" "$repoid" "${MAP[$repoid]}"
done

# Sync each repo ID to its target dir (deduplicating targets)
# We'll maintain a mapping so multiple repoids can land in same dir (e.g., foreman plugins)
declare -A TARGET_DIRS_CREATED
for repoid in "${!MAP[@]}"; do
  target="${DEST_ROOT}/${MAP[$repoid]}"
  # Create a unique subdir per repoid under target to avoid clobber
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
echo "On the air-gapped host: extract to /opt/localrepos, drop sample-offline.repo into /etc/yum.repos.d/, then 'dnf makecache' and install 'foreman-installer'."
