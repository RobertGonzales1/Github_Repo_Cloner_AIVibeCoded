# GitHub Repo Cloner

A Windows PowerShell script that backs up **all of your GitHub repositories**. It clones your public repos, private repos and starred repos into a dated folder, then zips the folder.

Handy for periodic offline backups or for moving to a new machine.

## Features

- Clones your **public** and **private** repositories (only repos you own)
- Optionally clones your **starred** repositories too
- Saves everything into a dated folder, e.g. `20260616\my-repos\...` and `20260616\starred\...`
- Can sort repos into subfolders by programming language
- Skips repos that already exist in the output folder
- Zips the output with a live progress spinner, then removes the unzipped folder (optional)
- Prints a summary of cloned, skipped and failed repos when it finishes
- Handles GitHub API pagination, so it works with any number of repos

## Requirements

| Requirement | Notes |
|---|---|
| Windows 10 / 11 | Uses Windows PowerShell 5.1 (built in) or PowerShell 7+ |
| [Git](https://git-scm.com/) | Must be installed and on your `PATH` (`git --version` should work) |
| GitHub Personal Access Token | Optional for public repos only. **Required** for private repos |

## Installation

1. **Install Git** from <https://git-scm.com/> if you don't already have it.
2. **Download this repo.** Either:
   - Click **Code → Download ZIP** on GitHub and extract it, or
   - `git clone https://github.com/robertgonzales1/Github_Repo_Cloner_AIVibeCoded.git`
3. **Allow PowerShell scripts to run** (one-time, Windows 11 especially). Open PowerShell and run:
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
   ```
   If that still blocks the script, use:
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser Unrestricted
   ```
   > `run-clone.bat` already starts PowerShell with `-ExecutionPolicy Bypass` for that one run, so you may not need this step if you only use the `.bat` file.
4. If Windows marks the downloaded files as "blocked", right-click each file → **Properties** → tick **Unblock**. You can also run:
   ```powershell
   Get-ChildItem -Path . | Unblock-File
   ```

## Creating a GitHub token

1. Go to <https://github.com/settings/tokens>.
2. Choose **Generate new token (classic)**.
3. Give it a name and an expiration date, and tick the **`repo`** scope. You need that scope to read private repositories.
4. Click **Generate token** and copy it (it starts with `ghp_`).

> A **fine-grained** token also works. Give it access to *All repositories* with **Contents: Read-only** and **Metadata: Read-only**.

## Configuration

Open `clone-github-repos.ps1` in a text editor and edit the **CONFIGURATION** section at the top:

```powershell
$Username        = "your_github_username"  # Your GitHub username
$Token           = "ghp_your_token_here"   # Your GitHub Personal Access Token
$OutputDir       = "$PSScriptRoot\$DateStamp" # Where to save repos (dated folder)
$ZipWhenDone     = $true    # Zip the dated output folder when cloning finishes
$RemoveAfterZip  = $true    # Delete the folder once the zip is created

$IncludeStarred  = $true    # Also clone your starred repositories
$GroupByLanguage = $false   # Organize repos into subfolders by language
$SkipPublic      = $false   # Skip your public repositories
$SkipPrivate     = $false   # Skip your private repositories
```

| Setting | Default | Description |
|---|---|---|
| `$Username` | — | Your GitHub username (used to find your starred repos) |
| `$Token` | — | Your Personal Access Token. If you leave the placeholder, only public repos are cloned |
| `$OutputDir` | `<script folder>\yyyyMMdd` | Where the repos are saved |
| `$ZipWhenDone` | `$true` | Create `yyyyMMdd.zip` after cloning |
| `$RemoveAfterZip` | `$true` | Delete the unzipped folder after the zip is checked |
| `$IncludeStarred` | `$true` | Also clone repos you have starred |
| `$GroupByLanguage` | `$false` | Save repos in `my-repos\<Language>\<repo>` subfolders |
| `$SkipPublic` | `$false` | Don't clone your public repos |
| `$SkipPrivate` | `$false` | Don't clone your private repos |

## Usage

**Option 1:** Double-click **`run-clone.bat`**.

**Option 2:** Run it from PowerShell:
```powershell
cd path\to\Github_Repo_Cloner_AIVibeCoded
.\clone-github-repos.ps1
```

### Example output

```
Created directory: C:\Backups\20260616

Fetching your repositories...
  Public: 12  |  Private: 4
  Found 16 repositories.

  [CLONE] my-project  (Python, public)
  [CLONE] secret-stuff  (C#, private)
  ...
Fetching starred repositories for 'your_github_username'...
  Found 30 repositories.
  ...

--- Done ---
  Cloned:  46
  Skipped: 0
  Failed:  0
  Output:  C:\Backups\20260616

  Created: C:\Backups\20260616.zip (512.3 MB in 01:42)
  Removed source folder.
```

### Output layout

```
20260616\
├── my-repos\
│   ├── repo-one\
│   └── repo-two\
└── starred\
    ├── someone-elses-repo\
    └── ...
```

## Security notes

- **Never commit your real token.** Before you share the script or push it anywhere, set `$Token` back to `ghp_your_token_here`. A good habit is to keep your filled-in copy as `clone-github-repos.local.ps1`. That name is already in `.gitignore`.
- To clone private repos, the script puts the token into the clone URL. Git then saves that URL in each private repo's `.git\config`, and those files go into the zip. **Treat the backup folder and zip as sensitive.** To remove the token from a cloned repo, run:
  ```powershell
  git -C path\to\repo remote set-url origin https://github.com/<owner>/<repo>.git
  ```
- Give your token an expiration date and the smallest scope that works. Revoke it at <https://github.com/settings/tokens> if it ever leaks.

## Troubleshooting

| Problem | Fix |
|---|---|
| `running scripts is disabled on this system` | See step 3 of [Installation](#installation), or use `run-clone.bat` |
| `Git is not installed or not in PATH` | Install Git, then open a new PowerShell window |
| `[WARNING] Token not set` | Paste your token into `$Token`. Without one, only public repos are cloned |
| `401 Unauthorized` | The token is wrong or expired. Create a new one |
| Private repos missing | Make sure the token has the `repo` scope (classic) or Contents read access (fine-grained) |
| `403` / rate limit errors | Without a token, the GitHub API allows only 60 requests/hour. Add a token |
| `Skipped folder removal (zip not verified)` | The zip was missing or under 1 MB, so the folder was kept to be safe |

## License

[MIT](LICENSE)
