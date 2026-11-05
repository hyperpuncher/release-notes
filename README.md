# release notes

One GitHub Action that renders grouped release notes from git history. It uses `git` and the `gh` CLI, both already on every runner. No third-party action, no downloaded binary, no node bundle.

<!-- prettier-ignore -->
```markdown
### what's changed

#### feat
- show album track play counts [`f52c890`](https://github.com/you/repo/commit/f52c890...) by @you

#### fix
- close context menus with Escape [`8ea7adf`](https://github.com/you/repo/commit/8ea7adf...)

**full changelog:** [v0.5.7...v0.6.0](https://github.com/you/repo/compare/v0.5.7...v0.6.0)
```

each commit carries its author handle. those mentions are also what makes GitHub render its own **Contributors** avatar block under the release, so no separate list is needed.

## usage

whole workflow file:

```yaml
name: release

on:
    push:
        tags: ["v*"]

permissions:
    contents: write # only the publish step needs write, the notes step reads

jobs:
    publish:
        runs-on: ubuntu-slim # required, there is no default
        steps:
            - uses: actions/checkout@v7
              with:
                  fetch-depth: 0 # the action reads tags and the full range

            - uses: hyperpuncher/release-notes@v1
              id: notes

            - run: gh release create "$GITHUB_REF_NAME" dist/* --verify-tag --notes-file "${{ steps.notes.outputs.path }}"
              env:
                  GH_TOKEN: ${{ github.token }}
```

the action only writes a file. publishing stays in your workflow, so each project keeps its own draft, asset, and latest rules.

## inputs

| input          | default                               | meaning                                                 |
| -------------- | ------------------------------------- | ------------------------------------------------------- |
| `tag`          | `github.ref_name`                     | tag to render                                           |
| `previous_tag` | detected                              | compare base. found from the parent of `tag` when empty |
| `output`       | `${{ runner.temp }}/release-notes.md` | file to write                                           |
| `contributors` | `true`                                | add hidden mentions, so GitHub shows its avatar block   |
| `token`        | `github.token`                        | used to resolve logins for non-noreply emails           |

## outputs

| output | meaning                            |
| ------ | ---------------------------------- |
| `path` | the markdown file that was written |

## how it reads commits

- conventional prefixes are grouped and ranked `feat fix perf refactor style docs build test ci chore revert`, anything else goes last under `other`
- the prefix and the scope are removed, the subject is kept
- breaking markers (`feat!:` or `feat(api)!:`) do not change placement
- `--use-mailmap` is passed, so a `.mailmap` merges duplicate authors
- handles come from noreply emails without a network call. other addresses get one `gh api` call per unique email, cached. authors with no GitHub account get no handle, and bots are skipped

## test

```sh
bash tests/run.sh
```

The test builds a throwaway repository with fixture commits, then compares the rendered shape: group order, prefix and scope removal, breaking markers, unknown types, the first release with no previous tag, and the hidden mentions line. It runs offline because the fixture authors use noreply addresses.

## pinning

`@v1` is a tag and can move. pin the full commit sha if you want the strict version:

```yaml
- uses: hyperpuncher/release-notes@<sha>
```

## limits

- needs `fetch-depth: 0` in `actions/checkout`
- needs `bash`, `git` and `gh` on the runner. `ubuntu-slim` has all three and starts fastest. it is 1 CPU in a container with a 15 minute job limit
- macOS ships bash 3.2 and the script needs bash 4, so ubuntu is the supported runner
- tags must match `v[0-9]*` for auto detection, or pass `previous_tag`
- the compare link and commit links use `github.server_url`, so GitHub Enterprise works
