#!/bin/bash

set -eux

docker run --rm -it -v "$PWD:/app" -p 5005:5005 metacpan/sco-redirect:latest
