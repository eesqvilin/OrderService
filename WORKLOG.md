# WORKLOG

## Part 1 - Scaffold Service  

- Noted that the assesment requires NET 8 SDK.  The `brew install --cask dotnet-skd@8` pinned the latest version 10.0.402.  As a solution, the required version (8) was pinned using a global.json file using the following command:

 `dotnet new global.json --sdk-version 8.0.426 --roll-forward latestFeature`

- As a typo error wrote "VERSION (`app.MapGet("/version", () => Environment.GetEnvironmentVariable("VERSION") ?? "dev");`) instead of `"APP_VERSION"` and got `dev%` as output.  After running the command `APP_VERSION=1.0.0-test dotnet run &` to set the version to 1.0.0-test, resulted on the same output as the reference file. 

## Part 2 - Vulnerability Scanning 

## Part 3 - Github Actions 

## Part 4 - Deploy Step

## Part 5 - Written Section 

