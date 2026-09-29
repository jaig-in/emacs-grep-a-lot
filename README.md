# emacs-grep-a-lot

**Multiple named search buffers with word-at-point grep and ripgrep for Emacs.**

A modernized rewrite of [grep-a-lot](https://github.com/ZungBang/emacs-grep-a-lot) and [grep-o-matic](https://github.com/ZungBang/emacs-grep-o-matic) by [Avi Rozen](https://github.com/ZungBang), plus a new ripgrep counterpart.

## What's in the box

| File | What it does | Default keys |
|---|---|---|
| `grep-a-lot.el` | Every grep gets its own `*grep:<term>*<N>` buffer; ring navigation | `M-g ]` next · `M-g [` prev · `M-g _` kill all |
| `grep-o-matic.el` | One-key grep word-at-point via `rgrep` — repo / dir / open files | `M-]` then `/` `.` `,` |
| `rg-o-matic.el` | Same idea, but uses [ripgrep](https://github.com/BurntSushi/ripgrep) | `M-\` then `/` `.` `,` |

All three are independent `provide`/`require` packages. Use any combination.

## Quick start

```elisp
;; Add to load-path (or install via straight/elpaca/use-package)
(add-to-list 'load-path "/path/to/emacs-grep-a-lot")

(require 'grep-a-lot)
(grep-a-lot-setup-keys)

(require 'grep-o-matic)
(grep-o-matic-setup-keys)

(require 'rg-o-matic)        ; needs `rg` on PATH
(rg-o-matic-setup-keys)
```

## What changed from the originals

### grep-a-lot (was 1.0.7)
- **Lexical binding**, no `(require 'advice)` or `defadvice`
- Buffers named `*grep:<search-term>*<N>` instead of `*grep*<N>` — you can tell what each search was
- Uses `compilation-start-hook` instead of advising `grep`/`lgrep`/`rgrep`
- Dropped igrep support (unmaintained since 2013)
- Requires Emacs 28.1+

### grep-o-matic (was 1.0.7)
- Uses `project-root` / `vc-root-dir` instead of the separate `repository-root.el` package
- Expanded default file patterns (JS/TS, Rust, Go, YAML, Dockerfile, etc.)
- Lexical binding, `cl-lib`
- Dropped igrep support

### rg-o-matic (new)
- Ripgrep counterpart to grep-o-matic
- Results in `grep-mode` so grep-a-lot ring navigation works across grep and rg buffers
- Customizable via `rg-o-matic-executable` and `rg-o-matic-default-args`

## Key bindings at a glance

```
M-g ]           grep-a-lot-next         cycle to next search buffer
M-g [           grep-a-lot-prev         cycle to previous
M-g _           grep-a-lot-kill-all     kill all search buffers

M-] /           grep-o-matic-repository         grep word-at-point in project
M-] .           grep-o-matic-current-directory   grep in current dir
M-] ,           grep-o-matic-visited-files       grep across open files

M-\ /           rg-o-matic-project      rg word-at-point in project
M-\ .           rg-o-matic-directory    rg in current dir
M-\ ,           rg-o-matic-open-files   rg across open files
```

Prefix any `-o-matic` command with `C-u` to edit the search term before running.

## Requirements

- Emacs 28.1+
- [ripgrep](https://github.com/BurntSushi/ripgrep) on PATH (for rg-o-matic only)

## Credits

Based on the original [grep-a-lot](https://github.com/ZungBang/emacs-grep-a-lot) and [grep-o-matic](https://github.com/ZungBang/emacs-grep-o-matic) by **Avi Rozen** ([@ZungBang](https://github.com/ZungBang)). Licensed under GPL-3.0, same as the originals.

## License

[GPL-3.0](LICENSE)
