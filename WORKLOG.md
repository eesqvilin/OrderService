# WORKLOG

> [!NOTE] 
> Observations and Notes (Parts 1-4)

## Part 1 - Scaffold Service  

- Noted that the assesment requires NET 8 SDK.  The `brew install --cask dotnet-skd@8` pinned the latest version 10.0.402.  As a solution, the required version (8) was pinned using a global.json file using the following command:

        `dotnet new global.json --sdk-version 8.0.426 --roll-forward latestFeature`

- As a typo error wrote "VERSION (`app.MapGet("/version", () => Environment.GetEnvironmentVariable("VERSION") ?? "dev");`) instead of `"APP_VERSION"` and got `dev%` as output.  After running the command `APP_VERSION=1.0.0-test dotnet run &` to set the version to 1.0.0-test, resulted on the same output as the reference file. 

## Part 2 - Vulnerability Scanning

- warn : NU1903: Package 'Newtonsoft.Json' 9.0.1 has a known high severity vulnerability, https://github.com/advisories/GHSA-5crp-9r3c-p9vr appeared during Newtonsoft.Json package installation. 

- Ref. https://hub.docker.com/r/microsoft/dotnet-aspnet and https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/docker/building-net-docker-images?view=aspnetcore-10.0 for image to be used.  Image `mcr.microsoft.com/dotnet/aspnet:8.0` will be used to match project requirements. 

- created `.gitignore` file to ignore non-required files. Used `ls -a` in the root folder to check on files.  

-  Vulnerability found during trivy scan using command `trivy image orderservice:local`


Will proceed to update the package to fixed version specified during the scan using `dotnet add package Newtonsoft.Json --version 13.0.1`

- Why do we care if the container runs as root and what did you have to change to make USER appuser actually work?

From a security standpoint running a container as root widens the damage an attack can do and exposes the application (e.g. vulnerable dependencies).  As root with full privilege can modify, install tools, read the container files and access the host.  RUnning as a non-root user applies the principle of least privilege and limits the surface in of an attack.  To make `USER appsuser` work: I created the user using `adduser` command and then switch it using `USER` command. As `adduser` needs root privileges the order matters for example we must perform all root privileged operations before switching to the non-root user. 

## Part 3 - Github Actions 

- During testing for first job the Format Code step failed with message: 

Performed a search in the codebase for "ENDOFLINE" and found it on the .editorcofig file created early in the project.  Upon research found that there different values to this depending on the OS architecture (lf matching Mac and Linux). Ran `grep -n end_of_line .editorconfig` and found it on line 21.  Will proceed to change end_of_line value to lf to match local and container architecture.  Ran `dotnet format` to rerun and apply changes. 

- job: Docker Build and Scan finished with exit code 1 in the Scan Image (Trivy) step. Although scanner is working is stoping the pipeline because of the failure. The Summary shows the 7 vulnerabilities are related to debian distros and the all are fixed already in newer versions of the package. 

Solution approach will be updating the packages using `apt-get update && apt-get install --only-upgrade -y perl-base` to update the package in the runtime stage of the Dockerfile. Later can add `rm -rf var/lib/apt/list/*` to command to keep image clean.

- Using https://github.com/marketplace for actions versioning. 

- Measured the slow steps before optimizing: the NuGet cache saved only about 2s because the project has few packages, so I kept my attention on the Docker build, where type=gha cache with mode=max cut Build Image from 28s to 8s by reusing layers from both stages.

- Referred to https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax for syntax.



## Part 4 - Deploy Step

- Wrote the deploy job to run only on main and only if no earlier job failed or was cancelled (!failure() && !cancelled()), since a plain always() would try to deploy after a failed scan, and since skipped jobs are allowed through, the manual redeploy path works when the build jobs are skipped. It pulls the SHA-tagged image from GHCR (no login needed because the package is public), replaces any existing container with docker rm -f, and verifies the deploy by comparing /version to the commit SHA instead of only checking that the endpoint responds, with retries for startup time and container logs printed on failure.

My first deploy run failed at verification with curl: (56) connection reset, and a second run with `--retry-all-errors` still failed (exit 7, connection refused for ~31 seconds), which showed the container had started and then exited rather than being slow to start. My diagnostic docker logs step was missing if: failure() and had been skipped, so I fixed that, and the logs showed OrderService.dll missing from /app. Inspecting the pulled image with docker run --entrypoint ls showed /app was empty: the COPY --from=build /app/publish . line had been lost from the runtime stage, so the image contained no application, and BuildKit had silently skipped the whole build stage because nothing depended on it. The Trivy gate had passed on this image because there was nothing to scan, so “green scan” didn’t mean “good image.” After restoring the COPY, the pipeline went green.

## Part 5 - Written Section (Answers)

1. Right now my format, build and test steps run one after another inside a single job, but they don’t depend on each other, so I would split format and test into parallel jobs: I’d gain faster feedback, since the run takes as long as the slowest job instead of the sum, and I’d see every failure in a single run. The image scan can’t run in parallel with the build, because it needs the built image, and I wouldn’t build an image that already failed format or tests, so the Docker job keeps needs: on the earlier jobs. The risk of running everything in parallel is wasted runner time when an early check fails and a harder-to-read pipeline when several jobs fail at once, and push and deploy would still have to wait for every gate.

2. The only credential in this pipeline is the built-in GITHUB_TOKEN: I don’t store any secrets in the repo settings, because GitHub creates the token at the start of each job, it’s passed only to the GHCR login step, and it expires when the job ends. Its blast radius is limited twice: by its short life, and by my permissions: block, which gives it only contents: read and packages: write, so a token leaked into a log could only read this repo and push packages during that window. GitHub masks secrets in logs but only exact values, so I avoid printing or transforming it, and a long-lived personal token, which I deliberately didn’t use, would have been far worse. The only other variable is DOCKER_IMAGE in the workflow’s env:, which holds the image name and commit SHA, so it is configuration, not a secret, and is safe to keep in the file and show in logs.
> [!NOTE]
> Reference: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#env

3. The gap would be the gate running only when someone pushes and a cached or old image keeps passing even after a fixed CVE appears.  We can close it triggering an `on: schedule` that rebuilds without the cache and and rescan. Also the usage of dependabot be helpful on this. (This steps are not implemented.) 
> [!NOTE]
> Reference: https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule https://docs.github.com/en/code-security/tutorials/secure-your-dependencies/automate-dependabot-with-actions

4. The smallest next step I can see is Docker Compose running three copies of the container on one host with nginx in front as a reverse proxy and load balancer. I’m still learning this area, but I understand that a Dockerfile only describes how to build a single image, so it can’t handle load balancing, updating without downtime, or sending traffic only to healthy copies, and Compose is what defines the copies and the proxy as services that talk to each other. 
>[!NOTE]
> References: https://docs.docker.com/reference/compose-file/services/ https://ecostack.dev/posts/load-balancing-docker-compose-replicas-using-nginx/