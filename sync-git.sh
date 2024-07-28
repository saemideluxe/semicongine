#!/bin/sh

rsync -r --exclude '.hg/' --exclude 'build/' --exclude 'sync-git.sh' . /home/sam/git/semicongine/

git -C /home/sam/git/semicongine/ commit -a -m $( hg log --limit 1 --template "{desc}" )
