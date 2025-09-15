#!/usr/bin/env bash
set -euo pipefail

# Metal3 + Ironic Zarf deployer (run on AIR-GAPPED k3s control-plane node)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKDIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PACKAGES_DIR="${WORKDIR}/zarf-packages"

CONFIG_FILE="${1:-}"
if [[ -n "${CONFIG_FILE}" && -f "${CONFIG_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
elif [[ -f "${WORKDIR}/config.sh" ]]; then
  # shellcheck disable=SC1091
  source "${WORKDIR}/config.sh"
fi

# Defaults (override via config.sh)
BMO_TAG="${BMO_TAG:-v0.3.0}"
IRONIC_TAG="${IRONIC_TAG:-v0.3.0}"
IPA_NODE_NAME="${IPA_NODE_NAME:-}"

if [[ -z "${IPA_NODE_NAME}" ]]; then
  echo "[error] IPA_NODE_NAME is required. Set it in config.sh or pass a config file as first argument." >&2
  echo "Hint: kubectl get nodes -o name" >&2
  exit 1
fi

check_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[error] Required command '$1' not found in PATH" >&2
    exit 1
  }
}

check_cmd kubectl
check_cmd zarf

echo "[step] Ensuring Zarf is initialized (with registry)"
zarf init --components=container-registry --confirm || true

echo "[step] Creating namespace metal3 (if missing)"
kubectl get ns metal3 >/dev/null 2>&1 || kubectl create ns metal3

echo "[step] Preparing hostPath directory for IPA artifacts: /opt/metal3/ipa"
sudo mkdir -p /opt/metal3/ipa
sudo chown "$(id -u)":"$(id -g)" /opt/metal3/ipa || true
sudo chmod 755 /opt/metal3/ipa || true

echo "[step] Locating Zarf packages in ${PACKAGES_DIR}"
BMO_PKG=$(ls -1t "${PACKAGES_DIR}"/zarf-package-metal3-bmo-*.tar.zst | head -n1 || true)
IRONIC_PKG=$(ls -1t "${PACKAGES_DIR}"/zarf-package-metal3-ironic-*.tar.zst | head -n1 || true)

if [[ -z "${BMO_PKG}" || -z "${IRONIC_PKG}" ]]; then
  echo "[error] Could not find required packages under ${PACKAGES_DIR}." >&2
  echo "Expected files matching: zarf-package-metal3-bmo-*.tar.zst and zarf-package-metal3-ironic-*.tar.zst" >&2
  exit 1
fi

echo "[step] Deploying BMO package: ${BMO_PKG}"
zarf package deploy "${BMO_PKG}" --confirm --set BMO_TAG="${BMO_TAG}"

echo "[step] Deploying Ironic package: ${IRONIC_PKG}"
zarf package deploy "${IRONIC_PKG}" --confirm \
  --set IRONIC_TAG="${IRONIC_TAG}" \
  --set IPA_NODE_NAME="${IPA_NODE_NAME}"

echo "[verify] Pods in metal3 namespace"
kubectl -n metal3 get pods -o wide || true
echo "[verify] IPA server service"
kubectl -n metal3 get svc ipa-server || true
echo "[verify] BMH CRDs"
kubectl get crds | grep baremetalhost || true

echo "[done] Deployment complete"


