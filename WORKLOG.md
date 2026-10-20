# WORKLOG

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

- first deploy run failed at the verification step with `curl: (56) Connection reset by peer`. Docker had published the port before the app inside was ready, and `--retry-connrefused` didn’t help because a reset isn’t a refused connection, so the retries never ran.

- Deploy failure #2 (verification). After adding `--retry-all-errors`, the verify step still failed (curl exit 7): the first attempt got a connection reset, then every retry over ~31 seconds was refused, which means the container had started and then exited rather than being slow to start. My earlier theory was wrong. I couldn’t see why, because my docker logs step was missing if: failure() and was skipped after the failure, so I fixed that and added docker ps -a to see the exit status on the next run.

## Part 5 - Written Section 

