#!/usr/bin/env bash
set -euo pipefail

#=========================================================
# Hybrid Foreman/Puppet offline bundle for AlmaLinux 9/10
# - FULL mirror: Foreman & Puppet repos
# - MINIMAL bundle: only the deps needed from BaseOS/AppStream/CRB/EPEL
#=========================================================
# Usage:
#   ./make-foreman-hybrid-bundle.sh <dest_dir> [options]
#
# Examples (EL10):
#   ./make-foreman-hybrid-bundle.sh /srv/foreman-hybrid \
#     --with-epel \
#     --foreman-release-url "https://yum.theforeman.org/releases/3.15/el10/x86_64/foreman-release.rpm" \
#     --puppet-release-url  "https://yum.puppet.com/puppet8-release-el-10.noarch.rpm"
#
# Examples (EL9):
#   ./make-foreman-hybrid-bundle.sh /srv/foreman-hybrid \
#     --with-epel \
#     --foreman-release-url "https://yum.theforeman.org/releases/3.15/el9/x86_64/foreman-release.rpm" \
#     --puppet-release-url  "https://yum.puppet.com/puppet8-release-el-9.noarch.rpm"
#
# Notes:
# - Foreman/Puppet URLs optional; you can re-run later to add them.
# - Output layout:
#     dest/
#       foreman/   (FULL mirror)
#       puppet/    (FULL mirror)
#       minimal/   (ONLY the rpms needed from base/appstream/crb/epel)
#       README-offline.txt
#       sample-offline.repo
#=========================================================

DEST_ROOT=""
WITH_EPEL=0
FOREMAN_RELEASE_URL=""
PUPPET_RELEASE_URL=""
EXTRA_FOREMAN_IDS="foreman,foreman-plugins,foreman-client"
EXTRA_PUPPET_IDS="puppet,puppet8,puppetlabs-products,puppetlabs-deps,puppetlabs-pc1"

need_val() { local f="$1"; local v="${2:-}"; [[ -n "$v" && ! "$v" =~ ^-- ]] || { echo "ERROR: $f requires a value." >&2; exit 2; }; }

print_usage() {
  cat >&2 <<'USAGE'
Usage: make-foreman-hybrid-bundle.sh <dest_dir> [options]

Options:
  --with-epel
  --foreman-release-url URL
  --puppet-release-url  URL
  --extra-foreman-ids   "id1,id2"   (default: foreman,foreman-plugins,foreman-client)
  --extra-puppet-ids    "id1,id2"   (default: puppet,puppet8,puppetlabs-products,puppetlabs-deps,puppetlabs-pc1)
  --help | -h
USAGE
}

# --- Parse CLI ---
if [[ $# -lt 1 || "$1" =~ ^-- ]]; then
  echo "ERROR: destination directory is required as the first argument." >&2
  print_usage; exit 2
fi
DEST_ROOT="$1"; shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-epel) WITH_EPEL=1; shift ;;
    --foreman-release-url) need_val "$1" "${2:-}"; FOREMAN_RELEASE_URL="$2"; shift 2 ;;
    --puppet-release-url)  need_val "$1" "${2:-}"; PUPPET_RELEASE_URL="$2";  shift 2 ;;
    --extra-foreman-ids)   need_val "$1" "${2:-}"; EXTRA_FOREMAN_IDS="$2";   shift 2 ;;
    --extra-puppet-ids)    need_val "$1" "${2:-}"; EXTRA_PUPPET_IDS="$2";    shift 2 ;;
    --help|-h) print_usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; print_usage; exit 2 ;;
  esac
done

log() { printf "\n==> %s\n" "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

require_root() { [[ $EUID -eq 0 ]] || die "Please run as root (sudo)."; }

detect_el() {
  . /etc/os-release || die "cannot read /etc/os-release"
  [[ "${ID:-}" == "almalinux" ]] || die "This script targets AlmaLinux only."
  if [[ "${VERSION_ID:-}" == 9* ]]; then ELVER=9
  elif [[ "${VERSION_ID:-}" == 10* ]]; then ELVER=10
  else die "Unsupported AlmaLinux VERSION_ID=${VERSION_ID:-?} (need 9 or 10)"; fi
  log "Detected AlmaLinux ${ELVER}"
}

install_tools() {
  log "Installing tools (dnf5-plugins/dnf-plugins-core, createrepo_c, tar, xz)..."
  # Try both DNF5 and DNF4 plugin sets; ignore failures where not present
  dnf -y install dnf5-plugins createrepo_c tar xz || true
  dnf -y install dnf-plugins-core createrepo_c tar xz || true

  command -v createrepo_c >/dev/null || die "createrepo_c missing"
  command -v tar >/dev/null || die "tar missing"
}

select_cmds() {
  # reposync
  if command -v dnf5 >/dev/null 2>&1 && dnf5 --help 2>&1 | grep -qi reposync; then
    REPOSYNC=(dnf5 reposync); DEST_OPT="--destdir"
  elif command -v reposync >/dev/null 2>&1; then
    REPOSYNC=(reposync); DEST_OPT="--download-path"
  elif command -v dnf >/dev/null 2>&1 && dnf --help 2>&1 | grep -qi reposync; then
    REPOSYNC=(dnf reposync); DEST_OPT="--download-path"
  else
    die "No reposync found; install dnf5-plugins or dnf-plugins-core."
  fi
  log "Using reposync: ${REPOSYNC[*]} (dest flag: $DEST_OPT)"

  # download
  if command -v dnf5 >/dev/null 2>&1 && dnf5 download --help >/dev/null 2>&1; then
    DOWNLOAD=(dnf5 download); DL_DEST_OPT="--destdir"
  elif dnf download --help >/dev/null 2>&1; then
    DOWNLOAD=(dnf download); DL_DEST_OPT="--destdir"
  else
    die "No 'dnf download' available; install dnf5-plugins or dnf-plugins-core."
  fi
  log "Using download: ${DOWNLOAD[*]} (dest flag: $DL_DEST_OPT)"
}

enable_base_repos() {
  log "Enabling BaseOS/AppStream/CRB..."
  dnf config-manager --set-enabled baseos appstream crb || true
}

maybe_enable_epel() {
  if [[ $WITH_EPEL -eq 1 ]]; then
    log "Installing epel-release..."
    dnf -y install epel-release || die "Failed to install epel-release"
    dnf config-manager --set-enabled epel || true
  fi
}

install_release_rpms() {
  [[ -n "$FOREMAN_RELEASE_URL" ]] && { log "Installing Foreman release: $FOREMAN_RELEASE_URL"; dnf -y install "$FOREMAN_RELEASE_URL" || die "Foreman release install failed"; } || log "Skipping Foreman release."
  [[ -n "$PUPPET_RELEASE_URL"  ]] && { log "Installing Puppet release:  $PUPPET_RELEASE_URL";  dnf -y install "$PUPPET_RELEASE_URL"  || die "Puppet release install failed";  } || log "Skipping Puppet release."
}

repo_exists() {
  local id="$1"
  (dnf5 repolist --all 2>/dev/null || dnf repolist --all 2>/dev/null || true) | awk '{print $1}' | grep -qE "^${id}(\.|$)"
}

reposync_one() {
  local repoid="$1" dest="$2"
  if ! repo_exists "$repoid"; then log "Repo '$repoid' not found/disabled, skipping."; return 0; fi
  log "FULL mirror: $repoid -> $dest"
  mkdir -p "$dest"
  "${REPOSYNC[@]}" --download-metadata "$DEST_OPT" "$dest" --repoid="$repoid" || die "reposync failed for $repoid"
  # Create/refresh metadata (reposync usually handles inside subdir; do top too)
  createrepo_c --update "$dest" || true
}

download_minimal() {
  local outdir="$1"; shift
  mkdir -p "$outdir"
  log "MINIMAL download of packages (with deps) into $outdir:"
  log "Packages: $*"
  # --resolve pulls all dependencies, --alldeps is not needed here
  "${DOWNLOAD[@]}" --resolve $DL_DEST_OPT "$outdir" "$@" || die "dnf download failed"
  log "Generating metadata for minimal repo..."
  createrepo_c --update "$outdir"
}

write_readme() {
  local out="$1/README-offline.txt"
  cat >"$out" <<'EOF'
Hybrid Offline Bundle for Foreman (AlmaLinux 9/10)
==================================================

Contents:
  foreman/  -> FULL mirror of Foreman repos
  puppet/   -> FULL mirror of Puppet repos
  minimal/  -> ONLY the RPMs needed by foreman-installer and puppet-agent (from BaseOS/AppStream/CRB/EPEL)

Use on AIR-GAPPED host:
-----------------------
1) Copy this directory to the target, e.g. /opt/localrepos
2) Create /etc/yum.repos.d/local-offline.repo similar to sample-offline.repo here.
3) Run:
     dnf clean all
     dnf makecache
4) Install Foreman:
     dnf -y install foreman-installer
5) Run the installer:
     foreman-installer    # or: foreman-installer -i

Notes:
- The 'minimal' repo contains only the currently resolved deps. If install fails due to a missing dep, re-run the builder adding that package or include EPEL/base repos fully.
- For updates or plugins later, you may need to rebuild/refresh.
EOF
  log "Wrote $out"
}

write_repo_template() {
  cat > "$1/sample-offline.repo" <<'REPO'
# Minimal deps (BaseOS/AppStream/CRB/EPEL subset needed by Foreman+Puppet)
[local-minimal]
name=Local Minimal Core Deps
baseurl=file:///opt/localrepos/minimal
enabled=1
gpgcheck=0

# Full Foreman mirror
[local-foreman]
name=Local Foreman (full)
baseurl=file:///opt/localrepos/foreman
enabled=1
gpgcheck=0

# Full Puppet mirror
[local-puppet]
name=Local Puppet (full)
baseurl=file:///opt/localrepos/puppet
enabled=1
gpgcheck=0
REPO
  log "Wrote $1/sample-offline.repo"
}

tar_bundle() {
  local root="$1" tarfile="$2"
  log "Creating tarball: $tarfile"
  tar -C "$(dirname "$root")" -cf "$tarfile" "$(basename "$root")"
}

# ----------------- MAIN -----------------
require_root
detect_el
install_tools
select_cmds
enable_base_repos
maybe_enable_epel
install_release_rpms

DEST_ROOT="$(readlink -f "$DEST_ROOT")"; mkdir -p "$DEST_ROOT"
FOREMAN_DIR="$DEST_ROOT/foreman"
PUPPET_DIR="$DEST_ROOT/puppet"
MINIMAL_DIR="$DEST_ROOT/minimal"

# 1) FULL mirror Foreman/Puppet repos
IFS=',' read -r -a F_IDS <<< "$EXTRA_FOREMAN_IDS"
IFS=',' read -r -a P_IDS <<< "$EXTRA_PUPPET_IDS"
for id in "${F_IDS[@]}"; do id="$(echo "$id" | xargs)"; [[ -n "$id" ]] && reposync_one "$id" "$FOREMAN_DIR"; done
for id in "${P_IDS[@]}"; do id="$(echo "$id" | xargs)"; [[ -n "$id" ]] && reposync_one "$id" "$PUPPET_DIR"; done

# 2) MINIMAL: only what foreman-installer + puppet-agent need
PKGS=(foreman-installer puppet-agent)
# (Optional: add a few commonly-needed helpers; harmless if already deps)
PKGS+=(foreman-cli foreman-proxy)
download_minimal "$MINIMAL_DIR" "${PKGS[@]}"

# 3) Docs & bundle
write_readme "$DEST_ROOT"
write_repo_template "$DEST_ROOT"

BASENAME="$(basename "$DEST_ROOT")"
PARENT="$(dirname "$DEST_ROOT")"
TS="$(date +%Y%m%d-%H%M%S)"
OUT_TAR="${PARENT}/${BASENAME}-${TS}.tar"
tar_bundle "$DEST_ROOT" "$OUT_TAR"

log "DONE."
log "Hybrid bundle directory: $DEST_ROOT"
log "Tarball ready:           $OUT_TAR"
echo
echo "Next (connected host): copy the tarball to USB."
echo "On air-gapped host: extract to /opt/localrepos, copy sample-offline.repo to /etc/yum.repos.d/, then 'dnf makecache' and 'dnf -y install foreman-installer'."
