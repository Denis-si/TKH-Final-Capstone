# Secure Automated Web Architecture

## Description
This repository contains an enterprise-grade Infrastructure as Code (IaC) blueprint that automatically provisions a secure, highly available cloud web stack on Amazon Web Services (AWS) using HashiCorp Terraform. Built with a shift-left security paradigm, every commit is continuously analyzed by an automated DevSecOps CI/CD pipeline using static application security testing (SAST) before code is approved for deployment.

## Technologies Used
* **Cloud Infrastructure:** Amazon Web Services (AWS EC2, VPC, Subnets, Internet Gateway, Security Groups)
* **Infrastructure as Code (IaC):** HashiCorp Terraform (HCL)
* **DevSecOps & CI/CD:** GitHub Actions
* **Static Security Testing (SAST):** `tfsec` / Aqua Security

## Cloud Architecture & Security Controls
* **Virtual Private Cloud (VPC):** Custom `10.0.0.0/16` isolated network environment with DNS hostnames and resolution enabled.
* **Network Access & Routing:** A dedicated public subnet (`10.0.1.0/24`) attached to an Internet Gateway via explicit route table entries for web traffic handling.
* **Firewall Lockdown (Security Groups):** 
  * **HTTP (Port 80):** Inbound traffic is open to the public (`0.0.0.0/0`) to serve web content.
  * **SSH (Port 22):** Inbound administrative access is strictly restricted to a single authorized administrator IP address (`/32` CIDR mask).
* **Server Hardening:**
  * **Storage Encryption:** Root Amazon EBS volume encrypted using AWS managed keys (`gp3`).
  * **IMDSv2 Enforcement:** Requires session token authentication for instance metadata requests to prevent SSRF credential exfiltration.
  * **Automated Bootstrap:** EC2 user data script installs, configures, and enables the Apache (`httpd`) web service on boot.

## DevSecOps Pipeline
The integrated GitHub Actions workflow (`security-scan.yml`) runs on every push to the `main` branch. It executes a `tfsec` SAST scan with `--soft-fail=false`, ensuring that any misconfiguration or policy violation physically breaks the build prior to deployment.