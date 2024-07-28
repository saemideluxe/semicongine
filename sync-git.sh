#!/bin/sh

rsync -r --exclude '.hg/' --excdlue 'build/' . /home/sam/git/semicongine/

git -C /home/sam/git/semicongine/ commit -a -m $( hg log --limit 1 --template "{desc}" )
