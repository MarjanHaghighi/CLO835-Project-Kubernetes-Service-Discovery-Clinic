# CLO835 – Project 14: Service Discovery Failure Clinic

## Student Information

| Item | Information |
|------|-------------|
| **Student Name** | Marjan Haghighi |
| **Student ID** | 127878254 |
| **Course** | CLO835 – Portable Technologies in Cloud |
| **Semester** | Fall 2026 |
| **Project** | Project 14 – Service Discovery Failure Clinic |

---

# Project Overview

This project demonstrates a complete Kubernetes-based two-tier application deployed on a **kind** cluster. The application consists of a Flask web application and a MySQL database communicating **only through Kubernetes Service DNS** without using hard-coded IP addresses.

The project focuses on Kubernetes Service Discovery, DNS resolution, CoreDNS, Services, Endpoints, ConfigMaps, Secrets, and troubleshooting common service discovery failures.

---

# Project Objectives

This project demonstrates how to:

- Deploy a two-tier application on Kubernetes
- Configure Service Discovery using Kubernetes DNS
- Store configuration using ConfigMaps
- Store sensitive information using Kubernetes Secrets
- Verify healthy DNS resolution
- Troubleshoot Service Discovery failures
- Diagnose CoreDNS issues
- Restore application availability
- Automate deployment using bootstrap.sh
- Build and publish Docker images using GitHub Actions

---

# Project Architecture

```
                   Client (curl)
                        │
                        ▼
               NodePort Service
            web-svc-127878254
                        │
         ┌──────────────┴──────────────┐
         ▼                             ▼
   Web Pod 1                     Web Pod 2
         │                             │
         └──────────────┬──────────────┘
                        ▼
            ClusterIP Service
            db-svc-127878254
                        │
                        ▼
                  MySQL Database
```

---

# Kubernetes Resources

### Namespace

```
clinic-127878254
```

### Deployments

- web-127878254
- db-127878254

### Services

- web-svc-127878254 (NodePort)
- db-svc-127878254 (ClusterIP)

### Pods

- Web Pods (2 replicas)
- Database Pod
- Debug Pod

### Configuration

- ConfigMap
- Secret

---

# Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── docker-build-push.yml
│
├── evidence/
├── manifests/
├── terraform/
├── web/
│
├── bootstrap.sh
├── verify-clinic.sh
├── diagnosis-tree.md
├── runbook.md
├── README.md
└── healthy-baseline-results.txt
```

---

# Technologies Used

- Kubernetes
- kind
- Docker
- Docker Hub
- GitHub Actions
- Python Flask
- MySQL 8
- CoreDNS
- ConfigMaps
- Secrets
- Terraform
- AWS EC2
- Ubuntu Linux

---

# Prerequisites

Install the following before running the project:

- Docker
- kind
- kubectl
- Git

Verify installation:

```bash
docker --version
kind version
kubectl version --client
git --version
```

---

# Installation

Clone the repository

```bash
git clone <YOUR_GITHUB_REPOSITORY>
```

Enter the project directory

```bash
cd clo835-project
```

Make scripts executable

```bash
chmod +x bootstrap.sh
chmod +x verify-clinic.sh
```

Deploy the application

```bash
./bootstrap.sh
```

---

# Verification

Verify cluster

```bash
kubectl get nodes
```

Verify namespace

```bash
kubectl get ns
```

Verify resources

```bash
kubectl get all -n clinic-127878254
```

Verify Services

```bash
kubectl get svc -n clinic-127878254
```

Verify Endpoints

```bash
kubectl get endpoints -n clinic-127878254
```

Verify DNS

```bash
kubectl exec -it debug-127878254 \
-n clinic-127878254 \
-- nslookup db-svc-127878254
```

Verify application

```bash
curl http://<NODE-IP>:<NODEPORT>
```

---

# Service Discovery Workflow

```
Flask Application
        │
        ▼
DB_HOST (ConfigMap)
        │
        ▼
db-svc-127878254
        │
        ▼
ClusterIP Service
        │
        ▼
Endpoints
        │
        ▼
MySQL Pod
```

---

# GitHub Actions

The repository includes a GitHub Actions workflow that automatically:

- Builds the Docker image
- Pushes the image to Docker Hub
- Creates the following tags:
  - `v1`
  - `latest`

The workflow **does not connect to the Kubernetes cluster**, complying with the project requirements.

---

# Troubleshooting

The repository includes two supporting documents:

- **runbook.md**
- **diagnosis-tree.md**

These documents provide procedures for:

- Bootstrap deployment
- DNS verification
- Service inspection
- Endpoint verification
- CoreDNS troubleshooting
- Service recovery
- End-to-end validation

---

# Evidence

The **evidence/** directory contains terminal transcripts demonstrating the healthy state of the application, including:

- Bootstrap execution
- Repository structure
- DNS resolution
- Service and Endpoint verification
- Kubernetes resources
- Application output
- Deployment verification
- CoreDNS verification
- Verification script output

---

# Live Demonstration

During the presentation the following workflow is demonstrated:

1. Verify healthy deployment
2. Verify DNS resolution
3. Verify Service discovery
4. Instructor introduces one failure
5. Predict expected output
6. Diagnose using `diagnosis-tree.md`
7. Repair the issue
8. Verify complete recovery

---

# Learning Outcomes

This project demonstrates practical knowledge of:

- Kubernetes Architecture
- Service Discovery
- CoreDNS
- Cluster Networking
- ConfigMaps
- Secrets
- Services
- Endpoints
- Labels and Selectors
- Liveness and Readiness Probes
- GitHub Actions
- Docker Image Automation
- Infrastructure Automation
- Kubernetes Troubleshooting

---

# License

Academic project submitted to **Seneca Polytechnic** for **CLO835 – Portable Technologies in Cloud**.

This repository is intended for educational purposes only.

---

# Author

**Marjan Haghighi**

Student ID: **127878254**

Seneca Polytechnic

Fall 2026
