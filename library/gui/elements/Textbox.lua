-- NoIndex: true

--[[	Lokasenna_GUI - Textbox class

    For documentation, see this class's page on the project wiki:
    https://github.com/jalovatt/Lokasenna_GUI/wiki/Textbox

    Creation parameters:
	name, z, x, y, w, h[, caption, pad]

]]--

local Buffer = require("gui.buffer")

local Font = require("public.font")
local Color = require("public.color")
local Math = require("public.math")
local Text = require("public.text")
-- local Table = require("public.table")

local Config = require("gui.config")

local Const = require("public.const")

local TextUtils = require("gui.elements._text_utils")

local Textbox = require("gui.element"):new()
Textbox.__index = Textbox
Textbox.defaultProps = {

  type = "Textbox",
  x = 0,
  y = 0,
  w = 96,
  h = 24,
  retval = "",
  caption = "Textbox",
  pad = 4,
  bg = "windowBg",
  color = "txt",
  captionFont = 3,
  textFont = "monospace",
  captionPosition = "left",
  undoLimit = 20,
  undoStates = {},
  redoStates = {},
  windowPosition = 0,
  caret = 0,
  selectionStart = nil,
  selectionEnd = nil,
  charH = nil,
  windowH = nil,
  windowW = nil,
  charW = nil,
  focus = false,
  blink = 0,
  shadow = true,
}

function Textbox:new(props)
	local txt = self:addDefaultProps(props)

	return self:assignChild(txt)
end


function Textbox:init()

	local w, h = self.w, self.h

	self.buffer = Buffer.get()

	gfx.dest = self.buffer
	gfx.setimgdim(self.buffer, -1, -1)
	gfx.setimgdim(self.buffer, 2*w, h)

	Color.set("elmBg")
	gfx.rect(0, 0, 2*w, h, 1)

	Color.set("elmFrame")
	gfx.rect(0, 0, w, h, 0)

	Color.set("elmFill")
	gfx.rect(w, 0, w, h, 0)
	gfx.rect(w + 1, 1, w - 2, h - 2, 0)

  -- Make sure we calculate this ASAP to avoid errors with
  -- dynamically-generated textboxes
  if gfx.w > 0 then self:recalculateWindow() end

end


function Textbox:onDelete()

	Buffer.release(self.buffer)

end


function Textbox:draw()

	-- Some values can't be set in :init() because the window isn't
	-- open yet - measurements won't work.
	if not self.windowW then self:recalculateWindow() end

	if self.caption and self.caption ~= "" then self:drawCaption() end

	-- Blit the textbox frame, and make it brighter if focused.
	gfx.blit(self.buffer, 1, 0, (self.focus and self.w or 0), 0,
           self.w, self.h, self.x, self.y)

  if self.retval ~= "" then self:drawText() end

	if self.focus then

		if self.selectionStart then self:drawSelection() end
		if self.showCaret then self:drawCaret() end

	end

  self:drawGradient()

end


function Textbox:val(newval)

	if newval then
    self:setEditorState(tostring(newval))
		self:redraw()
	else
		return self.retval
	end

end


-- Just for making the caret blink
function Textbox:onUpdate()

	if self.focus then

		if self.blink == 0 then
			self.showCaret = true
			self:redraw()
		elseif self.blink == math.floor(Config.caretBlinkRate / 2) then
			self.showCaret = false
			self:redraw()
		end
		self.blink = (self.blink + 1) % Config.caretBlinkRate

	end

end

-- Make sure the box highlight goes away
function Textbox:lostFocus()

    self:redraw()

end



------------------------------------
-------- Input methods -------------
------------------------------------


function Textbox:onMouseDown(state)

  self.caret = self:getCaret(state.mouse.x)

  -- Reset the caret so the visual change isn't laggy
  self.blink = 0

  -- Shift+click to select text
  if state.mouse.cap & 8 == 8 and self.caret then

    self.selectionStart, self.selectionEnd = self.caret, self.caret

  else

    self.selectionStart, self.selectionEnd = nil, nil

  end

  self:redraw()

end


function Textbox:onDoubleclick(state)

	self:selectWord(state)

end


function Textbox:onDrag(state)

	self.selectionStart = self:getCaret(state.mouse.ox, state.mouse.oy)
  self.selectionEnd = self:getCaret(state.mouse.x, state.mouse.y)

	self:redraw()

end


function Textbox:onType(state)

	local char = state.kb.char

  -- Navigation keys, Return, clipboard stuff, etc
  if self.keys[char] then

    local shift = state.mouse.cap & 8 == 8

    if shift and not self.sel then
      self.selectionStart = self.caret
    end

    -- Flag for some keys (clipboard shortcuts) to skip
    -- the next section
    local bypass = self.keys[char](self, state)

    if shift and char ~= Const.char.BACKSPACE then

      self.selectionEnd = self.caret

    elseif not bypass then

      self.selectionStart, self.selectionEnd = nil, nil

    end

  -- Typeable chars
  elseif Math.clamp(32, char, 254) == char then

    if self.selectionStart then self:deleteSelection() end

    self:insertChar(char)

  end
  self:setWindowToCaret()

  -- Make sure no functions crash because they got a type==number
  self.retval = tostring(self.retval)

  -- Reset the caret so the visual change isn't laggy
  self.blink = 0

end


function Textbox:onWheel(state)

  local len = string.len(self.retval)

  if len <= self.windowW then return end

  -- Scroll right/left
  local dir = state > 0 and 3 or -3
  self.windowPosition = Math.clamp(0, self.windowPosition + dir, len + 2 - self.windowW)

  self:redraw()

end




------------------------------------
-------- Drawing methods -----------
------------------------------------


function Textbox:drawCaption()

  local caption = self.caption

  Font.set(self.captionFont)

  local strWidth, strHeight = gfx.measurestr(caption)

  if self.captionPosition == "left" then
    gfx.x = self.x - strWidth - self.pad
    gfx.y = self.y + (self.h - strHeight) / 2

  elseif self.captionPosition == "top" then
    gfx.x = self.x + (self.w - strWidth) / 2
    gfx.y = self.y - strHeight - self.pad

  elseif self.captionPosition == "right" then
    gfx.x = self.x + self.w + self.pad
    gfx.y = self.y + (self.h - strHeight) / 2

  elseif self.captionPosition == "bottom" then
    gfx.x = self.x + (self.w - strWidth) / 2
    gfx.y = self.y + self.h + self.pad

  end

  Text.drawBackground(caption, self.bg)

  if self.shadow then
    Text.drawWithShadow(caption, self.color, "shadow")
  else
    Color.set(self.color)
    gfx.drawstr(caption)
  end

end


function Textbox:drawText()

	Color.set(self.color)
	Font.set(self.textFont)

  local str = string.sub(self.retval, self.windowPosition + 1)

  -- I don't think self.pad should affect the text at all. Looks weird,
  -- messes with the amount of visible text too much.
	gfx.x = self.x + 4 -- + self.pad
	gfx.y = self.y + (self.h - gfx.texth) / 2
  local r = gfx.x + self.w - 8 -- - 2*self.pad
  local b = gfx.y + gfx.texth

	gfx.drawstr(str, 0, r, b)

end


function Textbox:drawCaret()

  local caretRelative = self:adjustToWindow(self.caret)

  if caretRelative then

      Color.set("txt")

      local caretH = self.charH - 2

      gfx.rect(   self.x + (caretRelative * self.charW) + 4,
                  self.y + (self.h - caretH) / 2,
                  self.insertCaret and self.charW or 2,
                  caretH)

  end

end


function Textbox:drawSelection()

  Color.set("elmFill")
  gfx.a = 0.5
  gfx.mode = 1

  local s, e = self.selectionStart, self.selectionEnd

  if e < s then s, e = e, s end


  local x = Math.clamp(self.windowPosition, s, self:windowRight())
  local w = Math.clamp(x, e, self:windowRight()) - x

  if self:isSelectionVisible(x, w) then

    -- Convert from char-based coords to actual pixels
    x = self.x + (x - self.windowPosition) * self.charW + 4

    local h = self.charH - 2

    local y = self.y + (self.h - h) / 2

    w = w * self.charW
    w = math.min(w, self.x + self.w - x - self.pad)



    gfx.rect(x, y, w, h, true)

  end

  gfx.mode = 0

	-- Later calls to Color.set should handle this, but for
	-- some reason they aren't always.
  gfx.a = 1

end


function Textbox:drawGradient()

  local left = self.windowPosition > 0
  local right = self.windowPosition < (string.len(self.retval) - self.windowW + 2)
  if not (left or right) then return end

  local fadeW = 8

  Color.set("elmBg")

  local leftX = self.x + 2 + fadeW
  local rightX = self.x + self.w - 3 - fadeW
  for i = 0, fadeW do

    gfx.a = i/fadeW

    -- Left
    if left then
      gfx.line(leftX - i, self.y + 2, leftX - i, self.y + self.h - 4)
    end

    -- Right
    if right then
      gfx.line(rightX + i, self.y + 2, rightX + i, self.y + self.h - 4)
    end

  end

end




------------------------------------
-------- Selection methods ---------
------------------------------------


-- Make sure at least part of the selection is visible
function Textbox:isSelectionVisible(x, w)

	return w > 0                  -- Selection has width,
    and x + w > self.windowPosition    -- doesn't end to the left
    and x < self:windowRight()    -- and doesn't start to the right

end


function Textbox:selectAll()

  self.selectionStart = 0
  self.caret = 0
  self.selectionEnd = string.len(self.retval)

end


function Textbox:selectWord()

  local str = self.retval

  if not str or str == "" then return 0 end

  self.selectionStart = string.find( str:sub(1, self.caret), "%s[%S]+$") or 0
  self.selectionEnd = (      string.find( str, "%s", self.selectionStart + 1)
                  or  string.len(str) + 1)
              - (self.windowPosition > 0 and 2 or 1) -- Kludge, fixes length issues

end


function Textbox:deleteSelection()

  if not (self.selectionStart and self.selectionEnd) then return 0 end

  self:storeUndoState()

  local s, e = self.selectionStart, self.selectionEnd

  if s > e then s, e = e, s end

  self.retval =   string.sub(self.retval or "", 1, s)..
                  string.sub(self.retval or "", e + 1)

  self.caret = s

  self.selectionStart, self.selectionEnd = nil, nil
  self:setWindowToCaret()


end


function Textbox:getSelectedText()

  local s, e = self.selectionStart, self.selectionEnd

  if s > e then s, e = e, s end

  return string.sub(self.retval, s + 1, e)

end


Textbox.toClipboard = TextUtils.toClipboard
Textbox.fromClipboard = TextUtils.fromClipboard



------------------------------------
-------- Window/pos helpers --------
------------------------------------


function Textbox:recalculateWindow()

  Font.set(self.textFont)

  self.charW, self.charH = gfx.measurestr("i")
  self.windowW = math.floor(self.w / self.charW)

end


function Textbox:windowRight()

  return self.windowPosition + self.windowW

end


-- See if a given position is in the visible window
-- If so, adjust it from absolute to window-relative
-- If not, returns nil
function Textbox:adjustToWindow(x)

  return ( Math.clamp(self.windowPosition, x, self:windowRight() - 1) == x )
    and x - self.windowPosition
    or nil

end


function Textbox:setWindowToCaret()

  if self.caret < self.windowPosition + 1 then
    self.windowPosition = math.max(0, self.caret - 1)
  elseif self.caret > (self:windowRight() - 2) then
    self.windowPosition = self.caret + 2 - self.windowW
  end

end


function Textbox:getCaret(x)

  local caretX = math.floor(  ((x - self.x) / self.w) * self.windowW) + self.windowPosition
  return Math.clamp(0, caretX, string.len(self.retval or ""))

end




------------------------------------
-------- Char/string helpers -------
------------------------------------


function Textbox:insertString(str, moveCaret)

  self:storeUndoState()

  local sanitized = self:sanitizeText(str)

  if self.selectionStart then self:deleteSelection() end

  local pre, post =   string.sub(self.retval or "", 1, self.caret),
                      string.sub(self.retval or "", self.caret + 1)

  self.retval = pre .. tostring(sanitized) .. post

  if moveCaret then self.caret = self.caret + string.len(sanitized) end

end


function Textbox:insertChar(char)

  self:storeUndoState()

  local a, b = string.sub(self.retval, 1, self.caret),
               string.sub(self.retval, self.caret + (self.insertCaret and 2 or 1))

  self.retval = a..string.char(char)..b
  self.caret = self.caret + 1

end


function Textbox:carettoend()

  return string.len(self.retval or "")

end


-- Replace any characters that we're unable to reproduce properly
function Textbox:sanitizeText(str)

  return tostring(str):gsub("\t", "    "):gsub("[\n\r]", " ")

end

Textbox.doCtrlChar = TextUtils.doCtrlChar


-- Non-typing key commands
-- A table of functions is more efficient to access than using really
-- long if/then/else structures.
Textbox.keys = {

  [Const.char.LEFT] = function(self)

    self.caret = math.max( 0, self.caret - 1)

  end,

  [Const.char.RIGHT] = function(self)

    self.caret = math.min( string.len(self.retval), self.caret + 1 )

  end,

  [Const.char.UP] = function(self)

    self.caret = 0

  end,

  [Const.char.DOWN] = function(self)

    self.caret = string.len(self.retval)

  end,

  [Const.char.BACKSPACE] = function(self)

    self:storeUndoState()

    if self.selectionStart then

      self:deleteSelection()

    else

    if self.caret <= 0 then return end

      local str = self.retval
      self.retval =   string.sub(str, 1, self.caret - 1)..
                      string.sub(str, self.caret + 1, -1)
      self.caret = math.max(0, self.caret - 1)

    end

  end,

  [Const.char.INSERT] = function(self)

    self.insertCaret = not self.insertCaret

  end,

  [Const.char.DELETE] = function(self)

    self:storeUndoState()

    if self.selectionStart then

      self:deleteSelection()

    else

      local str = self.retval
      self.retval =   string.sub(str, 1, self.caret) ..
                      string.sub(str, self.caret + 2)

    end

  end,

  [Const.char.RETURN] = function(self)

    self.focus = false
    self:lostFocus()
    self:redraw()

  end,

  [Const.char.HOME] = function(self)

    self.caret = 0

  end,

  [Const.char.END] = function(self)

    self.caret = string.len(self.retval)

  end,

  [Const.char.TAB] = function(self)

    -- tab functionality has been temporarily removed because it was broken anyway
    -- GUI.tab_to_next(self)

  end,

	-- A -- Select All
	[1] = function(self, state)

		return self:doCtrlChar(state, self.selectAll)

	end,

	-- C -- Copy
	[3] = function(self, state)

		return self:doCtrlChar(state, self.toClipboard)

	end,

	-- V -- Paste
	[22] = function(self, state)

    return self:doCtrlChar(state, self.fromClipboard)

	end,

	-- X -- Cut
	[24] = function(self, state)

		return self:doCtrlChar(state, self.toClipboard, true)

	end,

	-- Y -- Redo
	[25] = function (self, state)

		return self:doCtrlChar(state, self.redo)

	end,

	-- Z -- Undo
	[26] = function (self, state)

		return self:doCtrlChar(state, self.undo)

	end


}




------------------------------------
-------- Misc. helpers -------------
------------------------------------


Textbox.undo = TextUtils.undo
Textbox.redo = TextUtils.redo

Textbox.storeUndoState = TextUtils.storeUndoState

function Textbox:getEditorState()

	return { retval = self.retval, caret = self.caret }

end

function Textbox:setEditorState(retval, caret, windowPosition, selectionStart, selectionEnd)

  self.retval = retval or ""
  self.caret = math.min(caret and caret or self.caret, string.len(self.retval))
  self.windowPosition = windowPosition or 0
  self.selectionStart, self.selectionEnd = selectionStart or nil, selectionEnd or nil

end

Textbox.SWS_clipboard = TextUtils.SWS_clipboard

return Textbox
