# Kubernetes Service Discovery Failure Clinic

CLO835 Semester Project – Project 14

## Student Information

- Student ID: 127878254
- Cluster name: `clinic-127878254`
- Namespace: `clinic-127878254`

## Project Overview

This project demonstrates Kubernetes service discovery, DNS troubleshooting,
application-to-database connectivity, and failure diagnosis using a local kind
cluster.

The system includes:

- A Flask web application
- A MySQL database
- Kubernetes Deployments and Services
- Kubernetes Secrets and ConfigMaps
- Readiness and liveness probes
- A BusyBox diagnostic pod
- GitHub Actions for Docker image building and publishing

## Container Image

```text
marjanhaghighi/clo835-project-service-discovery-web:v1
