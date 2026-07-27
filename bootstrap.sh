#!/usr/bin/env bash
set -Eeuo pipefail

STUDENT_ID="${STUDENT_ID:-127878254}"
CLUSTER_NAME="clinic-${STUDENT_ID}"
NAMESPACE="clinic-${STUDENT_ID}"
KIND_CONTEXT="kind-${CLUSTER_NAME}"
WEB_URL="http://localhost:30080/"

show_diagnostics() {
  echo
  echo "========== BOOTSTRAP DIAGNOSTICS =========="

  kubectl get nodes -o wide 2>/dev/null || true
  kubectl get pods -n "${NAMESPACE}" -o wide 2>/dev/null || true
  kubectl get services -n "${NAMESPACE}" 2>/dev/null || true
  kubectl get endpoints -n "${NAMESPACE}" 2>/dev/null || true

  echo
  echo "Database logs:"
  kubectl logs deployment/db-"${STUDENT_ID}" \
    -n "${NAMESPACE}" \
    --tail=100 2>/dev/null || true

  echo
  echo "Web logs:"
  kubectl logs deployment/web-"${STUDENT_ID}" \
    -n "${NAMESPACE}" \
    --all-pods=true \
    --tail=100 2>/dev/null || true

  echo "==========================================="
}

trap 'echo "ERROR: bootstrap.sh failed at line ${LINENO}."; show_diagnostics' ERR

echo "Checking required commands..."

for command_name in docker kind kubectl curl; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "ERROR: ${command_name} is not installed or is not in PATH."
    exit 1
  fi
done

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker is not running."
  exit 1
fi

echo "Required tools are available."

if kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  echo "Deleting the existing Kind cluster: ${CLUSTER_NAME}"
  kind delete cluster --name "${CLUSTER_NAME}"
fi

echo "Creating Kind cluster: ${CLUSTER_NAME}"

kind create cluster \
  --name "${CLUSTER_NAME}" \
  --config manifests/kind-config.yaml

kubectl config use-context "${KIND_CONTEXT}"
kubectl cluster-info --context "${KIND_CONTEXT}"

echo "Applying the namespace and non-sensitive configuration..."

kubectl apply -f manifests/namespace.yaml
kubectl apply -f manifests/app-configmap.yaml
kubectl apply -f manifests/db-seed-configmap.yaml

echo "Creating the database Secret at runtime..."

if [[ -z "${DB_PASSWORD:-}" ]]; then
  while [[ -z "${DB_PASSWORD:-}" ]]; do
    read -rsp "Enter DB_PASSWORD: " DB_PASSWORD
    echo

    if [[ -z "${DB_PASSWORD}" ]]; then
      echo "DB_PASSWORD cannot be empty."
    fi
  done
fi

if [[ -z "${MYSQL_ROOT_PASSWORD:-}" ]]; then
  while [[ -z "${MYSQL_ROOT_PASSWORD:-}" ]]; do
    read -rsp "Enter MYSQL_ROOT_PASSWORD: " MYSQL_ROOT_PASSWORD
    echo

    if [[ -z "${MYSQL_ROOT_PASSWORD}" ]]; then
      echo "MYSQL_ROOT_PASSWORD cannot be empty."
    fi
  done
fi

kubectl create secret generic "db-secret-${STUDENT_ID}" \
  --namespace "${NAMESPACE}" \
  --from-literal=DB_PASSWORD="${DB_PASSWORD}" \
  --from-literal=MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
  --dry-run=client \
  -o yaml |
kubectl apply -f -

unset DB_PASSWORD
unset MYSQL_ROOT_PASSWORD

echo "Applying the database resources..."

kubectl apply -f manifests/db-deployment.yaml
kubectl apply -f manifests/db-service.yaml

echo "Waiting for the database Deployment..."

kubectl rollout status \
  deployment/db-"${STUDENT_ID}" \
  --namespace "${NAMESPACE}" \
  --timeout=300s

echo "Applying the web and troubleshooting resources..."

kubectl apply -f manifests/web-deployment.yaml
kubectl apply -f manifests/web-service.yaml
kubectl apply -f manifests/debug-pod.yaml

echo "Waiting for the web Deployment..."

kubectl rollout status \
  deployment/web-"${STUDENT_ID}" \
  --namespace "${NAMESPACE}" \
  --timeout=300s

echo "Waiting for the debug Pod..."

kubectl wait \
  --namespace "${NAMESPACE}" \
  --for=condition=Ready \
  pod/debug-"${STUDENT_ID}" \
  --timeout=180s

echo
echo "Current Kubernetes resources:"
kubectl get all -n "${NAMESPACE}"

echo
echo "Service endpoints:"
kubectl get endpoints -n "${NAMESPACE}"

echo
echo "Testing the web application at ${WEB_URL}"

for attempt in $(seq 1 30); do
  echo "Application test attempt ${attempt}/30..."

  if response=$(curl \
    --fail \
    --silent \
    --show-error \
    --max-time 10 \
    "${WEB_URL}"); then

    echo
    echo "${response}"
    echo
    echo "BOOTSTRAP PASSED"
    exit 0
  fi

  sleep 5
done

echo "BOOTSTRAP FAILED: the application did not respond successfully."
show_diagnostics
exit 1
