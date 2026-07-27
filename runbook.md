# Project 14 – Service Discovery Failure Clinic
## Runbook
**Student ID:** 127878254

---

# Table of Contents

1. Environment Verification
2. Bootstrap the Project
3. Verify Cluster
4. Verify Namespace
5. Verify Deployments
6. Verify Pods
7. Verify Services
8. Verify Endpoints
9. Verify ConfigMaps
10. Verify Secrets
11. Verify DNS Resolution
12. Verify Service Discovery
13. Verify Database Connectivity
14. Verify Application
15. Verify Readiness
16. Verify Events
17. Verify Logs
18. Inspect CoreDNS
19. Diagnosis Procedures
20. Recovery Procedures
21. Final Verification

---

# 1. Environment Verification

Check Docker

```bash
docker version
```

Check kubectl

```bash
kubectl version --client
```

Check kind

```bash
kind version
```

---

# 2. Bootstrap Project

Run:

```bash
chmod +x bootstrap.sh
./bootstrap.sh
```

Expected Result

- Cluster created
- Namespace created
- Database deployed
- Web deployed
- Debug pod deployed
- Services created
- Verification successful

---

# 3. Verify Cluster

```bash
kubectl get nodes
```

Expected

```
1 control-plane
2 workers
Ready
```

---

# 4. Verify Namespace

```bash
kubectl get ns
```

Expected

```
clinic-127878254
```

---

# 5. Verify Deployments

```bash
kubectl get deployments -n clinic-127878254
```

Expected

```
db-127878254      1/1
web-127878254     2/2
```

Describe deployment

```bash
kubectl describe deployment web-127878254 -n clinic-127878254
```

---

# 6. Verify Pods

```bash
kubectl get pods -o wide -n clinic-127878254
```

Expected

```
db Running
debug Running
web Running
web Running
```

Describe pod

```bash
kubectl describe pod <pod-name> -n clinic-127878254
```

---

# 7. Verify Services

```bash
kubectl get svc -n clinic-127878254
```

Expected

```
db-svc-127878254
web-svc-127878254
```

Describe Service

```bash
kubectl describe svc db-svc-127878254 -n clinic-127878254
```

---

# 8. Verify Endpoints

```bash
kubectl get endpoints -n clinic-127878254
```

Expected

```
db endpoint
web endpoints
```

If Endpoints are empty

Possible causes

- selector mismatch
- pod not ready
- deployment scaled to zero

---

# 9. Verify ConfigMaps

```bash
kubectl get configmaps -n clinic-127878254
```

Describe

```bash
kubectl describe configmap app-config -n clinic-127878254
```

Verify

DB_HOST

is

```
db-svc-127878254
```

---

# 10. Verify Secrets

```bash
kubectl get secrets -n clinic-127878254
```

---

# 11. Verify DNS Resolution

Enter debug pod

```bash
kubectl exec -it debug-127878254 -n clinic-127878254 -- sh
```

Resolver

```bash
cat /etc/resolv.conf
```

Explain

- search domains
- nameserver
- ndots:5

DNS Tests

```bash
nslookup db-svc-127878254
```

```bash
nslookup db-svc-127878254.clinic-127878254
```

```bash
nslookup db-svc-127878254.clinic-127878254.svc
```

```bash
nslookup db-svc-127878254.clinic-127878254.svc.cluster.local
```

Exit

```bash
exit
```

---

# 12. Verify Service Discovery

```bash
kubectl get svc,endpoints -n clinic-127878254
```

Verify

Selectors

```bash
kubectl describe svc db-svc-127878254 -n clinic-127878254
```

Verify labels

```bash
kubectl get pods --show-labels -n clinic-127878254
```

---

# 13. Verify Database Connectivity

Open debug pod

```bash
kubectl exec -it debug-127878254 -n clinic-127878254 -- sh
```

Test TCP

```bash
nc -zv db-svc-127878254 3306
```

---

# 14. Verify Application

Find NodePort

```bash
kubectl get svc web-svc-127878254 -n clinic-127878254
```

Curl

```bash
curl http://localhost:30080
```

or

```bash
curl http://<EC2-PUBLIC-IP>:30080
```

Expected

- Student ID
- Database Service Name
- Seeded row

---

# 15. Verify Readiness

```bash
kubectl describe pod <web-pod> -n clinic-127878254
```

Check

Readiness Probe

---

# 16. Verify Events

```bash
kubectl get events -n clinic-127878254 --sort-by=.lastTimestamp
```

---

# 17. Verify Logs

Web

```bash
kubectl logs deployment/web-127878254 -n clinic-127878254
```

Database

```bash
kubectl logs deployment/db-127878254 -n clinic-127878254
```

---

# 18. Inspect CoreDNS

Pods

```bash
kubectl -n kube-system get pods -l k8s-app=kube-dns
```

ConfigMap

```bash
kubectl -n kube-system get configmap coredns -o yaml
```

Logs

```bash
kubectl -n kube-system logs -l k8s-app=kube-dns
```

---

# 19. Diagnosis Procedures

## Service Missing

```bash
kubectl get svc
```

Repair

```bash
kubectl apply -f manifests/db-service.yaml
```

---

## Selector Mismatch

```bash
kubectl describe svc db-svc-127878254
```

```bash
kubectl get pods --show-labels
```

Repair

Update labels or selector

---

## Empty Endpoints

```bash
kubectl get endpoints
```

Check

Pods

Readiness

Deployment replicas

---

## CoreDNS Failure

Check

```bash
kubectl logs -n kube-system -l k8s-app=kube-dns
```

Restore

```bash
kubectl apply -f manifests/coredns-known-good.yaml -n kube-system
```

Restart

```bash
kubectl rollout restart deployment coredns -n kube-system
```

---

# 20. Recovery Verification

DNS

```bash
kubectl exec -it debug-127878254 -n clinic-127878254 -- nslookup db-svc-127878254
```

Endpoints

```bash
kubectl get endpoints -n clinic-127878254
```

Application

```bash
curl http://localhost:30080
```
curl http://52.90.124.69:30080
---

# 21. Final Verification Checklist

✓ Cluster Ready

✓ Namespace exists

✓ Deployments healthy

✓ Pods Running

✓ Services created

✓ Endpoints populated

✓ ConfigMaps loaded

✓ DNS resolves

✓ Database reachable

✓ Application returns student ID

✓ Seeded data displayed

✓ Readiness healthy

✓ NodePort accessible

✓ Logs clean

✓ CoreDNS healthy

✓ Recovery verified
