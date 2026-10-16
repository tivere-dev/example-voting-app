# because of dotnet, we always build on amd64, and target platforms in cli
# dotnet doesn't support QEMU for building or running.
# (errors common in arm/v7 32bit) https://github.com/dotnet/dotnet-docker/issues/1537
# https://hub.docker.com/_/microsoft-dotnet
# hadolint ignore=DL3029
# to build for a different platform than your host, use --platform=<platform>
# for example, if you were on Intel (amd64) and wanted to build for ARM, you would use:
# docker buildx build --platform "linux/arm64/v8" .

# build compiles the program for the builder's local platform.
# .NET 10 LTS SDK, pinned by version tag (readable) and digest (immutable).
FROM --platform=${BUILDPLATFORM} mcr.microsoft.com/dotnet/sdk:10.0.402@sha256:0d99ebf1ccad15037b5c98c9fe8979d6b8dbac23812feae2277a0b277b5c5ffa AS build
ARG TARGETPLATFORM
ARG TARGETARCH
ARG BUILDPLATFORM
RUN echo "I am running on $BUILDPLATFORM, building for $TARGETPLATFORM"

WORKDIR /source
COPY *.csproj .
RUN dotnet restore -a $TARGETARCH

COPY . .
RUN dotnet publish -c release -o /app -a $TARGETARCH --self-contained false --no-restore

# app image: "chiseled" Ubuntu has only what .NET needs to run, with no shell
# or package manager, which leaves less to patch and less for an attacker to use
FROM mcr.microsoft.com/dotnet/runtime:10.0.13-noble-chiseled@sha256:75e4232c875a07e46e447ca0a56a61f7cd72d9fb361639018a19e9fc605c6827
WORKDIR /app
COPY --from=build /app .
# Chiseled images already default to the non-root "app" user (UID 1654);
# set it explicitly so the intent is visible here
USER $APP_UID
# No HEALTHCHECK: the worker serves no port, and if its main loop fails the
# process exits, which Docker and Kubernetes already detect
ENTRYPOINT ["dotnet", "Worker.dll"]
