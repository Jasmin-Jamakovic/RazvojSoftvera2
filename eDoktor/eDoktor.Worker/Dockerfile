FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy solution and project files
COPY ["eDoktor.Worker/eDoktor.Worker.csproj", "eDoktor.Worker/"]
COPY ["eDoktor.Model/eDoktor.Model.csproj", "eDoktor.Model/"]

# Restore NuGet packages
RUN dotnet restore "eDoktor.Worker/eDoktor.Worker.csproj"

# Copy everything else
COPY . .

# Build the project
WORKDIR "/src/eDoktor.Worker"
RUN dotnet build "eDoktor.Worker.csproj" -c Release -o /app/build

FROM mcr.microsoft.com/dotnet/runtime:8.0 AS runtime
WORKDIR /app
COPY --from=build /app/build .

ENTRYPOINT ["dotnet", "eDoktor.Worker.dll"]