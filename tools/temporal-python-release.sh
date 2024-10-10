#!/usr/bin/env bash

# https://www.notion.so/temporalio/Open-Source-Release-process-6267e8f184ba40218e9859610222285e#efa79ffc25344932811ab7d4c1865d96
set -u
set -e

git fetch --tags
git tag | sort -V

PREVIOUS_RELEASE=1.7.1
THIS_RELEASE=HEAD

git log $PREVIOUS_RELEASE..$THIS_RELEASE --pretty="%cd - %h - %s" --date=short | sort

cd /tmp
git clone --recurse-submodules git@github.com:temporalio/sdk-python.git
cd sdk-python
mkdir distrelease
poetry install --no-root

# ID of CI run on main post-merge of version bump
RUN_ID=

mkdir /tmp/artifacts
gh run download "$RUN_ID" --repo temporalio/sdk-python --dir /tmp/artifacts
mv /tmp/artifacts/*/* distrelease

# test.pypi
poetry run twine upload --repository testpypi distrelease/*
cd /tmp/
rm -fr samples-python
git clone org-56493103@github.com:temporalio/samples-python.git
# edit pyproject to use test.pypi
poetry update temporalio
poetry run python hello/hello_activity.py

# Real release
poetry run twine upload distrelease/*
cd /tmp/
rm -fr samples-python
git clone org-56493103@github.com:temporalio/samples-python.git
# edit pyproject
# DO NOT USE test.pypi !
poetry update temporalio
poetry run python hello/hello_activity.py
