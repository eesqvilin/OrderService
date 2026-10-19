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


## Part 3 - Github Actions 

## Part 4 - Deploy Step

## Part 5 - Written Section 

