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

```
$ ./awsResourceByTag.py -r eu-west-1 name=test
{
    "Reservations": [],
    "ResponseMetadata": {
        "RequestId": "4c7bd606-01fc-4b3c-91af-5fa8014e0cea",
        "HTTPStatusCode": 200,
        "HTTPHeaders": {
            "content-type": "text/xml;charset=UTF-8",
            "transfer-encoding": "chunked",
            "vary": "accept-encoding",
            "date": "Sun, 26 May 2019 21:25:07 GMT",
            "server": "AmazonEC2"
        },
        "RetryAttempts": 0
    }
}
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
