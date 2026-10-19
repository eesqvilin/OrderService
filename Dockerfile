# Dockerfile for OrderService

#Stage 1: Build the application
FROM mcr.microsoft/dotnet/sdk:8.0 as build
WORKDIR  /src
COPY *.csproj ./
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish

#Stage 2: Build the runtime image
FROM mcr.microsoft/dotnet/aspnet:8.0 as runtime
WORKDIR /app
RUN adduser --disabled-password --gecos "" appuser
COPY --from=build /app/publish .
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:8080/health || exit 1
ENTRYPOINT ["dotnet", "OrderService.dll"]