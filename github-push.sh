#!/bin/bash


# prevent endless recursion
if [[ "$HG_ARGS" == *"github-mirror"* ]]; then
    exit 0
fi

hg bookmark hg
hg push github-mirror

