var builder = WebApplication.CreateBuilder(args);

var app = builder.Build();

// Map health and version endpoints
app.MapGet("/health", () => Results.Ok(new {status = "healthy"}));
app.MapGet("/version", () => Environment.GetEnvironmentVariable("VERSION") ?? "dev");


app.Run();

