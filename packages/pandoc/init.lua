local base = require("packages.base")

local package = pl.class(base)
package._name = "pandoc"

-- Process arguments that might not actually have that much to do with their
-- immediate function but affect the document in other ways, such as setting
-- bookmarks on anything tagged with an ID attribute.
local handlePandocArgs = function (options)
  local wrapper = SILE.process
  if options.id then
    SU.debug("pandoc", "Set ID on tag")
    SILE.call("pdf:destination", { name = options.id })
  end
  if options.lang then
    SU.debug("pandoc", "Set lang in tag: "..options.lang)
    local fontfunc = SILE.Commands[SILE.Commands["font:" .. options.lang] and "font:" .. options.lang or "font"]
    local innerWrapper = wrapper
    wrapper = function (content)
      innerWrapper(function ()
        fontfunc({ language = options.lang }, content)
      end)
    end
    options.lang = nil
  end
  if options.classes then
    for _, class in pairs(pl.stringx.split(options.classes, ",")) do
      if class == "unnumbered" then
        SU.debug("pandoc", "Convert unnumbered class to legacy heading function option")
        options.numbering = false
      elseif SILE.Commands["class:"..class] then
        SU.debug("pandoc", "Add inner class wrapper: "..class)
        local innerWrapper = wrapper
        wrapper = function (content)
          innerWrapper(function ()
            SILE.call("class:"..class, options, content)
          end)
        end
      else
        SU.warn("Unhandled class ‘"..class.."’, not mapped to legacy option and no matching wrapper function")
      end
    end
    options.classes = nil
  end
  return wrapper, options
end

function package:_init (class)

  base._init(self, class)

  class:loadPackage("footnotes")
  class:loadPackage("image")
  class:loadPackage("pdf")
  class:loadPackage("raiselower")
  class:loadPackage("rules")
  class:loadPackage("url")
  class:loadPackage("verbatim")

end

function package:registerCommands ()

  local class = self.class

  -- Document level stuff

  -- Blocks

  class:registerCommand("BlockQuote", function (_, content)
    SILE.call("quote", {}, content)
    SILE.typesetter:leaveHmode()
  end)

  class:registerCommand("BulletList", function (_, content)
    -- luacheck: ignore pandocListType
    local pandocListType = "bullet"
    SILE.settings:temporarily(function ()
      SILE.settings:set("document.rskip","10pt")
      SILE.settings:set("document.lskip","20pt")
      SILE.process(content)
    end)
    SILE.typesetter:leaveHmode()
  end)

  class:registerCommand("CodeBlock", function (options, content)
    local wrapper, args = handlePandocArgs(options)
    wrapper(function ()
      SILE.call("verbatim", args, content)
    end)
    SILE.typesetter:leaveHmode()
  end)

  class:registerCommand("DefinitionList", function (_, content)
    SILE.process(content)
    SILE.typesetter:leaveHmode()
  end)

  class:registerCommand("Div", function (options, content)
    handlePandocArgs(options)(content)
    SILE.typesetter:leaveHmode()
  end, "Generic block wrapper")

  class:registerCommand("Header", function (options, content)
    local analog = options.type
    options.level, options.type = nil, nil
    local wrapper, args = handlePandocArgs(options)
    wrapper(function ()
      if analog and SILE.Commands[analog] then
        SILE.call(analog, args, content)
      else
        SILE.process(content)
      end
    end)
    SILE.typesetter:leaveHmode()
  end)

  class:registerCommand("HorizontalRule", function (_, _)
    SILE.call("center", {}, function ()
      SILE.call("raise", { height = "0.8ex" }, function ()
        SILE.call("hrule", { height = "0.5pt", width = "50%lw" })
        end)
      end)
    SILE.typesetter:leaveHmode()
  end)

  class:registerCommand("LineBlock", function (_, content)
    SILE.process(content)
    SILE.typesetter:leaveHmode()
  end)

  class:registerCommand("Null", function (_, _)
    SILE.typesetter:leaveHmode()
  end)

  class:registerCommand("OrderedList", function (_, content)
    -- TODO: handle listAttributes
    SILE.settings:temporarily(function ()
      SILE.settings:set("document.rskip","10pt")
      SILE.settings:set("document.lskip","20pt")
      SILE.process(content)
    end)
    SILE.typesetter:leaveHmode()
  end)

  class:registerCommand("Para", function (_, content)
    SILE.process(content)
    SILE.call("par")
    SILE.typesetter:leaveHmode()
  end)

  class:registerCommand("Plain", function (_, content)
    SILE.process(content)
    SILE.typesetter:leaveHmode()
  end)

  class:registerCommand("RawBlock", function (options, content)
    local format = options.format
    SU.debug("pandoc", format)
    -- TODO: execute as script? pass to different input parser?
    SILE.process(content)
    SILE.typesetter:leaveHmode()
  end)

  class:registerCommand("Table", function (options, content)
    SU.debug("pandoc", options.caption)
    -- TODO: options.caption
    -- TODO: options.align
    -- TODO: options.width
    -- TODO: options.headers
    SILE.process(content)
    SILE.typesetter:leaveHmode()
  end)

  -- Inlines

  class:registerCommand("Cite", function (options, content)
    SU.debug("pandoc", options, content)
    -- TODO: options is citation list?
  end, "Creates a Cite inline element")

  class:registerCommand("Code", function (options, content)
    local wrapper, args = handlePandocArgs(options)
    wrapper(function ()
      SILE.call("code", args, content)
    end)
  end, "Creates a Code inline element")

  class:registerCommand("Emph", function (_, content)
    SILE.call("em", {}, content)
  end, "Creates an inline element representing emphasised text.")

  class:registerCommand("Image", function (options, _)
    local wrapper, args = handlePandocArgs(options)
    wrapper(function ()
      SILE.call("img", args)
    end)
  end, "Creates a Image inline element")

  class:registerCommand("LineBreak", function (_, _)
    SILE.call("break")
  end, "Create a LineBreak inline element")

  class:registerCommand("Link", function (options, content)
    local wrapper, args = handlePandocArgs(options)
    wrapper(function ()
      SILE.call("url", args, content)
    end)
  end, "Creates a link inline element, usually a hyperlink.")

  class:registerCommand("Nbsp", function (_, _)
    SILE.typesetter:typeset(" ")
  end, "Output a non-breaking space.")

  class:registerCommand("Math", function (options, content)
    SU.debug("pandoc", options)
    -- TODO options is math type
    SILE.process(content)
  end, "Creates a Math element, either inline or displayed.")

  class:registerCommand("Note", function (_, content)
    SILE.call("footnote", {}, content)
  end, "Creates a Note inline element")

  class:registerCommand("Quoted", function (options, content)
    SU.debug("pandoc", options.type)
    -- TODO: options.type
    SILE.process(content)
  end, "Creates a Quoted inline element given the quote type and quoted content.")

  class:registerCommand("RawInline", function (options, content)
    local format = options.format
    SU.debug("pandoc", format)
    -- TODO: execute as script? pass to different input parser?
    SILE.process(content)
  end, "Creates a Quoted inline element given the quote type and quoted content.")

  class:registerCommand("SmallCaps", function (_, content)
    SILE.call("font", { features = "+smcp" }, content)
  end, "Creates text rendered in small caps")

  class:registerCommand("Span", function (options, content)
    handlePandocArgs(options)(content)
  end, "Creates a Span inline element")

  class:registerCommand("Strikeout", function (_, content)
    SILE.call("strikethrough", {}, content)
  end, "Creates text which is striked out.")

  class:registerCommand("Strong", function (_, content)
    SILE.call("strong", {}, content)
  end, "Creates a Strong element, whose text is usually displayed in a bold font.")

  local scriptOffset = "0.7ex"
  local scriptSize = "1.5ex"

  class:registerCommand("Subscript", function (_, content)
    SILE.call("lower", { height = scriptOffset }, function ()
      SILE.call("font", { size = scriptSize }, content)
    end)
  end, "Creates a Subscript inline element")

  class:registerCommand("Superscript", function (_, content)
    SILE.call("raise", { height = scriptOffset }, function ()
      SILE.call("font", { size = scriptSize }, content)
    end)
  end, "Creates a Superscript inline element")

  -- Utility wrapper classes

  class:registerCommand("class:csl-no-emph", function (_, content)
    SILE.call("font", { style = "Roman" }, content)
  end,"Inline upright wrapper")

  class:registerCommand("class:csl-no-strong", function (_, content)
    SILE.call("font", { weight = 400 }, content)
  end,"Inline normal weight wrapper")

  class:registerCommand("class:csl-no-smallcaps", function (_, content)
    SILE.call("font", { features = "-smcp" }, content)
  end,"Inline smallcaps disable wrapper")

  -- Non native types

  class:registerCommand("ListItem", function (_, content)
    SILE.call("smallskip")
    SILE.call("glue", { width = "-1em"})
    SILE.call("rebox", { width = "1em" }, function ()
      -- Note: Relies on Lua scope shadowing to find immediate parent list type
      -- luacheck: ignore pandocListType
      if pandocListType == "bullet" then
        SILE.typesetter:typeset("•")
      else
        SILE.typesetter:typeset("-")
      end
    end)
    SILE.process(content)
    SILE.call("smallskip")
  end)

  class:registerCommand("ListItemTerm", function (_, content)
    SILE.call("smallskip")
    SILE.call("strong", content)
    SILE.typesetter:typeset(" : ")
  end)

  class:registerCommand("ListItemDefinition", function (_, content)
    SILE.process(content)
    SILE.call("smallskip")
  end)

end

package.documentation = [[
\begin{document}

Cover all the possible commands Pandoc's SILE export might throw at us.

\end{document}
]]

return package
