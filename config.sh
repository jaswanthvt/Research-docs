#!/usr/bin/env bash
# User-editable configuration for Zarf Metal3 build/deploy

# Image tags (pin as needed)
export BMO_TAG="v0.3.0"
export IRONIC_TAG="v0.3.0"

# Upstream repos and overlay
export BMO_REPO_URL="https://github.com/metal3-io/baremetal-operator.git"
export IRONIC_REPO_URL="https://github.com/metal3-io/ironic-deployment.git"
export IRONIC_OVERLAY_PATH="overlay/default"

# For air-gapped deploy: set to the node that will host IPA files via hostPath
# kubectl get nodes -o name
export IPA_NODE_NAME=""


