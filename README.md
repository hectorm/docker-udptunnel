# udptunnel

A statically linked build of [udptunnel](https://github.com/hectorm/udptunnel) in a Docker container.

## Usage
```sh
docker run --rm --network host -it docker.io/hectorm/udptunnel:latest --help
```

## Export build to local filesystem
```sh
docker pull docker.io/hectorm/udptunnel:latest
docker save docker.io/hectorm/udptunnel:latest | tar -xO --wildcards '*/layer.tar' | tar -xi udptunnel
```
