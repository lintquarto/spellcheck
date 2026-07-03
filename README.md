# spellcheck extension for Quarto

This extension provides a filter to run [Hunspell](https://hunspell.github.io/) whenever a `.qmd` file is rendered and prints potentially misspelled words to the console.

The current version was amended by Amy Heather, based on earlier MIT-licensed work by John MacFarlane and forked from Christopher Kenny:

- John MacFarlane, *spellcheck.lua* in the Pandoc Lua filters repository: <https://github.com/pandoc/lua-filters/blob/master/spellcheck/spellcheck.lua>.
- Christopher Kenny, Quarto spellcheck extension repository: <https://github.com/christopherkenny/spellcheck>.

Amendments in this repository are also released under the MIT Licence.

<br>

## Requirements

You must have Hunspell installed for this extension to work.

If you want to use British English, make sure the `en_GB` dictionary is installed as well as Hunspell itself. On Ubuntu and Debian, this is typically provided by `hunspell-en-gb`

**Ubuntu/Debian:**

```bash
sudo apt update
sudo apt install hunspell hunspell-en-gb
```

**macOS with Homebrew:**

```bash
brew install hunspell
```

**Windows with Chocolatey:**

```bash
choco install hunspell.portable
```

<br>

## Installing the extension

From a directory with an existing Quarto file or project, run:

```bash
quarto add lintquarto/spellcheck
```

Quarto installs extensions locally into an `_extensions` directory alongside your project or document, rather than into a global library. If you use version control, you should commit the `_extensions` directory to your repository.

<br>

## Using the extension

After installation, add the filter to your document YAML or your project-level `_quarto.yml`.

You can specify which language to use (default is British England `en_GB`).

You can also specify words to ignore.

**In a document:**

```yaml
---
filters:
  - spellcheck
spellcheck-lang: en_GB
spellcheck-ignore:
  - ignoreme
---
```

**In `_quarto.yml`:**

```yaml
---
project:
  type: default

filters:
  - spellcheck
spellcheck-lang: en_GB
spellcheck-ignore:
  - ignoreme
---
```

When the document is rendered, the filter prints possible misspellings to the console, for example:

```text
Possibly misspelled words:
--------------------------
consol
listd
spelld
--------------------------
```

<br>

## Running spellcheck

The extension will run when the document is rendered. A minimal example is provided:

```
quarto render example.qmd
```

To run it without running code:

```
quarto render example.qmd --metadata execute.eval=false
```

To run spellcheck via a GitHub action:

```
name: spellcheck

on:
  push:

jobs:
  spellcheck:
    runs-on: ubuntu-latest

    steps:
      - name: Check out repository
        uses: actions/checkout@v4

      - name: Set up Quarto
        uses: quarto-dev/quarto-actions/setup@v2

      - name: Install Hunspell
        run: |
          sudo apt-get update
          sudo apt-get install -y hunspell hunspell-en-gb

      - name: Run spellcheck render
        run: |
          quarto render . --metadata execute.eval=false
```