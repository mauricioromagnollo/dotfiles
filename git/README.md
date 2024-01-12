# **Git**

> My git configs and aliases.

<br>

| Alias | Command | Definition  |  
|---|---|---|
|**git aacm**|`git add --all && git commit -m`|Add all files and start commit with message|
|**git aaca**|`git add --all && git commit --amend --no-edit`|Add all files and amend to current commit|
|**git s**|`git status -s`|Show status (added (A), modified (M), untracked (?), deleted (D) e staged)|
|**git l**|`git log --pretty=format:'%C(blue)%h %C(red)%d %C(white)%s - %C(cyan)%cn, %C(green)%cr'`|Show formatted commits in one line and colored|
| **git c** | `git commit` |Start commit with editor|
| **git cm** | `git commit -m` |Start commit with message|
| **git ca** | `git commit --amend --no-edit` |Amend into current commit|
| **git cae** | `git commit --amend` |Amend into current commit editing commit message|
| **git a** | `git add` |Add files|
| **git aa** | `git add --all` |Add all files|
| **git b** | `git branch` |Branch|
| **git bd `$BRANCH`** | `git branch -D` |Delete local branch|
| **git bdr `$BRANCH`** | `git push origin --delete` |Delete remote branch|
| **git bp `$BRANCH`** | `git push -u origin` |Push local branch to remote|
| **git rb** | `git rebase` |Rebase|
| **git rbc** | `git rebase --continue` |Continue Rebase|
| **git rba** | `git rebase --abort` |Abort Rebase|
| **git rbi `N`** | `git rebase -i HEAD~$1` |Interactive rebase to commit `N`|
| **git plr `$BRANCH`** | `git pull --rebase origin` |Pull and Rebase|
| **git pl** | `git pull` |Pull|
| **git p** | `git push` |Push|
| **git pf** | `git push --force` |Push force|
| **git pfl** | `git push --force-with-lease` |Push force with lease|
| **git fa** | `git fetch --all` |Fetch all|
| **git tg** | `git tag` |Tag|
| **git tgp `$TAG_NAME` `$MSG`** | `"!f(){ git tag \"$1\" -m \"$2\" && git push origin master --follow-tags;};f"` |Create new Tag with message and push|
| **git co** | `git checkout` |Checkout|
| **git com** | `git checkout master` |Checkout to master branch|
| **git cob `$BRANCH`** | `git checkout -b` |Create new branch and checkout|
|**git unst**|`git reset HEAD --`|Unstage last files added.|
|**git roll**|`git reset --soft HEAD~1`|Rollback last commit|
|**git squash**|`git reset --soft HEAD~1`|Squash all commits|
