#!/usr/bin/env bash
set -euo pipefail

# Metal3 + Ironic Zarf package builder (run on ONLINE AlmaLinux/macOS)

# Resolve directories
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKDIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RENDERED_DIR="${WORKDIR}/rendered"
PACKAGES_DIR="${WORKDIR}/zarf-packages"
ARTIFACTS_DIR="${WORKDIR}/artifacts"
SRC_DIR="${WORKDIR}/src"

CONFIG_FILE="${1:-}"
if [[ -n "${CONFIG_FILE}" && -f "${CONFIG_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
elif [[ -f "${WORKDIR}/config.sh" ]]; then
  # shellcheck disable=SC1091
  source "${WORKDIR}/config.sh"
fi

# Defaults (override via config.sh or first-arg file)
BMO_TAG="${BMO_TAG:-v0.3.0}"
IRONIC_TAG="${IRONIC_TAG:-v0.3.0}"
BMO_REPO_URL="${BMO_REPO_URL:-https://github.com/metal3-io/baremetal-operator.git}"
IRONIC_REPO_URL="${IRONIC_REPO_URL:-https://github.com/metal3-io/ironic-deployment.git}"
IRONIC_OVERLAY_PATH="${IRONIC_OVERLAY_PATH:-overlay/default}"

echo "[info] Working dir: ${WORKDIR}"

check_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[error] Required command '$1' not found in PATH" >&2
    exit 1
  }
}

check_cmd git
check_cmd kustomize
check_cmd zarf

mkdir -p "${RENDERED_DIR}" "${PACKAGES_DIR}" "${ARTIFACTS_DIR}" "${SRC_DIR}"

# Validate IPA artifacts exist
if [[ ! -f "${ARTIFACTS_DIR}/ironic-python-agent.kernel" || ! -f "${ARTIFACTS_DIR}/ironic-python-agent.initramfs" ]]; then
  cat >&2 <<EOF
[error] Missing IPA artifacts in ${ARTIFACTS_DIR}
Expected files:
  - ${ARTIFACTS_DIR}/ironic-python-agent.kernel
  - ${ARTIFACTS_DIR}/ironic-python-agent.initramfs
Place them there, then re-run this script.
EOF
  exit 1
fi

echo "[step] Cloning/updating upstream repos"
if [[ ! -d "${SRC_DIR}/baremetal-operator/.git" ]]; then
  git clone --depth=1 "${BMO_REPO_URL}" "${SRC_DIR}/baremetal-operator"
else
  git -C "${SRC_DIR}/baremetal-operator" fetch --depth=1 origin
  git -C "${SRC_DIR}/baremetal-operator" reset --hard FETCH_HEAD
fi

if [[ ! -d "${SRC_DIR}/ironic-deployment/.git" ]]; then
  git clone --depth=1 "${IRONIC_REPO_URL}" "${SRC_DIR}/ironic-deployment"
else
  git -C "${SRC_DIR}/ironic-deployment" fetch --depth=1 origin
  git -C "${SRC_DIR}/ironic-deployment" reset --hard FETCH_HEAD
fi

echo "[step] Rendering manifests via kustomize"
kustomize build "${SRC_DIR}/baremetal-operator/config/default" > "${RENDERED_DIR}/bmo.yaml"
kustomize build "${SRC_DIR}/ironic-deployment/${IRONIC_OVERLAY_PATH}" > "${RENDERED_DIR}/ironic.yaml"

echo "[step] Writing IPA server manifest"
cat > "${RENDERED_DIR}/ipa-server.yaml" <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: ipa-server
  namespace: metal3
spec:
  selector:
    app: ipa-server
  ports:
    - port: 80
      targetPort: 80
      protocol: TCP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ipa-server
  namespace: metal3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ipa-server
  template:
    metadata:
      labels:
        app: ipa-server
    spec:
      nodeName: ${ZARF_VAR_IPA_NODE_NAME}
      containers:
        - name: nginx
          image: docker.io/library/nginx:1.25-alpine
          ports:
            - containerPort: 80
          volumeMounts:
            - name: ipa-data
              mountPath: /usr/share/nginx/html
      volumes:
        - name: ipa-data
          hostPath:
            path: /opt/metal3/ipa
            type: Directory
EOF

echo "[step] Writing Zarf package configs"
cat > "${PACKAGES_DIR}/zarf-bmo.yaml" <<'EOF'
apiVersion: zarf.dev/v1alpha1
kind: ZarfPackageConfig
metadata:
  name: metal3-bmo
  version: 0.1.0
  description: Metal3 BareMetal Operator (CRDs + controller)
variables:
  - name: BMO_TAG
    default: "v0.3.0"
components:
  - name: bmo
    required: true
    defaultNamespace: metal3
    manifests:
      - name: bmo
        namespace: metal3
        files:
          - ../rendered/bmo.yaml
    images:
      - quay.io/metal3-io/baremetal-operator:${ZARF_VAR_BMO_TAG}
    actions:
      onDeploy:
        after:
          - description: Wait for BMO controller to be Available
            wait:
              cluster:
                kind: Deployment
                name: baremetal-operator-controller-manager
                namespace: metal3
                condition: Available
                timeoutSeconds: 600
EOF

cat > "${PACKAGES_DIR}/zarf-ironic.yaml" <<'EOF'
apiVersion: zarf.dev/v1alpha1
kind: ZarfPackageConfig
metadata:
  name: metal3-ironic
  version: 0.1.0
  description: Metal3 Ironic services with in-cluster IPA server (no internet)
variables:
  - name: IRONIC_TAG
    default: "v0.3.0"
  - name: IPA_NODE_NAME
    default: ""
components:
  - name: ironic
    required: true
    defaultNamespace: metal3
    images:
      - quay.io/metal3-io/ironic:${ZARF_VAR_IRONIC_TAG}
      - quay.io/metal3-io/ironic-inspector:${ZARF_VAR_IRONIC_TAG}
      - quay.io/metal3-io/ironic-ipa-downloader:${ZARF_VAR_IRONIC_TAG}
      - quay.io/metal3-io/ironic-httpd:${ZARF_VAR_IRONIC_TAG}
      - quay.io/metal3-io/ironic-dnsmasq:${ZARF_VAR_IRONIC_TAG}
      - quay.io/metal3-io/ironic-mariadb:${ZARF_VAR_IRONIC_TAG}
      - quay.io/metal3-io/ironic-keepalived:${ZARF_VAR_IRONIC_TAG}
      - docker.io/library/nginx:1.25-alpine
    manifests:
      - name: ironic
        namespace: metal3
        files:
          - ../rendered/ironic.yaml
          - ../rendered/ipa-server.yaml
    files:
      - source: ../artifacts/ironic-python-agent.kernel
        target: /opt/metal3/ipa/ironic-python-agent.kernel
      - source: ../artifacts/ironic-python-agent.initramfs
        target: /opt/metal3/ipa/ironic-python-agent.initramfs
    actions:
      onDeploy:
        before:
          - description: Create metal3 namespace if missing
            cmd: kubectl get ns metal3 >/dev/null 2>&1 || kubectl create ns metal3
        after:
          - description: Point ipa-downloader to in-cluster IPA server
            cmd: kubectl -n metal3 set env deployment/ironic-ipa-downloader IPA_BASEURI=http://ipa-server.metal3.svc.cluster.local
          - description: Wait for Ironic pods to be ready (best-effort)
            wait:
              cluster:
                kind: Deployment
                name: ironic
                namespace: metal3
                condition: Available
                timeoutSeconds: 900
EOF

echo "[step] Building Zarf packages"
(
  cd "${PACKAGES_DIR}"
  zarf package create zarf-bmo.yaml --confirm
  zarf package create zarf-ironic.yaml --confirm
)

echo "[done] Packages created in: ${PACKAGES_DIR}"
ls -1t "${PACKAGES_DIR}"/zarf-package-metal3-*.tar.zst 2>/dev/null || true


