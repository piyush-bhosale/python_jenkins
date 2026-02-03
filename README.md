# ✅ **FULL PIPELINE REPORT**

### *DevOps | DevSecOps*

***

# 📌 **1. Checkout Code**

### **What happens**

*   Jenkins pulls your latest source code from GitHub.
*   This ensures the pipeline always works with current code.

### **Why it’s needed**

*   Every build/test must use the latest code version.

***

# 📌 **2. Preflight Validation**

### **What happens**

This stage checks that your project structure is correct:

*   Python is installed
*   pip is installed
*   `pyproject.toml` or `setup.py` exists
*   `app/` folder exists
*   `tests/` folder exists
*   `requirements-dev.txt` exists

### **Why**

*   To stop early if basic project files are missing.
*   Saves time by catching basic problems upfront.

***

# 📌 **3. Setup Python Environment**

### **What happens**

*   A new Python **virtual environment (.venv)** is created.
*   pip + setuptools + wheel are upgraded.
*   All dev dependencies are installed from `requirements-dev.txt`.
*   Your project package is installed with `pip install -e .`.

### **Why**

*   To isolate dependencies.
*   To make testing and quality tools work properly.

***

# 📌 **4. Dependency Lock Enforcement**

### **What happens**

*   Jenkins checks that **every dependency** in `requirements-dev.txt` uses **== pinned versions**.
*   If any package has `>=`, `<=`, `~=`, or no version → build fails.

### **Why**

*   To ensure builds are reproducible.
*   To avoid “it works on my machine” problems.
*   Security teams require pinned versions.

***

# 📌 **5. Run Tests**

### **What happens**

*   All tests run using pytest.
*   Coverage report (`coverage.xml`) is generated.
*   JUnit test report (`report.xml`) is created.

### **Why**

*   To ensure your code works.
*   To catch regressions early.
*   For SonarQube to read test coverage.

***

# 📌 **6. Python Quality Stack**

### **What happens**

This stage runs all your code quality tools:

1.  **Ruff lint** (mandatory)
2.  **Ruff format check** (non-blocking)
3.  **Black format check** (non-blocking)
4.  **Mypy type check** (non-blocking)
5.  **Bandit security scan** (non-blocking)
6.  **pip-audit vulnerability scan** (non-blocking)

### **Why**

*   Ensures code quality standards.
*   Gives feedback without blocking pipeline.

***

# 📌 **7. OWASP Dependency Check (CVE Scan)**

### **What happens**

*   Jenkins copies `requirements-dev.txt` → `requirements.txt`.
*   OWASP DC scans Python dependencies for known CVEs.
*   Report is generated in XML.
*   Stage is **non-blocking** (pipeline continues).

### **Why**

*   To catch vulnerabilities in libraries.
*   DevSecOps requirement.

***

# 📌 **8. SonarQube Analysis**

### **What happens**

*   SonarQube scanner analyzes your:
    *   Code quality
    *   Bugs
    *   Vulnerabilities
    *   Code smells
    *   Coverage (from coverage.xml)
    *   Test results (report.xml)

### **Why**

*   To maintain quality standards.
*   To enforce clean code.

***

# 📌 **9. SonarQube Quality Gate**

### **What happens**

*   Jenkins waits for SonarQube’s approval.
*   Pipeline **fails** if quality standards are not met.

### **Why**

*   Prevents poor-quality code from moving forward.

***

# 📌 **10. Build Python Package (Wheel + sdist)**

### **What happens**

*   Old builds are removed.
*   `python -m build` generates:
    *   `.whl` file
    *   `.tar.gz` source package
*   Packages stored in `dist/`.

### **Why**

*   This is the official distributable Python build.
*   Required for packaging + deployments.

***

# 📌 **11. Build Docker Image**

### **What happens**

*   Jenkins builds a Docker image using your Dockerfile.
*   Tags the image as:
        python-jenkins-demo:<BUILD_NUMBER>-<GIT_SHA>
*   Stores tag in `image_tag.txt`.

### **Why**

*   Containerizing your app is required for deployment.
*   Git SHA + build number ensures traceability.

***

# 📌 **12. Trivy Image Scan**

### **What happens**

*   Trivy scans your Docker image for:
    *   OS vulnerabilities
    *   Python dependency vulnerabilities
*   Creates JSON report.
*   Stage is **non-blocking**.

### **Why**

*   Security check for your container.
*   DevSecOps best practice.

***

# 📌 **13. Push Image to DockerHub**

### **What happens**

*   Jenkins logs into DockerHub using credential ID `dockerhub`.
*   Jenkins tags image for DockerHub:
        piyushbhosale9226/python_jenkins:<BUILD_SHA_TAG>
*   Pushes image to DockerHub.
*   Saves pushed tag to `dockerhub_image.txt`.

### **Why**

*   Deployment servers (EC2) can pull from DockerHub.
*   Official way to publish container images.  
    Docker uses `docker push NAME[:TAG]` to upload images.

***

# 📌 **14. Upload Artifacts to S3**

### **What happens**

Jenkins uploads all important artifacts to your S3 bucket:

**Uploaded:**

*   Python packages → `dist/`
*   `coverage.xml`
*   `report.xml`
*   `dependency-check-report.*`
*   `trivy-image-report.json`
*   `image_tag.txt`
*   `dockerhub_image.txt`

Using:

    aws s3 cp <source> <s3 bucket path> --recursive --region ap-south-1

AWS CLI supports uploading directories using `--recursive`.

### **Why**

*   S3 becomes your artifact store.
*   Useful for auditing, rollbacks, deployments.

***

# 📌 **15. Post Actions**

### **What happens**

*   Jenkins publishes test results.
*   Archives:
    *   dist files
    *   coverage.xml
    *   reports
    *   dockerhub\_image.txt

### **Why**

*   Centralized record after the build.
*   Makes debugging easy.

***

# 🚀 **CD (Deployment) – Ready to Add**

*(You have not added CD yet, but your pipeline is READY for it)*

Your deployment will include:

1.  SSH into EC2
2.  Stop old container
3.  Pull new image
4.  Start container
5.  Run health check

Docker runs containers in foreground; `docker run` creates the main process.

***

# ⭐ **Final Summary (Super Short Version)**

| Stage             | What It Does               | Why It Matters       |
| ----------------- | -------------------------- | -------------------- |
| Checkout          | Pull code                  | Latest changes       |
| Preflight         | Basic checks               | Avoid early failures |
| Setup Python      | Create venv + install deps | Clean environment    |
| Lock Check        | Ensure pinned deps         | Reproducible builds  |
| Tests             | Run pytest                 | Validate correctness |
| Quality           | Lint + type + security     | Code health          |
| OWASP             | CVE scan                   | Security             |
| Sonar             | Code quality scan          | Quality governance   |
| Quality Gate      | Approval                   | Stops bad code       |
| Build Package     | Build wheel/sdist          | Deployable artifact  |
| Docker Build      | Build image                | Container deployment |
| Trivy             | Scan image                 | Security             |
| Push to DockerHub | Publish image              | Deployment source    |
| Upload to S3      | Store artifacts            | Audits + releases    |
| Post Actions      | Archive results            | Reporting            |

***


