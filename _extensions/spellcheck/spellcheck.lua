-- lua filter for spell checking
-- Copyright (C) 2017-2020 John MacFarlane, released under MIT license
-- Altered to use hunspell and work with Quarto by Christopher T. Kenny

-- Ensure Pandoc version supports stringify on Meta (>= 2.1)
if PANDOC_VERSION == nil then
  error("ERROR: pandoc >= 2.1 required for spellcheck.lua filter")
end

-- Stores words grouped by language: words[lang][word] = count
local words = {}

-- Words to ignore during spellcheck (user + defaults)
local words_to_drop = {"Doi"}

-- Default language (set via document metadata)
local deflang

-- Debug helper: recursively stringify a Lua table
-- Useful for inspecting intermediate structures during development
function dump(o)
  if type(o) == 'table' then
    local s = '{ '
    for k, v in pairs(o) do
      if type(k) ~= 'number' then k = '"' .. k .. '"' end
      s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
    end
    return s .. '} '
  else
    return tostring(o)
  end
end

-- Write a list of words to a file (one per line)
-- Used to create a temporary "personal dictionary" for Hunspell
local function write_words(tbl, path)
  file = io.open(path, "w")
  for i, wrd in ipairs(tbl) do
    file:write(wrd, '\n')
  end
  file:close()
  return file
end

-- UNUSED
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

-- Add a word to the dictionary for a given language
-- Ensures the language table exists, then increments count
local function add_to_dict(lang, t)
  if not words[lang] then
    words[lang] = {}
  end
  if not words[lang][t] then
    words[lang][t] = (words[lang][t] or 0) + 1
  end
end

-- Read default spellcheck language from metadata
-- YAML example:
-- spellcheck-lang: en_GB
local function get_deflang(meta)
  deflang = (meta['spellcheck-lang'] and pandoc.utils.stringify(meta['spellcheck-lang'])) or 'en_US'
  return nil
end

-- Run Hunspell on all collected words for a given language
local function run_spellcheck(lang)
  -- Prepare list of collected words for Hunspell
  -- Collect unique words (keys of words[lang])
  local keys = {}
  local wordlist = words[lang]

  for k,_ in pairs(wordlist) do
    --if not in_table(words_to_drop, k) then
        keys[#keys + 1] = k
    --end
  end

  -- Temporary file for ignore list (personal dictionary)
  local f = '.spellcheck.txt'
  write_words(words_to_drop, f)

  -- Run Hunspell via pandoc.pipe
  -- -l: list misspelled words
  -- -d: dictionary (language)
  -- -p: personal dictionary file
  local success, outp = pcall(function()
    return pandoc.pipe('hunspell', { '-l', '-d', lang, '-p', f}, table.concat(keys, '\n'))
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

  -- Clean up temp file
  os.remove(f)
end

-- Final step after document traversal
-- Ensures all words are collected, then runs spellcheck per language
local function results(el)
  pandoc.walk_block(pandoc.Div(el.blocks), {Str = function(e) add_to_dict(deflang, e.text) end})
  for lang,_ in pairs(words) do
    run_spellcheck(lang)
  end
end

-- Add individual string elements to default language dictionary
-- (Defined but not used directly in final filter table)
local function checkstr(el)
  add_to_dict(deflang, el.text)
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

-- Register filter callbacks with Pandoc
-- Order matters: metadata first, then element traversal, then final step
return {
  {Meta = get_deflang},
  {Meta = read_ignore_words},
  {Div = checkdiv, Span = checkspan},
  {
    Str = function(e) add_to_dict(deflang, e.text) end,
    Pandoc = results
  }
}
