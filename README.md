# udptunnel

A statically linked build of [udptunnel](https://github.com/hectorm/udptunnel) in a Docker container.

## Usage
```sh
docker run --rm --network host -it hectormolinero/udptunnel:latest --help
```

## Export build to local filesystem
```sh
docker pull hectormolinero/udptunnel:latest
docker save hectormolinero/udptunnel:latest | tar -xO --wildcards '*/layer.tar' | tar -xi udptunnel
```
