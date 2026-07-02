# spellcheck Extension For Quarto

This extension provides a filter to run [Hunspell](https://hunspell.github.io/) whenever a `.qmd` file is rendered and prints potentially misspelled words to the console.

The current version was amended by Amy Heather, based on earlier MIT-licensed work by John MacFarlane and Christopher Kenny:

- John MacFarlane, *spellcheck.lua* in the Pandoc Lua filters repository: <https://github.com/pandoc/lua-filters/blob/master/spellcheck/spellcheck.lua>.
- Christopher Kenny, Quarto spellcheck extension repository: <https://github.com/christopherkenny/spellcheck/blob/main/_extensions/spellcheck/spellcheck.lua>.

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

## Installing the extension

From a directory with an existing Quarto file or project, run:

```bash
quarto add amyheather/spellcheck
```

Quarto installs extensions locally into an `_extensions` directory alongside your project or document, rather than into a global library. If you use version control, you should commit the `_extensions` directory to your repository.

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

## Example

A minimal example is provided in [example.qmd](example.qmd).

## Licensing

This repository is based on earlier MIT-licensed code by John MacFarlane and Christopher Kenny:

- John MacFarlane, *spellcheck.lua* in the Pandoc Lua filters repository: <https://github.com/pandoc/lua-filters/blob/master/spellcheck/spellcheck.lua>.
- Christopher Kenny, Quarto spellcheck extension repository: <https://github.com/christopherkenny/spellcheck>.

Amendments by Amy Heather are also released under the MIT License