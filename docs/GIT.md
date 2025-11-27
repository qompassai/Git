<!-- GIT.md -->
<!-- Qompass AI - [Add description here] -->
<!-- Copyright (C) 2025 Qompass AI, All rights reserved -->
<!-- ---------------------------------------- -->


# List all local branches
git branch

# List all remote branches
git branch -r

# List all branches (local + remote)
git branch -a


git fetch origin
git fetch upstream
git log origin/master --oneline -1
git log upstream/master --oneline -1


git fetch origin

# Switch to the master branch
git checkout master

# Pull latest changes (optional, in case master has been updated)
git pull origin master

# To view changes (commits) made on master
git log --oneline

# To see what files have changed compared to your current branch (before switching)
git diff <your-branch> master

# To see the latest changes between last two commits
git diff HEAD~1 HEAD

