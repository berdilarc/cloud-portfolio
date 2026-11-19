# Cloud Portfolio

## Development

[mise](https://mise.jdx.dev/) installs the tools the checks need, at the versions pinned in `mise.toml`. CI installs the same versions from `mise.lock`, which records their checksums.

```sh
mise install
pre-commit install
```

[pre-commit](https://pre-commit.com/) then runs the checks from `.pre-commit-config.yaml` on every commit. To run them on all files, as CI does:

```sh
pre-commit run --all-files
```

To change a tool version, edit `mise.toml` and run `mise lock` to update `mise.lock`. Dependabot does not update either file.
