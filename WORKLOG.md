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

```
app/OrderService.deps.json (dotnet-core)

Total: 1 (UNKNOWN: 0, LOW: 0, MEDIUM: 0, HIGH: 1, CRITICAL: 0)

┌─────────────────┬────────────────┬──────────┬────────┬───────────────────┬───────────────┬────────────────────────────────────────────────┐
│     Library     │ Vulnerability  │ Severity │ Status │ Installed Version │ Fixed Version │                     Title                      │
├─────────────────┼────────────────┼──────────┼────────┼───────────────────┼───────────────┼────────────────────────────────────────────────┤
│ Newtonsoft.Json │ CVE-2024-21907 │ HIGH     │ fixed  │ 9.0.1             │ 13.0.1        │ Improper Handling of Exceptional Conditions in │
│                 │                │          │        │                   │               │ Newtonsoft.Json                                │
│                 │                │          │        │                   │               │ https://avd.aquasec.com/nvd/cve-2024-21907     │
└─────────────────┴────────────────┴──────────┴────────┴───────────────────┴───────────────┴────────────────────────────────────────────────┘
```
Will proceed to update the package to fixed version specified during the scan using `dotnet add package Newtonsoft.Json --version 13.0.1`

- Why do we care if the container runs as root and what did you have to change to make USER appuser actually work?

From a security standpoint running a container as root widens the damage an attack can do and exposes the application (e.g. vulnerable dependencies).  As root with full privilege can modify, install tools, read the container files and access the host.  RUnning as a non-root user applies the principle of least privilege and limits the surface in of an attack.  To make `USER appsuser` work: I created the user using `adduser` command and then switch it using `USER` command. As `adduser` needs root privileges the order matters for example we must perform all root privileged operations before switching to the non-root user. 

## Part 3 - Github Actions 

- During testing for first job the Format Code step failed with message: 

```
Run dotnet format --verify-no-changes
/home/runner/work/OrderService/OrderService/Program.cs(1,50): error ENDOFLINE: Fix end of line marker. Replace 2 characters with '\r\n\r\n'. [/home/runner/work/OrderService/OrderService/OrderService.csproj]
/home/runner/work/OrderService/OrderService/Program.cs(3,27): error ENDOFLINE: Fix end of line marker. Replace 2 characters with '\r\n\r\n'. [/home/runner/work/OrderService/OrderService/OrderService.csproj]
/home/runner/work/OrderService/OrderService/Program.cs(5,36): error ENDOFLINE: Fix end of line marker. Replace 1 characters with '\r\n'. [/home/runner/work/OrderService/OrderService/OrderService.csproj]
/home/runner/work/OrderService/OrderService/Program.cs(6,69): error ENDOFLINE: Fix end of line marker. Replace 1 characters with '\r\n'. [/home/runner/work/OrderService/OrderService/OrderService.csproj]
/home/runner/work/OrderService/OrderService/Program.cs(7,90): error ENDOFLINE: Fix end of line marker. Replace 3 characters with '\r\n\r\n\r\n'. [/home/runner/work/OrderService/OrderService/OrderService.csproj]
Error: Process completed with exit code 2.
```
Performed a search in the codebase for "ENDOFLINE" and found it on the .editorcofig file created early in the project.  Upon research found that there different values to this depending on the OS architecture (lf matching Mac and Linux). Ran `grep -n end_of_line .editorconfig` and found it on line 21.  Will proceed to change end_of_line value to lf to match local and container architecture.  Ran `dotnet format` to rerun and apply changes. 

- job: Docker Build and Scan finished with exit code 1 in the Scan Image (Trivy) step. Although scanner is working is stoping the pipeline because of the failure. The Summary shows the 7 vulnerabilities are related to debian distros and the all are fixed already in newer versions of the package. 

  ```
  Report Summary
  
  ┌──────────────────────────────────────────────────────────────────────────────────┬─────────────┬─────────────────┬─────────┐
  │                                      Target                                      │    Type     │ Vulnerabilities │ Secrets │
  ├──────────────────────────────────────────────────────────────────────────────────┼─────────────┼─────────────────┼─────────┤
  │ orderservice (debian 12.15)                                                      │   debian    │        7        │    -    │
  ├──────────────────────────────────────────────────────────────────────────────────┼─────────────┼─────────────────┼─────────┤
  │ app/OrderService.deps.json                                                       │ dotnet-core │        0        │    -    │
  ├──────────────────────────────────────────────────────────────────────────────────┼─────────────┼─────────────────┼─────────┤
  │ usr/share/dotnet/shared/Microsoft.AspNetCore.App/8.0.32/Microsoft.AspNetCore.Ap- │ dotnet-core │        0        │    -    │
  │ p.deps.json                                                                      │             │                 │         │
  ├──────────────────────────────────────────────────────────────────────────────────┼─────────────┼─────────────────┼─────────┤
  │ usr/share/dotnet/shared/Microsoft.NETCore.App/8.0.32/Microsoft.NETCore.App.deps- │ dotnet-core │        0        │    -    │
  │ .json                                                                            │             │                 │         │
  └──────────────────────────────────────────────────────────────────────────────────┴─────────────┴─────────────────┴─────────┘
  Legend:
  - '-': Not scanned
  
  📣 Notices:
    - Version 0.76.0 of Trivy is now available, current version is 0.70.0
  
  To suppress version checks, run Trivy scans with the --skip-version-check flag
  
  - '0': Clean (no security findings detected)
  
  
  For OSS Maintainers: VEX Notice
  --------------------------------
  If you're an OSS maintainer and Trivy has detected vulnerabilities in your project that you believe are not actually exploitable, consider issuing a VEX (Vulnerability Exploitability eXchange) statement.
  VEX allows you to communicate the actual status of vulnerabilities in your project, improving security transparency and reducing false positives for your users.
  Learn more and start using VEX: https://trivy.dev/docs/v0.70/guide/supply-chain/vex/repo#publishing-vex-documents
  
  To disable this notice, set the TRIVY_DISABLE_VEX_NOTICE environment variable.
  
  
  orderservice (debian 12.15)
  ===========================
  Total: 7 (HIGH: 4, CRITICAL: 3)
  
  ┌───────────┬────────────────┬──────────┬────────┬───────────────────┬──────────────────┬──────────────────────────────────────────────────────────────┐
  │  Library  │ Vulnerability  │ Severity │ Status │ Installed Version │  Fixed Version   │                            Title                             │
  ├───────────┼────────────────┼──────────┼────────┼───────────────────┼──────────────────┼──────────────────────────────────────────────────────────────┤
  │ perl-base │ CVE-2026-13221 │ CRITICAL │ fixed  │ 5.36.0-7+deb12u3  │ 5.36.0-7+deb12u4 │ perl: Perl: Incorrect regular expression processing via      │
  │           │                │          │        │                   │                  │ large regular expressions                                    │
  │           │                │          │        │                   │                  │ https://avd.aquasec.com/nvd/cve-2026-13221                   │
  │           ├────────────────┤          │        │                   │                  ├──────────────────────────────────────────────────────────────┤
  │           │ CVE-2026-42496 │          │        │                   │                  │ perl-archive-tar: perl-archive-tar: Path traversal via       │
  │           │                │          │        │                   │                  │ crafted symlinks allows arbitrary file access                │
  │           │                │          │        │                   │                  │ https://avd.aquasec.com/nvd/cve-2026-42496                   │
  │           ├────────────────┤          │        │                   │                  ├──────────────────────────────────────────────────────────────┤
  │           │ CVE-2026-8376  │          │        │                   │                  │ perl: Perl: Heap buffer overflow when compiling regular      │
  │           │                │          │        │                   │                  │ expressions on 32-bit builds...                              │
  │           │                │          │        │                   │                  │ https://avd.aquasec.com/nvd/cve-2026-8376                    │
  │           ├────────────────┼──────────┤        │                   │                  ├──────────────────────────────────────────────────────────────┤
  │           │ CVE-2026-42497 │ HIGH     │        │                   │                  │ perl-Archive-Tar: perl-Archive-Tar: Arbitrary file           │
  │           │                │          │        │                   │                  │ modification via crafted hardlinks during archive extraction │
  │           │                │          │        │                   │                  │ https://avd.aquasec.com/nvd/cve-2026-42497                   │
  │           ├────────────────┤          │        │                   │                  ├──────────────────────────────────────────────────────────────┤
  │           │ CVE-2026-48962 │          │        │                   │                  │ perl-IO-Compress: perl-IO-Compress: Arbitrary code execution │
  │           │                │          │        │                   │                  │ via attacker-controlled output glob                          │
  │           │                │          │        │                   │                  │ https://avd.aquasec.com/nvd/cve-2026-48962                   │
  │           ├────────────────┤          │        │                   │                  ├──────────────────────────────────────────────────────────────┤
  │           │ CVE-2026-57432 │          │        │                   │                  │ perl: Perl: Information disclosure via integer overflow in   │
  │           │                │          │        │                   │                  │ pack/unpack operations                                       │
  │           │                │          │        │                   │                  │ https://avd.aquasec.com/nvd/cve-2026-57432                   │
  │           ├────────────────┤          │        │                   │                  ├──────────────────────────────────────────────────────────────┤
  │           │ CVE-2026-57433 │          │        │                   │                  │ Storable: Storable: Denial of Service via signed integer     │
  │           │                │          │        │                   │                  │ overflow in deserialization                                  │
  │           │                │          │        │                   │                  │ https://avd.aquasec.com/nvd/cve-2026-57433                   │
  └───────────┴────────────────┴──────────┴────────┴───────────────────┴──────────────────┴──────────────────────────────────────────────────────────────┘
  Error: Process completed with exit code 1.

  ```
Solution approach will be updating the packages using `apt-get update && apt-get install --only-upgrade -y perl-base` to update the package in the runtime stage of the Dockerfile. Later can add `rm -rf var/lib/apt/list/*` to command to keep image clean.

- Using https://github.com/marketplace for actions versioning. 

- Measured the slow steps before optimizing: the NuGet cache saved only about 2s because the project has few packages, so I kept my attention on the Docker build, where type=gha cache with mode=max cut Build Image from 28s to 8s by reusing layers from both stages.

- Referred to https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax for syntax.



## Part 4 - Deploy Step

- Wrote the deploy job to run only on main and only if no earlier job failed or was cancelled (!failure() && !cancelled()), since a plain always() would try to deploy after a failed scan, and since skipped jobs are allowed through, the manual redeploy path works when the build jobs are skipped. It pulls the SHA-tagged image from GHCR (no login needed because the package is public), replaces any existing container with docker rm -f, and verifies the deploy by comparing /version to the commit SHA instead of only checking that the endpoint responds, with retries for startup time and container logs printed on failure.

## Part 5 - Written Section 

