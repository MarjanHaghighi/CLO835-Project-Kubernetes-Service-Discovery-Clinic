# Project 14 – Service Discovery Failure Clinic
# Diagnosis Tree

**Student Name:** ___________________

**Student ID:** 127878254

**Namespace:** clinic-127878254

**Cluster:** clinic-127878254

---

# Objective

Identify why the web application cannot communicate with the database by following a structured troubleshooting process.

**Golden Rule**

For every command during the demo:

1. State your prediction.
2. Execute the command.
3. Compare the output with your prediction.
4. Decide the next branch.

Never guess.

---

# Layer 0 – Confirm the Symptom

## Prediction

"I expect the web application to fail because it cannot reach the database."

## Command

```bash
kubectl logs deployment/web-127878254 -n clinic-127878254
```

or

```bash
curl http://<EC2-PUBLIC-IP>:30080
```

### Healthy

Application returns

- Student ID
- Database Service name
- Seeded row

Diagnosis

System is healthy.

STOP

---

### Failure

Possible errors

```
Name or service not known
```

```
Temporary failure in name resolution
```

```
Connection refused
```

```
Connection timed out
```

↓

Continue to Layer 1.

---

# Layer 1 – Does the Service Exist?

## Prediction

"If the Service was renamed or deleted, Kubernetes cannot resolve it."

## Command

```bash
kubectl get svc -n clinic-127878254
```

Healthy

```
db-svc-127878254
```

↓

Continue to Layer 2

---

Service Missing

Diagnosis

Service layer failure

Repair

```bash
kubectl apply -f manifests/db-service.yaml
```

Verify

```bash
kubectl get svc -n clinic-127878254
```

If Service exists

↓

Continue

---

# Layer 2 – Does the Service Have Endpoints?

## Prediction

"If the Service has no Endpoints, Kubernetes cannot forward traffic."

Command

```bash
kubectl get endpoints -n clinic-127878254
```

Healthy

```
db-svc-127878254
10.x.x.x:3306
```

↓

Continue to Layer 4

---

Endpoints EMPTY

Possible causes

• Database Pod stopped

• Readiness failed

• Selector mismatch

↓

Continue to Layer 3

---

# Layer 3 – Why Are Endpoints Empty?

## Check Database Pods

Prediction

"I expect the database Pod is not Running."

Command

```bash
kubectl get pods -n clinic-127878254
```

Healthy

```
db Running
```

If NOT Running

Repair

```bash
kubectl rollout restart deployment/db-127878254 \
-n clinic-127878254
```

or

```bash
kubectl scale deployment db-127878254 \
--replicas=1 \
-n clinic-127878254
```

Verify

```bash
kubectl get pods
```

---

## Check Readiness

Prediction

"The Pod is running but not Ready."

Command

```bash
kubectl describe pod <db-pod> \
-n clinic-127878254
```

Look for

```
Readiness probe failed
```

Repair

Fix readiness issue.

---

## Check Selector vs Labels

Prediction

"The Service selector no longer matches Pod labels."

Commands

```bash
kubectl describe svc db-svc-127878254 \
-n clinic-127878254
```

```bash
kubectl get pods \
--show-labels \
-n clinic-127878254
```

Healthy

Selector

```
app=db
owner=127878254
```

matches Pod labels

Repair

Correct selector or labels.

Verify

```bash
kubectl get endpoints
```

Endpoints populated

↓

Continue to Layer 7

---

# Layer 4 – Verify DNS Resolution

Prediction

"The Service exists but DNS resolution is failing."

Enter Debug Pod

```bash
kubectl exec -it debug-127878254 \
-n clinic-127878254 \
-- sh
```

Check Resolver

```bash
cat /etc/resolv.conf
```

Explain

• nameserver

• search domains

• ndots:5

---

DNS Test 1

```bash
nslookup db-svc-127878254
```

Healthy

Returns ClusterIP

↓

Continue to Layer 7

Fails

↓

Continue to Layer 5

---

DNS Test 2

```bash
nslookup db-svc-127878254.clinic-127878254
```

---

DNS Test 3

```bash
nslookup db-svc-127878254.clinic-127878254.svc
```

---

DNS Test 4

```bash
nslookup db-svc-127878254.clinic-127878254.svc.cluster.local
```

Exit

```bash
exit
```

---

# Layer 5 – CoreDNS Investigation

Prediction

"I expect CoreDNS configuration or CoreDNS Pods are broken."

Check Pods

```bash
kubectl get pods \
-n kube-system \
-l k8s-app=kube-dns
```

Check ConfigMap

```bash
kubectl get configmap coredns \
-n kube-system \
-o yaml
```

Check Logs

```bash
kubectl logs \
-n kube-system \
-l k8s-app=kube-dns
```

Healthy

No syntax errors

DNS plugin loaded

---

Broken Corefile

Repair

```bash
kubectl apply \
-f manifests/coredns-known-good.yaml \
-n kube-system
```

Restart

```bash
kubectl rollout restart deployment coredns \
-n kube-system
```

Verify

```bash
kubectl get pods \
-n kube-system
```

↓

Continue to Layer 7

---

# Layer 6 – Network Layer

Prediction

"Everything above is healthy. Check connectivity."

Verify Services

```bash
kubectl get svc
```

Verify NodePort

```bash
kubectl get svc web-svc-127878254
```

Verify TCP

```bash
kubectl exec \
-it debug-127878254 \
-n clinic-127878254 \
-- nc -zv db-svc-127878254 3306
```

---

# Layer 7 – Recovery Verification

Prediction

"I expect the application to work again."

Verify DNS

```bash
kubectl exec \
-it debug-127878254 \
-n clinic-127878254 \
-- nslookup db-svc-127878254
```

Verify Endpoints

```bash
kubectl get endpoints \
-n clinic-127878254
```

Verify Pods

```bash
kubectl get pods \
-n clinic-127878254
```

Verify Application

```bash
curl http://<EC2-PUBLIC-IP>:30080
```

Expected

✓ Student ID displayed

✓ Database Service displayed

✓ Seeded data displayed

✓ No DNS errors

✓ No connection errors

---

# One-Page Decision Tree

```
WEB CANNOT REACH DATABASE
│
├── Confirm symptom
│       │
│       ├── Healthy → STOP
│       │
│       └── Failure
│
├── Service exists?
│       │
│       ├── NO → Apply db-service.yaml
│       │
│       └── YES
│
├── Endpoints populated?
│       │
│       ├── NO
│       │      ├── DB Pod down
│       │      ├── Readiness failed
│       │      └── Selector mismatch
│       │
│       └── YES
│
├── DNS works?
│       │
│       ├── NO
│       │      ├── Check resolv.conf
│       │      ├── nslookup
│       │      └── Check CoreDNS
│       │
│       └── YES
│
├── Network
│       │
│       ├── Service
│       ├── NodePort
│       └── TCP
│
└── Verify Recovery
        │
        ├── nslookup
        ├── Endpoints
        ├── Pods
        └── curl
```

---

# Professor Demo Checklist

Before every command:

✔ State your prediction.

✔ Run the command.

✔ Explain the output.

✔ State which Kubernetes layer it confirms or eliminates.

✔ Proceed to the next branch.

Never restart components unless the diagnosis identifies the root cause.
