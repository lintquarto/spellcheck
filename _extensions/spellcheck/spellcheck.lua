-- Spellcheck Pandoc/Quarto documents with Hunspell.
-- 
-- What this filter does:
-- 1. Reads spellcheck settings from document metadata.
-- 2. Collects words from the document body using a default language, with
--    overrides for spans and blocks that declare their own lang.
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

-- ---------------------------------------------------------------------------
-- Version check
-- ---------------------------------------------------------------------------

-- Require a Pandoc version new enough to support pandoc.utils.stringify on metadata.
if PANDOC_VERSION == nil then
  error("ERROR: pandoc >= 2.1 required for spellcheck.lua filter")
end

-- ---------------------------------------------------------------------------
-- Shared state
-- These objects hold information while Pandoc walks through the document.
-- ---------------------------------------------------------------------------

-- A nested table of unique words, grouped by language
-- Shape:
--   words[lang][word] = count
-- Examples:
--   words["en_GB"]["colour"] = 3
--   words["fr"]["bonjour"] = 1
local words = {}

-- Words to ignore even if Hunspell flags them.
-- This is a starting list built into the filter.
-- Extra ignored words can also be added from the metadata.
local words_to_drop = {"Doi"}

-- Default spellcheck language.
-- This is set from document metadata in get_deflang().
-- If metadata does not provide a value, we fall back to en_GB.
local deflang

-- ---------------------------------------------------------------------------
-- Small helper functions
-- These are generic utility functions used by the main filter logic.
-- ---------------------------------------------------------------------------

-- Return true if a value exists in a list-like table
-- Parameters:
--   tbl - a sequential Lua table
--   value - the value to search for
-- Returns:
--   true if value is found
--   false otherwise
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

-- Return true if a word should be excluded from spellchecking.
-- A word is dropped if it exactly matches any entry in words_to_drop,
-- or if it contains any entry as a substring (to handle compound tokens
-- like "MR/Z503915/1]." which contain an ignored word).
-- Parameters:
--   word - the word or token to test
-- Returns:
--   true if the word should be excluded
--   false otherwise
local function should_drop(word)
  for _, v in ipairs(words_to_drop) do
    if word == v or word:find(v, 1, true) then
      return true
    end
  end
  return false
end

-- Record one word under a given language.
-- Creates the entry if it doesn't already exist, else increments count.
-- Parameters:
--   lang - dictionary/language key (e.g., "en_GB")
--   t - the word to record
-- Example:
--   add_to_dict("en_GB", "simulation")
-- After calling this twice:
--   words["en_GB"]["simulation"] == 2
local function add_to_dict(lang, t)
  if in_table(words_to_drop, t) then return end
  if not words[lang] then
    words[lang] = {}
  end
  words[lang][t] = (words[lang][t] or 0) + 1
end

-- ---------------------------------------------------------------------------
-- Metadata readers
-- These functions run on the document metadata before the main text traversal.
-- ---------------------------------------------------------------------------

-- Read default spellcheck language from metadata.
-- YAML example:
--   spellcheck-lang: en_GB
-- If the metadata field is absent, use en_GB.
-- We use stringify as metadata values are Pandoc objects, not always plain Lua
-- strings, so pandoc.utils.stringify converts them into normal text we can use.
local function get_deflang(meta)
  deflang = (meta['spellcheck-lang'] and pandoc.utils.stringify(meta['spellcheck-lang'])) or 'en_GB'
  return nil
end

-- Read additional ignore words from metadata
-- YAML example:
--   spellcheck-ignore:
--     - SimPy
--     - Quarto
-- Each listed value is converted to plain text and appended to
-- words_to_drop, so these words will be skipped before Hunspell runs.
local function read_ignore_words(meta)
  local env = meta['spellcheck-ignore']
  if env ~= nil then
    for _, v in ipairs(env) do
      local value = pandoc.utils.stringify(v)
      words_to_drop[#words_to_drop + 1] = value
    end
  end
end

-- ---------------------------------------------------------------------------
-- Language-specific text collectors
-- These functions handle parts of the document that explicitly declare a
-- language via the lang attribute.
-- ---------------------------------------------------------------------------

-- Handle inline spans with explicit language
-- Example:
--   <span lang="fr">bonjour</span>
local function checkspan(el)
  local lang = el.attributes.lang
  if not lang then return nil end
  pandoc.walk_inline(el, {Str = function(e) add_to_dict(lang, e.text) end})
  return nil
end

-- Handle block elements with explicit language:
-- Example:
--   ::: {lang="de"}
--   text
--   :::
local function checkdiv(el)
  local lang = el.attributes.lang
  if not lang then return nil end
  pandoc.walk_block(el, {Str = function(e) add_to_dict(lang, e.text) end})
  return nil
end

-- ---------------------------------------------------------------------------
-- Body text collector
-- Once all configuration is known, this collects ordinary words from the
-- document body only (not metadata).
-- ---------------------------------------------------------------------------

-- Walk only the document body, not metadata.
-- This prevents values like theme names (e.g. "cosmo") from being treated
-- as spellcheck candidates.
local function collect_body_words(doc)
  pandoc.walk_block(pandoc.Div(doc.blocks), {
    Str = function(e)
      add_to_dict(deflang, e.text)
    end
  })
end

-- ---------------------------------------------------------------------------
-- Hunspell runner
-- Once all words have been collected, these functions prepare the word list
-- and pass it to Hunspell.
-- ---------------------------------------------------------------------------

-- Run Hunspell on all collected words for a given language.
-- Parameters:
--   lang - language/dictionary name, e.g. "en_US" or "en_GB"
local function run_spellcheck(lang)

  -- Collect the unique words for this language.
  -- The keys of words[lang] are the distinct words we saw in the document.
  local keys = {}
  local wordlist = words[lang]
  for k,_ in pairs(wordlist) do
    if not should_drop(k) then
      keys[#keys + 1] = k
    end
  end

  -- Run Hunspell via pandoc.pipe
  -- -l: list misspelled words
  -- -d: dictionary (language)
  -- table.concat(keys, "\n") creates the newline-separated input expected by
  -- hunspell when reading from standard input.
  local success, outp = pcall(function()
    return pandoc.pipe('hunspell', { '-l', '-d', lang}, table.concat(keys, '\n'))
  end)

  -- Print results if hunspell succeeded, otherwise show a warning.
  if success then
    print('Possibly misspelled words:')
    print('--------------------------')
    io.write(outp)
    print('--------------------------\n')
  else
    print("Warning: Hunspell is not installed or not accessible. Skipping spell check for '" .. lang .. "'.")
  end
end

-- ---------------------------------------------------------------------------
-- Final reporting step
-- ---------------------------------------------------------------------------

-- This function runs after document traversal.
-- It first collects ordinary words from the document body, then loops over
-- each language seen and runs spellcheck once for that language.
local function results(doc)
  collect_body_words(doc)
  for lang,_ in pairs(words) do
    run_spellcheck(lang)
  end
end

-- ---------------------------------------------------------------------------
-- Filter registration
-- ---------------------------------------------------------------------------

-- Pandoc Lua filters are returned as a list of filter passes.
-- This filter runs in four stages:
--   Pass 1. Read metadata and set the default language.
--   Pass 2: Read metadata and extend the ignore-word list.
--   Pass 3: Handle Div/Span elements with explicit lang attributes.
--   Pass 4: Collect ordinary Str elements from the document body, then
--           run the final spellcheck step once at the end.
return {
  {Meta = get_deflang},
  {Meta = read_ignore_words},
  {Div = checkdiv, Span = checkspan},
  {Pandoc = results}
}
