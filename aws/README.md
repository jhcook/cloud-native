# Amazon Web Services

Hopefully needs no introduction!

## Getting Started

You need to have credentials in `~/.aws/credentials`

### Prerequisites

aws-cli
jq

## Usage


```
$ awsShutdownInstanceVolumes.sh myprofile
us-west-2: vol-012a123456789abcd: 30
us-west-2: vol-012a123456789abce: 30
us-west-2: vol-012a123456789abcf: 8
Stopped GiB: 68
```

```
$ awsUnattachedVolumes.sh myprofile
us-west-2: vol-012a123456789abcg: 100
Unattached GiB: 100
```

## Contributing

Pull requests welcome!

## Versioning

We use [SemVer](http://semver.org/) for versioning.

## Authors

* **Justin Cook**

## License

This project is licensed under the BSD License

## Acknowledgments

* Auto Grid
