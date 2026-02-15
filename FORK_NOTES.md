Fork maintenance notes

Remotes
- upstream: original project (chaldea-center/chaldea)
- origin: your fork (e.g., DavidNavalho/chaldea)

Initial setup
- If starting from the upstream clone:
  - git remote rename origin upstream
  - git remote add origin git@github.com:YOURUSER/chaldea.git
  - git remote -v

Sync workflow (rebase; recommended)
- Rebase local main onto upstream/main and push to your fork:
  - sh scripts/sync_fork.sh
- Other branches: sh scripts/sync_fork.sh -b <branch>
- Merge instead of rebase: sh scripts/sync_fork.sh --merge
- Keep local changes stashed and re-apply automatically: sh scripts/sync_fork.sh --pop-stash

Conflict handling
- If the script reports conflicts during rebase/merge, fix files, then:
  - Rebase: git add <files> && git rebase --continue
  - Merge: git add <files> && git commit
- If stash pop reports conflicts, resolve and commit as usual.

Notes
- The script uses --force-with-lease when rebasing to protect against overwriting remote work.
- Prefer keeping platform lockfiles (e.g., macOS Podfile.lock) from upstream during syncs unless you intentionally changed dependencies.
- After syncing, run your usual checks (e.g., sh scripts/format.sh, flutter analyze, flutter test).

