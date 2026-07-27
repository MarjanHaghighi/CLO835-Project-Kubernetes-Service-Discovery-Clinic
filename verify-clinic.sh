#!/usr/bin/env bash
set -Eeuo pipefail

STUDENT_ID="${STUDENT_ID:-127878254}"
CLUSTER_NAME="clinic-${STUDENT_ID}"
CONTEXT="kind-${CLUSTER_NAME}"
NAMESPACE="clinic-${STUDENT_ID}"

DB_DEPLOYMENT="db-${STUDENT_ID}"
WEB_DEPLOYMENT="web-${STUDENT_ID}"

DB_SERVICE="db-svc-${STUDENT_ID}"
WEB_SERVICE="web-svc-${STUDENT_ID}"

APP_CONFIGMAP="app-config-${STUDENT_ID}"
DB_SEED_CONFIGMAP="db-seed-${STUDENT_ID}"
DB_SECRET="db-secret-${STUDENT_ID}"
DEBUG_POD="debug-${STUDENT_ID}"

WEB_URL="http://localhost:30080"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

section() {
  echo
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

pass() {
  echo "PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "FAIL: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
  echo "WARNING: $1"
  WARN_COUNT=$((WARN_COUNT + 1))
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

section "1. Local prerequisite checks"

for command_name in docker kind kubectl curl; do
  if command_exists "${command_name}"; then
    pass "${command_name} is installed"
  else
    fail "${command_name} is not installed or not in PATH"
  fi
done

if docker info >/dev/null 2>&1; then
  pass "Docker is running"
else
  fail "Docker is not running"
fi

section "2. Kind cluster and Kubernetes context"

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  pass "Kind cluster ${CLUSTER_NAME} exists"
else
  fail "Kind cluster ${CLUSTER_NAME} does not exist"
fi

CURRENT_CONTEXT="$(kubectl config current-context 2>/dev/null || true)"

if [[ "${CURRENT_CONTEXT}" == "${CONTEXT}" ]]; then
  pass "Current context is ${CONTEXT}"
else
  warn "Current context is ${CURRENT_CONTEXT:-none}; switching to ${CONTEXT}"

  if kubectl config use-context "${CONTEXT}" >/dev/null 2>&1; then
    pass "Switched to ${CONTEXT}"
  else
    fail "Could not switch to ${CONTEXT}"
  fi
fi

kubectl cluster-info --context "${CONTEXT}" || true

section "3. Node status"

kubectl get nodes -o wide || true

NODE_COUNT="$(
  kubectl get nodes --no-headers 2>/dev/null |
  wc -l |
  tr -d ' '
)"

NOT_READY_NODES="$(
  kubectl get nodes --no-headers 2>/dev/null |
  awk '$2 != "Ready" {count++} END {print count+0}'
)"

if [[ "${NODE_COUNT}" -eq 3 && "${NOT_READY_NODES}" -eq 0 ]]; then
  pass "All three Kind nodes are Ready"
elif [[ "${NODE_COUNT}" -gt 0 && "${NOT_READY_NODES}" -eq 0 ]]; then
  warn "${NODE_COUNT} nodes are Ready, but three nodes were expected"
else
  fail "One or more Kubernetes nodes are not Ready"
fi

section "4. Namespace and deployed resources"

if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  pass "Namespace ${NAMESPACE} exists"
else
  fail "Namespace ${NAMESPACE} does not exist"
fi

kubectl get all -n "${NAMESPACE}" -o wide || true
kubectl get configmaps,secrets -n "${NAMESPACE}" || true

section "5. Deployment rollout status"

if kubectl rollout status \
  deployment/"${DB_DEPLOYMENT}" \
  -n "${NAMESPACE}" \
  --timeout=20s; then
  pass "Database Deployment successfully rolled out"
else
  fail "Database Deployment is not successfully rolled out"
fi

if kubectl rollout status \
  deployment/"${WEB_DEPLOYMENT}" \
  -n "${NAMESPACE}" \
  --timeout=20s; then
  pass "Web Deployment successfully rolled out"
else
  fail "Web Deployment is not successfully rolled out"
fi

section "6. Pod readiness and restart counts"

kubectl get pods -n "${NAMESPACE}" -o wide || true

NOT_READY_PODS="$(
  kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null |
  awk '
    {
      split($2, ready, "/")
      if (ready[1] != ready[2] || $3 != "Running") {
        count++
      }
    }
    END {print count+0}
  '
)"

if [[ "${NOT_READY_PODS}" -eq 0 ]]; then
  pass "All namespace Pods are Running and Ready"
else
  fail "${NOT_READY_PODS} Pod or Pods are not Running and Ready"
fi

RESTARTED_PODS="$(
  kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null |
  awk '$4 > 0 {count++} END {print count+0}'
)"

if [[ "${RESTARTED_PODS}" -eq 0 ]]; then
  pass "No application Pods have restarted"
else
  warn "${RESTARTED_PODS} Pod or Pods have restart counts greater than zero"
fi

section "7. ConfigMap checks"

if kubectl get configmap "${APP_CONFIGMAP}" \
  -n "${NAMESPACE}" >/dev/null 2>&1; then
  pass "Application ConfigMap exists"
else
  fail "Application ConfigMap is missing"
fi

if kubectl get configmap "${DB_SEED_CONFIGMAP}" \
  -n "${NAMESPACE}" >/dev/null 2>&1; then
  pass "Database seed ConfigMap exists"
else
  fail "Database seed ConfigMap is missing"
fi

check_configmap_key() {
  local key="$1"
  local value

  value="$(
    kubectl get configmap "${APP_CONFIGMAP}" \
      -n "${NAMESPACE}" \
      -o "jsonpath={.data.${key}}" \
      2>/dev/null || true
  )"

  if [[ -n "${value}" ]]; then
    pass "ConfigMap contains ${key}"
  else
    fail "ConfigMap is missing ${key}"
  fi
}

for required_key in \
  STUDENT_ID \
  DB_HOST \
  DB_PORT \
  DB_NAME \
  DB_USER \
  APP_PORT; do
  check_configmap_key "${required_key}"
done

CONFIG_STUDENT_ID="$(
  kubectl get configmap "${APP_CONFIGMAP}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.data.STUDENT_ID}' \
    2>/dev/null || true
)"

CONFIG_DB_HOST="$(
  kubectl get configmap "${APP_CONFIGMAP}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.data.DB_HOST}' \
    2>/dev/null || true
)"

CONFIG_DB_PORT="$(
  kubectl get configmap "${APP_CONFIGMAP}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.data.DB_PORT}' \
    2>/dev/null || true
)"

CONFIG_DB_NAME="$(
  kubectl get configmap "${APP_CONFIGMAP}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.data.DB_NAME}' \
    2>/dev/null || true
)"

CONFIG_DB_USER="$(
  kubectl get configmap "${APP_CONFIGMAP}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.data.DB_USER}' \
    2>/dev/null || true
)"

CONFIG_APP_PORT="$(
  kubectl get configmap "${APP_CONFIGMAP}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.data.APP_PORT}' \
    2>/dev/null || true
)"

[[ "${CONFIG_STUDENT_ID}" == "${STUDENT_ID}" ]] \
  && pass "ConfigMap STUDENT_ID is correct" \
  || fail "ConfigMap STUDENT_ID is ${CONFIG_STUDENT_ID:-missing}"

[[ "${CONFIG_DB_HOST}" == "${DB_SERVICE}" ]] \
  && pass "ConfigMap DB_HOST is correct" \
  || fail "ConfigMap DB_HOST is ${CONFIG_DB_HOST:-missing}, expected ${DB_SERVICE}"

[[ "${CONFIG_DB_PORT}" == "3306" ]] \
  && pass "ConfigMap DB_PORT is correct" \
  || fail "ConfigMap DB_PORT is ${CONFIG_DB_PORT:-missing}, expected 3306"

[[ "${CONFIG_DB_NAME}" == "clinicdb" ]] \
  && pass "ConfigMap DB_NAME is correct" \
  || fail "ConfigMap DB_NAME is ${CONFIG_DB_NAME:-missing}, expected clinicdb"

[[ "${CONFIG_DB_USER}" == "clinicuser" ]] \
  && pass "ConfigMap DB_USER is correct" \
  || fail "ConfigMap DB_USER is ${CONFIG_DB_USER:-missing}, expected clinicuser"

[[ "${CONFIG_APP_PORT}" == "8080" ]] \
  && pass "ConfigMap APP_PORT is correct" \
  || fail "ConfigMap APP_PORT is ${CONFIG_APP_PORT:-missing}, expected 8080"

section "8. Secret checks"

if kubectl get secret "${DB_SECRET}" \
  -n "${NAMESPACE}" >/dev/null 2>&1; then
  pass "Database Secret exists"
else
  fail "Database Secret is missing"
fi

check_secret_key() {
  local key="$1"
  local encoded_value

  encoded_value="$(
    kubectl get secret "${DB_SECRET}" \
      -n "${NAMESPACE}" \
      -o "jsonpath={.data.${key}}" \
      2>/dev/null || true
  )"

  if [[ -n "${encoded_value}" ]]; then
    pass "Secret contains ${key}"
  else
    fail "Secret is missing ${key}"
  fi
}

check_secret_key "DB_PASSWORD"
check_secret_key "MYSQL_ROOT_PASSWORD"

SECRET_DB_USER="$(
  kubectl get secret "${DB_SECRET}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.data.DB_USER}' \
    2>/dev/null || true
)"

if [[ -z "${SECRET_DB_USER}" ]]; then
  pass "DB_USER is not duplicated in the Secret"
else
  warn "DB_USER is stored in the Secret, but it should come from the ConfigMap"
fi

section "9. Service configuration"

kubectl get services -n "${NAMESPACE}" -o wide || true

if kubectl get service "${DB_SERVICE}" \
  -n "${NAMESPACE}" >/dev/null 2>&1; then
  pass "Database Service exists"
else
  fail "Database Service is missing"
fi

if kubectl get service "${WEB_SERVICE}" \
  -n "${NAMESPACE}" >/dev/null 2>&1; then
  pass "Web Service exists"
else
  fail "Web Service is missing"
fi

DB_SERVICE_PORT="$(
  kubectl get service "${DB_SERVICE}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.spec.ports[0].port}' \
    2>/dev/null || true
)"

WEB_NODE_PORT="$(
  kubectl get service "${WEB_SERVICE}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.spec.ports[0].nodePort}' \
    2>/dev/null || true
)"

if [[ "${DB_SERVICE_PORT}" == "3306" ]]; then
  pass "Database Service exposes port 3306"
else
  fail "Database Service port is ${DB_SERVICE_PORT:-missing}, expected 3306"
fi

if [[ "${WEB_NODE_PORT}" == "30080" ]]; then
  pass "Web Service uses NodePort 30080"
else
  fail "Web Service NodePort is ${WEB_NODE_PORT:-missing}, expected 30080"
fi

section "10. EndpointSlice and endpoint checks"

kubectl get endpointslices.discovery.k8s.io -n "${NAMESPACE}" || true

DB_ENDPOINTS="$(
  kubectl get endpointslices.discovery.k8s.io \
    -n "${NAMESPACE}" \
    -l "kubernetes.io/service-name=${DB_SERVICE}" \
    -o jsonpath='{.items[*].endpoints[*].addresses[*]}' \
    2>/dev/null || true
)"

WEB_ENDPOINTS="$(
  kubectl get endpointslices.discovery.k8s.io \
    -n "${NAMESPACE}" \
    -l "kubernetes.io/service-name=${WEB_SERVICE}" \
    -o jsonpath='{.items[*].endpoints[*].addresses[*]}' \
    2>/dev/null || true
)"

if [[ -n "${DB_ENDPOINTS}" ]]; then
  pass "Database Service has endpoint: ${DB_ENDPOINTS}"
else
  fail "Database Service has no Ready endpoint"
fi

WEB_ENDPOINT_COUNT="$(
  awk '{print NF}' <<< "${WEB_ENDPOINTS}"
)"

if [[ "${WEB_ENDPOINT_COUNT}" -eq 2 ]]; then
  pass "Web Service has two endpoints: ${WEB_ENDPOINTS}"
elif [[ "${WEB_ENDPOINT_COUNT}" -gt 0 ]]; then
  warn "Web Service has ${WEB_ENDPOINT_COUNT} endpoint(s), expected two"
else
  fail "Web Service has no Ready endpoints"
fi

section "11. Pod labels and Service selectors"

kubectl get pods -n "${NAMESPACE}" --show-labels || true

DB_LABEL_COUNT="$(
  kubectl get pods \
    -n "${NAMESPACE}" \
    -l "app=db,owner=${STUDENT_ID}" \
    --no-headers 2>/dev/null |
  wc -l |
  tr -d ' '
)"

WEB_LABEL_COUNT="$(
  kubectl get pods \
    -n "${NAMESPACE}" \
    -l "app=web,owner=${STUDENT_ID}" \
    --no-headers 2>/dev/null |
  wc -l |
  tr -d ' '
)"

if [[ "${DB_LABEL_COUNT}" -eq 1 ]]; then
  pass "One database Pod matches the required labels"
else
  fail "${DB_LABEL_COUNT} database Pods match the required labels; expected one"
fi

if [[ "${WEB_LABEL_COUNT}" -eq 2 ]]; then
  pass "Two web Pods match the required labels"
else
  fail "${WEB_LABEL_COUNT} web Pods match the required labels; expected two"
fi

section "12. Identify Pods"

DB_POD="$(
  kubectl get pods \
    -n "${NAMESPACE}" \
    -l "app=db,owner=${STUDENT_ID}" \
    -o jsonpath='{.items[0].metadata.name}' \
    2>/dev/null || true
)"

WEB_POD="$(
  kubectl get pods \
    -n "${NAMESPACE}" \
    -l "app=web,owner=${STUDENT_ID}" \
    -o jsonpath='{.items[0].metadata.name}' \
    2>/dev/null || true
)"

echo "Database Pod: ${DB_POD:-not found}"
echo "Web Pod: ${WEB_POD:-not found}"
echo "Debug Pod: ${DEBUG_POD}"

[[ -n "${DB_POD}" ]] \
  && pass "Database Pod was identified" \
  || fail "Database Pod could not be identified"

[[ -n "${WEB_POD}" ]] \
  && pass "Web Pod was identified" \
  || fail "Web Pod could not be identified"

if kubectl get pod "${DEBUG_POD}" \
  -n "${NAMESPACE}" >/dev/null 2>&1; then
  pass "Debug Pod exists"
else
  fail "Debug Pod is missing"
fi

section "13. Application environment variables"

if [[ -n "${WEB_POD}" ]]; then
  kubectl exec -n "${NAMESPACE}" "${WEB_POD}" -- \
    sh -c 'env | grep -E "^(STUDENT_ID|DB_HOST|DB_PORT|DB_NAME|DB_USER|APP_PORT)="' \
    || true

  POD_DB_HOST="$(
    kubectl exec -n "${NAMESPACE}" "${WEB_POD}" -- \
      sh -c 'printf "%s" "$DB_HOST"' 2>/dev/null || true
  )"

  POD_APP_PORT="$(
    kubectl exec -n "${NAMESPACE}" "${WEB_POD}" -- \
      sh -c 'printf "%s" "$APP_PORT"' 2>/dev/null || true
  )"

  [[ "${POD_DB_HOST}" == "${DB_SERVICE}" ]] \
    && pass "Web Pod DB_HOST matches ${DB_SERVICE}" \
    || fail "Web Pod DB_HOST is ${POD_DB_HOST:-missing}"

  [[ "${POD_APP_PORT}" == "8080" ]] \
    && pass "Web Pod APP_PORT is 8080" \
    || fail "Web Pod APP_PORT is ${POD_APP_PORT:-missing}"
else
  fail "Environment variables could not be tested because no web Pod was found"
fi

section "14. DNS tests from the debug Pod"

DB_CLUSTER_IP="$(
  kubectl get service "${DB_SERVICE}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.spec.clusterIP}' \
    2>/dev/null || true
)"

echo "Database Service ClusterIP: ${DB_CLUSTER_IP:-missing}"

SHORT_DNS_OUTPUT="$(
  kubectl exec -n "${NAMESPACE}" "${DEBUG_POD}" -- \
    nslookup "${DB_SERVICE}" 2>&1 || true
)"

echo "${SHORT_DNS_OUTPUT}"

if [[ -n "${DB_CLUSTER_IP}" ]] &&
   grep -Fq "${DB_CLUSTER_IP}" <<< "${SHORT_DNS_OUTPUT}"; then
  pass "Short database Service name resolves to ${DB_CLUSTER_IP}"
else
  fail "Short database Service name does not resolve to ${DB_CLUSTER_IP:-the Service IP}"
fi

FULL_DB_DNS="${DB_SERVICE}.${NAMESPACE}.svc.cluster.local"

FULL_DNS_OUTPUT="$(
  kubectl exec -n "${NAMESPACE}" "${DEBUG_POD}" -- \
    nslookup "${FULL_DB_DNS}" 2>&1 || true
)"

echo "${FULL_DNS_OUTPUT}"

if [[ -n "${DB_CLUSTER_IP}" ]] &&
   grep -Fq "${DB_CLUSTER_IP}" <<< "${FULL_DNS_OUTPUT}"; then
  pass "Full database Service DNS name resolves to ${DB_CLUSTER_IP}"
else
  fail "Full database Service DNS name does not resolve correctly"
fi

KUBERNETES_DNS_OUTPUT="$(
  kubectl exec -n "${NAMESPACE}" "${DEBUG_POD}" -- \
    nslookup kubernetes.default.svc.cluster.local 2>&1 || true
)"

echo "${KUBERNETES_DNS_OUTPUT}"

if grep -Eq 'Address:[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
  <<< "${KUBERNETES_DNS_OUTPUT}"; then
  pass "Kubernetes default Service DNS resolves"
else
  fail "Kubernetes default Service DNS does not resolve"
fi

EXTERNAL_DNS_OUTPUT="$(
  kubectl exec -n "${NAMESPACE}" "${DEBUG_POD}" -- \
    nslookup google.com 2>&1 || true
)"

echo "${EXTERNAL_DNS_OUTPUT}"

if grep -Eq 'Address:[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
  <<< "${EXTERNAL_DNS_OUTPUT}"; then
  pass "External DNS resolution works"
else
  warn "External DNS resolution failed"
fi

section "15. Database TCP connectivity"

if kubectl exec -n "${NAMESPACE}" "${DEBUG_POD}" -- \
  sh -c "nc -z -w 5 ${DB_SERVICE} 3306"; then
  pass "Debug Pod can connect to database port 3306"
else
  fail "Debug Pod cannot connect to database port 3306"
fi

section "16. Seeded database records"

if [[ -n "${DB_POD}" ]]; then
  if kubectl exec -n "${NAMESPACE}" "${DB_POD}" -- \
    sh -c 'mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
      -e "SELECT * FROM clinic_items;"'; then
    pass "Database query executed successfully"
  else
    fail "Database query failed"
  fi

  ROW_COUNT="$(
    kubectl exec -n "${NAMESPACE}" "${DB_POD}" -- \
      sh -c 'mysql -N -s -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
        -e "SELECT COUNT(*) FROM clinic_items;"' \
      2>/dev/null |
    tail -n 1 |
    tr -d '[:space:]' || true
  )"

  if [[ "${ROW_COUNT}" == "5" ]]; then
    pass "Database contains five seeded records"
  else
    fail "Database contains ${ROW_COUNT:-unknown} seeded records; expected five"
  fi

  STUDENT_ID_ROW_COUNT="$(
    kubectl exec -n "${NAMESPACE}" "${DB_POD}" -- \
      sh -c "mysql -N -s -u\"\$MYSQL_USER\" -p\"\$MYSQL_PASSWORD\" \
        \"\$MYSQL_DATABASE\" \
        -e \"SELECT COUNT(*) FROM clinic_items WHERE student_id='${STUDENT_ID}';\"" \
      2>/dev/null |
    tail -n 1 |
    tr -d '[:space:]' || true
  )"

  if [[ "${STUDENT_ID_ROW_COUNT}" == "5" ]]; then
    pass "All five database records contain student ID ${STUDENT_ID}"
  else
    fail "Only ${STUDENT_ID_ROW_COUNT:-unknown} records contain student ID ${STUDENT_ID}"
  fi
else
  fail "Database records could not be tested because no database Pod was found"
fi

section "17. External HTTP tests"

test_http_route() {
  local route="$1"
  local description="$2"
  local expected_code="${3:-200}"
  local response_file="/tmp/clinic-response-${STUDENT_ID}.txt"
  local code

  code="$(
    curl \
      --silent \
      --show-error \
      --output "${response_file}" \
      --write-out '%{http_code}' \
      --max-time 10 \
      "${WEB_URL}${route}" 2>/dev/null || true
  )"

  if [[ "${code}" == "${expected_code}" ]]; then
    pass "${description} returned HTTP ${expected_code}"
    echo "Response:"
    cat "${response_file}"
    echo
  else
    fail "${description} returned HTTP ${code:-connection failure}; expected ${expected_code}"
  fi

  rm -f "${response_file}"
}

test_http_route "/" "Main application route"
test_http_route "/live" "Liveness route"
test_http_route "/ready" "Readiness route"

section "18. Probe configuration"

READINESS_PATH="$(
  kubectl get deployment "${WEB_DEPLOYMENT}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}' \
    2>/dev/null || true
)"

LIVENESS_PATH="$(
  kubectl get deployment "${WEB_DEPLOYMENT}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.httpGet.path}' \
    2>/dev/null || true
)"

[[ "${READINESS_PATH}" == "/ready" ]] \
  && pass "Web readiness probe uses /ready" \
  || fail "Web readiness probe uses ${READINESS_PATH:-no path}"

[[ "${LIVENESS_PATH}" == "/live" ]] \
  && pass "Web liveness probe uses /live" \
  || fail "Web liveness probe uses ${LIVENESS_PATH:-no path}"

section "19. CoreDNS health checks"

kubectl get deployment coredns -n kube-system || true
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide || true

COREDNS_AVAILABLE="$(
  kubectl get deployment coredns \
    -n kube-system \
    -o jsonpath='{.status.availableReplicas}' \
    2>/dev/null || true
)"

COREDNS_DESIRED="$(
  kubectl get deployment coredns \
    -n kube-system \
    -o jsonpath='{.spec.replicas}' \
    2>/dev/null || true
)"

if [[ -n "${COREDNS_AVAILABLE}" &&
      "${COREDNS_AVAILABLE}" == "${COREDNS_DESIRED}" ]]; then
  pass "All CoreDNS replicas are available"
else
  fail "CoreDNS available replicas are ${COREDNS_AVAILABLE:-0}/${COREDNS_DESIRED:-unknown}"
fi

if kubectl get configmap coredns -n kube-system >/dev/null 2>&1; then
  pass "CoreDNS ConfigMap exists"
else
  fail "CoreDNS ConfigMap is missing"
fi

section "20. Recent namespace events"

kubectl get events \
  -n "${NAMESPACE}" \
  --sort-by='.lastTimestamp' || true

WARNING_EVENTS="$(
  kubectl get events \
    -n "${NAMESPACE}" \
    --field-selector type=Warning \
    --no-headers 2>/dev/null |
  wc -l |
  tr -d ' '
)"

if [[ "${WARNING_EVENTS}" -eq 0 ]]; then
  pass "No Warning events are currently listed"
else
  warn "${WARNING_EVENTS} Warning event(s) are listed; review the output above"
fi

section "21. Recent application logs"

echo
echo "----- Database logs -----"
kubectl logs deployment/"${DB_DEPLOYMENT}" \
  -n "${NAMESPACE}" \
  --tail=30 || true

echo
echo "----- Web logs -----"
kubectl logs deployment/"${WEB_DEPLOYMENT}" \
  -n "${NAMESPACE}" \
  --all-pods=true \
  --tail=30 || true

section "Verification summary"

echo "Passed checks:   ${PASS_COUNT}"
echo "Failed checks:   ${FAIL_COUNT}"
echo "Warnings:        ${WARN_COUNT}"

if [[ "${FAIL_COUNT}" -eq 0 ]]; then
  echo
  echo "CLINIC VERIFICATION PASSED"
  exit 0
else
  echo
  echo "CLINIC VERIFICATION FAILED"
  echo "Review the failed checks above before starting failure scenarios."
  exit 1
fi
