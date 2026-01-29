# docker-fulcrum

> Run Fulcrum in Docker

A Docker configuration with sane defaults for running a full Fulcrum node.

## Usage

```
docker run --name fulcrum -v $HOME/.fulcrum:/data -p 50001:50001 eudaldgr/docker-fulcrum:<version-tag>
```

Replace the tag `<version-tag>` with the available version that you want to run. For example, to run version 2.1.0, use the tag `v2.1.0`:

```
docker run --name fulcrum -v $HOME/.fulcrum:/data -p 50001:50001 eudaldgr/docker-fulcrum:v2.1.0
```

### CLI Arguments

All CLI arguments are passed directly through to Fulcrum.

You can use this to configure via CLI args without a config file:

```
docker run --name fulcrum -v $HOME/.fulcrum:/data \
  -p 50001:50001 \
  -p 50002:50002 \
  eudaldgr/docker-fulcrum:v2.1.0 \
  -b 127.0.0.1:8332 \
  -u yourrpcuser \
  -p yourrpcpassword \
  -c $HOME/.fulcrum/fulcrum.crt \
  -k $HOME/.fulcrum/fulcrum.key
```

### Versions

Images for versions starting from v2.1.0 are available. To run a specific available version, use the appropriate tag.

```
docker run --name fulcrum -v $HOME/.fulcrum:/data -p 50001:50001 eudaldgr/docker-fulcrum:v2.1.0
```

## Build

A multi-architecture (amd64 and arm64) image is automatically built and published to GitHub when new tags are pushed in the format `v*.*.*` (e.g., `v2.1.0`).

If you want to build this image yourself, check out this repo, `cd` into it, and run:

```
docker buildx build --platform linux/amd64,linux/arm64 --build-arg VERSION=<version> -t <image_name>:<tag> --push .
```

Replace `<version>` with the Fulcrum version you're building (without the 'v' prefix), and `<image_name>:<tag>` with your desired image name and tag.

The Dockerfile supports `linux/amd64` and `linux/arm64` architectures only.

## License

MIT © eudaldgr https://eudald.gr
