# Docker image with Qbs, GCC and Qt

This docker image is used to run continuious integrations and local builds with the Qbs build system.

The image contains a GCC as the main compiler.
The -qt variants also contain some Qt modules.

## Usage

Use it like qbs command line.

```bash
docker run -it \
    --mount src="$(pwd)",target=/build,type=bind \
    -w /build \
    arbmind/qbs-gcc11:latest \
    build -d /tmp/qbs -p autotest-runner
```

This mounts your current directory to `/build` in the container. Changes the workdir to `/build` and runs qbs with build path `/tmp/qbs` and targets the `autotest-runner`.
