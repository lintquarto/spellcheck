-- Spellcheck Pandoc/Quarto documents with Hunspell.
-- 
-- What this filter does:
-- 1. Reads spellcheck settings from document metadata.
-- 2. Collects words from the document, grouped by language.
-- 3. Ignores configured words.
-- 4. Runs Hunspell once per language and prints possible misspellings.
--
-- Expected metadata:
--   spellcheck-lang: en_GB
--   spellcheck-ignore:
--     - SimPy
--     - Quarto
--
-- This filter is adapted from:
-- - John MacFarlane (MIT). https://github.com/pandoc/lua-filters/blob/master/spellcheck/spellcheck.lua.
-- - Chrisopher Kenny (MIT). https://github.com/christopherkenny/spellcheck/blob/main/_extensions/spellcheck/spellcheck.lua.

-- Require a Pandoc version new enough to support pandoc.utils.stringify on metadata.
if PANDOC_VERSION == nil then
  error("ERROR: pandoc >= 2.1 required for spellcheck.lua filter")
end

-- Unique words grouped by language - words[lang][word] = count
local words = {}

-- Words to ignore even if Hunspell flags them.
local words_to_drop = {"Doi"}

-- Default language (set via document metadata)
local deflang

-- Return true if a value exists in a list-like table
local function in_table(tbl, value)
    if tbl == nil then
        return false
    end
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- Record one word under a given language.
-- Creates the language entry the first time it is seen.
local function add_to_dict(lang, t)
  if not words[lang] then
    words[lang] = {}
  end
  words[lang][t] = (words[lang][t] or 0) + 1
end

-- Read default spellcheck language from metadata
-- YAML example:
-- spellcheck-lang: en_GB
local function get_deflang(meta)
  deflang = (meta['spellcheck-lang'] and pandoc.utils.stringify(meta['spellcheck-lang'])) or 'en_GB'
  return nil
end

-- Read additional ignore words from metadata
-- YAML example:
-- spellcheck-ignore:
--   - SimPy
--   - Quarto
local function read_ignore_words(meta)
  local env = meta['spellcheck-ignore']
  if env ~= nil then
    for _, v in ipairs(env) do
      local value = pandoc.utils.stringify(v)
      words_to_drop[#words_to_drop + 1] = value
    end
  end
end

-- Handle inline spans with explicit language:
-- <span lang="fr">bonjour</span>
local function checkspan(el)
  local lang = el.attributes.lang
  if not lang then return nil end
  pandoc.walk_inline(el, {Str = function(e) add_to_dict(lang, e.text) end})
  return nil
end

-- Handle block elements with explicit language:
-- ::: {lang="de"}
-- text
-- :::
local function checkdiv(el)
  local lang = el.attributes.lang
  if not lang then return nil end
  pandoc.walk_block(el, {Str = function(e) add_to_dict(lang, e.text) end})
  return nil
end

-- Run Hunspell on all collected words for a given language
local function run_spellcheck(lang)
  -- Prepare list of collected words for Hunspell
  -- Collect unique words (keys of words[lang])
  local keys = {}
  local wordlist = words[lang]

  for k,_ in pairs(wordlist) do
    if not in_table(words_to_drop, k) then
      keys[#keys + 1] = k
    end
  end

  -- Run Hunspell via pandoc.pipe
  -- -l: list misspelled words
  -- -d: dictionary (language)
  -- -p: personal dictionary file
  local success, outp = pcall(function()
    return pandoc.pipe('hunspell', { '-l', '-d', lang}, table.concat(keys, '\n'))
  end)

  -- Output results or warning
  if success then
    print('Possibly misspelled words:')
    print('--------------------------')
    io.write(outp)
    print('--------------------------\n')
  else
    print("Warning: Hunspell is not installed or not accessible. Skipping spell check for '" .. lang .. "'.")
  end
end

-- Final callback after document traversal.
-- At this point, all words should already have been collected.
local function results(el)
  for lang,_ in pairs(words) do
    run_spellcheck(lang)
  end
end

-- Register filter passes in a deliberate order:
-- 1. Read metadata first.
-- 2. Handle language-specific containers.
-- 3. Collect ordinary words in the default language.
-- 4. Run spellcheck once at the end.
return {
  {Meta = get_deflang},
  {Meta = read_ignore_words},
  {Div = checkdiv, Span = checkspan},
  {
    Str = function(e) add_to_dict(deflang, e.text) end,
    Pandoc = results
  }
}
