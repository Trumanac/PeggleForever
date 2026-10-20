-- Minimal fake World of Warcraft UI API so the addon can run outside the game.
-- Used by devtools/run.py (via lupa, Lua 5.1). Not loaded by WoW (no TOC entry).
local M = {}
M.time = 0
M.screen = { w = 1600, h = 900 }
M.mouse = { x = 800, y = 450, down = {} }
M.errors = {}      -- caught script errors { where=, msg= }
M.missing = {}     -- API methods that were called but are not implemented (name -> count)
M.sounds = {}      -- PlaySoundFile calls
M.printed = {}     -- print()/chat output
M.frames = {}      -- every frame in creation order
M.named = {}       -- name -> frame
M.timers = {}
local order = 0

local STRATA = { WORLD = 1, BACKGROUND = 2, LOW = 3, MEDIUM = 4, HIGH = 5, DIALOG = 6, FULLSCREEN = 7, FULLSCREEN_DIALOG = 8, TOOLTIP = 9 }
local LAYER = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }

local Obj = {}
local ObjMT

local function newObj(kind, name, parent, isFrame)
	if name == "" then name = nil end
	order = order + 1
	local o = setmetatable({}, ObjMT)
	rawset(o, "_kind", kind)
	rawset(o, "_name", name)
	rawset(o, "_parent", parent)
	rawset(o, "_isFrame", isFrame)
	rawset(o, "_order", order)
	rawset(o, "_shown", true)
	rawset(o, "_alpha", 1)
	rawset(o, "_points", {})
	rawset(o, "_scripts", {})
	rawset(o, "_events", {})
	rawset(o, "_children", {})
	rawset(o, "_regions", {})
	rawset(o, "_data", {})
	if name then
		M.named[name] = o
		_G[name] = o
	end
	return o
end

local function stubMethod(key)
	return function(self, ...)
		M.missing[key] = (M.missing[key] or 0) + 1
		return nil
	end
end

local ZERO_GETTERS = { Width = true, Height = true, Left = true, Right = true, Top = true, Bottom = true, Scale = true,
	EffectiveScale = true, Alpha = true, FrameLevel = true, ID = true, NumPoints = true, Value = true, MinValue = true, MaxValue = true,
	NumLines = true, StringWidth = true, StringHeight = true, TextWidth = true, TextHeight = true }

ObjMT = {
	__index = function(self, key)
		local v = Obj[key]
		if v ~= nil then return v end
		if type(key) == "string" then
			if key:sub(1, 1) == "_" then return nil end
			local s = key:sub(1, 3)
			if s == "Set" and #key > 3 then
				local field = "_" .. key:sub(4)
				M.missing[key] = (M.missing[key] or 0) + 1
				return function(me, ...)
					rawset(me, field, { ... })
				end
			elseif s == "Get" and #key > 3 then
				local field = "_" .. key:sub(4)
				local base = key:sub(4)
				return function(me)
					local st = rawget(me, field)
					if st then return unpack(st) end
					if ZERO_GETTERS[base] then return 1 end
					return nil
				end
			end
		end
		-- Only PascalCase names are treated as (missing) API methods; anything else is a plain nil field.
		if type(key) == "string" and key:match("^[A-Z]") then
			return stubMethod(key)
		end
		return nil
	end,
}

---------------------------------------------------------------- generic object methods
-- PlayerModel basics: SetCreature remembers the NPC; its display ID is 9000 + NPC ID once set (like a loaded model)
function Obj:SetCreature(id) self._creature = id end
function Obj:ClearModel() self._creature = nil end
function Obj:SetPortraitZoom(z) self._pzoom = z end
function Obj:SetFacing(f) self._facing = f end
function Obj:GetModelFileID() return self._creature and 1 or 0 end
function Obj:GetDisplayInfo() return self._creature and (9000 + self._creature) or nil end
function Obj:GetName() return self._name end
function Obj:GetObjectType() return self._kind end
function Obj:IsObjectType(t) return self._kind == t or (t == "Frame" and self._isFrame) or (t == "Region") end
function Obj:GetParent() return self._parent end
function Obj:SetParent(p)
	self._parent = p
end
function Obj:SetID(id) self._id = id end
function Obj:GetID() return self._id or 0 end

-- visibility
function Obj:Show()
	if self._shown then return end
	self._shown = true
	if self:IsVisible() then M.runShow(self) end
end
function Obj:Hide()
	if not self._shown then return end
	local wasVisible = self:IsVisible()
	self._shown = false
	if wasVisible then M.runHide(self) end
end
function Obj:SetShown(s) if s then self:Show() else self:Hide() end end
function Obj:IsShown() return self._shown end
function Obj:IsVisible()
	local o = self
	while o do
		if not o._shown then return false end
		o = o._parent
	end
	return true
end
function M.runShow(o)
	local f = o._scripts.OnShow
	if f then M.call(f, "OnShow " .. (o._name or o._kind), o) end
	for _, c in ipairs(o._children) do
		if c._shown then M.runShow(c) end
	end
end
function M.runHide(o)
	local f = o._scripts.OnHide
	if f then M.call(f, "OnHide " .. (o._name or o._kind), o) end
	for _, c in ipairs(o._children) do
		if c._shown then M.runHide(c) end
	end
end

function Obj:SetAlpha(a) self._alpha = a end
function Obj:GetAlpha() return self._alpha end
function Obj:GetEffectiveAlpha()
	local a, o = 1, self
	while o do a = a * o._alpha; o = o._parent end
	return a
end
function Obj:SetScale(s) self._scale = s end
function Obj:GetScale() return self._scale or 1 end
function Obj:GetEffectiveScale() return 1 end

-- size / anchors
function Obj:SetWidth(w) self._w = w end
function Obj:SetHeight(h) self._h = h end
function Obj:SetSize(w, h) self._w = w; self._h = h end
function Obj:ClearAllPoints() self._points = {}; self._allpoints = nil end
function Obj:SetAllPoints(rel) self._allpoints = rel or self._parent or true end
function Obj:SetPoint(point, rel, relPoint, x, y)
	if type(rel) == "number" then
		x, y = rel, relPoint; rel = nil; relPoint = nil
	elseif type(relPoint) == "number" then
		x, y = relPoint, x; relPoint = nil
	end
	if type(rel) == "string" then rel = _G[rel] end
	point = string.upper(point)
	self._points[#self._points + 1] = { point = point, rel = rel, relPoint = relPoint and string.upper(relPoint) or point, x = x or 0, y = y or 0 }
end
function Obj:GetNumPoints() return #self._points end

local function hAnchor(p)
	if p:find("LEFT") then return "L" elseif p:find("RIGHT") then return "R" else return "C" end
end
local function vAnchor(p)
	if p:find("TOP") then return "T" elseif p:find("BOTTOM") then return "B" else return "C" end
end

-- Returns left, bottom, right, top in screen coordinates (y up).
local function layout(o)
	if o == UIParent then return 0, 0, M.screen.w, M.screen.h end
	local cached = rawget(o, "_lay")
	if cached then return cached[1], cached[2], cached[3], cached[4] end
	local parent = o._parent or UIParent
	local L, R, T, B, CX, CY
	if o._allpoints then
		local rel = (o._allpoints == true) and parent or o._allpoints
		L, B, R, T = layout(rel)
	end
	for _, pt in ipairs(o._points) do
		local rel = pt.rel or parent
		local rl, rb, rr, rt = layout(rel)
		local ha, va = hAnchor(pt.relPoint), vAnchor(pt.relPoint)
		local ax = (ha == "L" and rl) or (ha == "R" and rr) or (rl + rr) / 2
		local ay = (va == "T" and rt) or (va == "B" and rb) or (rb + rt) / 2
		ax, ay = ax + pt.x, ay + pt.y
		local sh, sv = hAnchor(pt.point), vAnchor(pt.point)
		if sh == "L" then L = ax elseif sh == "R" then R = ax else CX = ax end
		if sv == "T" then T = ay elseif sv == "B" then B = ay else CY = ay end
	end
	local w, h = o._w, o._h
	if o._kind == "FontString" then
		if not w and o._text then
			local size = (o._font and o._font[2]) or 12
			w = #tostring(o._text) * size * 0.52
		end
		h = h or ((o._font and o._font[2]) or 12) * 1.2
	end
	local function resolve(lo, hi, cen, size)
		if lo and hi then return lo, hi end
		size = size or 0
		if lo then return lo, lo + size end
		if hi then return hi - size, hi end
		if cen then return cen - size / 2, cen + size / 2 end
		return nil
	end
	local x1, x2 = resolve(L, R, CX, w)
	local y1, y2 = resolve(B, T, CY, h)
	if not x1 then
		local pl, _, pr = layout(parent)
		x1, x2 = pl, pl + (w or 0)
	end
	if not y1 then
		local _, pb, _, pt2 = layout(parent)
		y1, y2 = pt2 - (h or 0), pt2
	end
	if parent._scrollChild == o and parent._vscroll then
		y1, y2 = y1 + parent._vscroll, y2 + parent._vscroll
	end
	o._lay = { x1, y1, x2, y2 }
	return x1, y1, x2, y2
end
M.layout = layout
function M.invalidate()
	for _, f in ipairs(M.frames) do rawset(f, "_lay", nil) end
	for _, f in ipairs(M.allRegions or {}) do rawset(f, "_lay", nil) end
end

function Obj:GetWidth() local l, b, r, t = layout(self); return r - l end
function Obj:GetHeight() local l, b, r, t = layout(self); return t - b end
function Obj:GetSize() return self:GetWidth(), self:GetHeight() end
function Obj:GetLeft() local l = layout(self); return l end
function Obj:GetBottom() local _, b = layout(self); return b end
function Obj:GetRight() local _, _, r = layout(self); return r end
function Obj:GetTop() local _, _, _, t = layout(self); return t end
function Obj:GetCenter() local l, b, r, t = layout(self); return (l + r) / 2, (b + t) / 2 end
function Obj:GetRect() local l, b, r, t = layout(self); return l, b, r - l, t - b end
function Obj:IsMouseOver()
	local l, b, r, t = layout(self)
	return M.mouse.x >= l and M.mouse.x <= r and M.mouse.y >= b and M.mouse.y <= t
end
function Obj:SetHitRectInsets() end
function Obj:EnableMouseWheel() end
function Obj:SetClipsChildren(v) self._clips = v and true or nil end
function Obj:SetShadowColor() end
function Obj:SetShadowOffset() end
function Obj:SetValueStep() end
function Obj:SetVerticalScroll(v) self._vscroll = v or 0; M.invalidate() end
function Obj:DisableDrawLayer() end
function Obj:SetResizeBounds() end
function Obj:SetMaxBytes() end
function Obj:EnableMouse(b) self._mouse = b end
function Obj:IsMouseEnabled() return self._mouse end

-- frames
function Obj:SetFrameStrata(s) self._strata = s end
function Obj:GetFrameStrata() return self._strata or (self._parent and self._parent:GetFrameStrata()) or "MEDIUM" end
function Obj:GetFrameLevel() return self._level or 1 end
function Obj:SetFrameLevel(l)
	local old = self._level or 1
	self._level = l
	local delta = l - old
	if delta ~= 0 then
		for _, c in ipairs(self._children) do
			c:SetFrameLevel((c._level or 1) + delta)
		end
	end
end
function Obj:Raise() end
function Obj:SetToplevel() end
function Obj:SetMovable() end
function Obj:SetClampedToScreen() end
function Obj:RegisterForDrag() end
function Obj:SetResizable() end

function Obj:SetScript(name, fn) self._scripts[name] = fn end
function Obj:GetScript(name) return self._scripts[name] end
function Obj:HasScript() return true end
function Obj:HookScript(name, fn)
	local old = self._scripts[name]
	if old then
		self._scripts[name] = function(...) old(...); fn(...) end
	else
		self._scripts[name] = fn
	end
end
function Obj:RegisterEvent(e) self._events[e] = true end
function Obj:UnregisterEvent(e) self._events[e] = nil end
function Obj:UnregisterAllEvents() self._events = {} end
function Obj:IsEventRegistered(e) return self._events[e] and true or false end

function Obj:CreateTexture(name, layer)
	local t = newObj("Texture", name, self, false)
	t._layer = layer or "ARTWORK"
	self._regions[#self._regions + 1] = t
	M.allRegions[#M.allRegions + 1] = t
	return t
end
function Obj:CreateFontString(name, layer, template)
	local f = newObj("FontString", name, self, false)
	f._layer = layer or "OVERLAY"
	f._template = template
	f._font = { nil, M.templateFontSize(template) }
	self._regions[#self._regions + 1] = f
	M.allRegions[#M.allRegions + 1] = f
	return f
end
function M.templateFontSize(t)
	if not t then return 12 end
	if t:find("Huge") then return 24 elseif t:find("Large") then return 16 elseif t:find("Small") then return 10 end
	return 12
end

-- textures
function Obj:SetTexture(a, b, c, d)
	if type(a) == "number" and b then
		self._color = { a, b, c, d or 1 }
		self._tex = nil
	else
		self._tex = a
		self._color = nil
	end
end
function Obj:GetTexture() return self._tex end
function Obj:SetColorTexture(r, g, b, a) self._color = { r, g, b, a or 1 }; self._tex = nil end
function Obj:SetTexCoord(...) self._coord = { ... } end
function Obj:SetVertexColor(r, g, b, a) self._vcolor = { r, g, b, a or 1 } end
function Obj:SetBlendMode(m) self._blend = m end
function Obj:SetDesaturated(d) self._desat = d end
function Obj:SetAtlas(a) self._atlas = a end
function Obj:SetGradient() end

function Obj:CreateMaskTexture(name)
	local t = newObj("Texture", name, self, false)
	t._layer = "ARTWORK"
	t._isMask = true
	return t
end
function Obj:AddMaskTexture(mask) self._masked = true end

-- font strings
function Obj:SetText(t)
	self._text = t
	if self._kind == "Button" or self._kind == "CheckButton" then
		local fs = self._data.fs
		if fs then fs:SetText(t) end
	end
end
function Obj:GetText() if self._text == nil and self._kind == "EditBox" then return "" end return self._text end
function Obj:SetFormattedText(fmt, ...) self._text = string.format(fmt, ...) end
function Obj:SetDrawLayer(layer) self._layer = layer end
function Obj:SetFont(path, size, flags) self._font = { path, size, flags } end
function Obj:SetFontObject(o) end
function Obj:SetTextColor(r, g, b, a) self._tcolor = { r, g, b, a or 1 } end
function Obj:SetJustifyH(j) self._justH = j end
function Obj:SetJustifyV(j) self._justV = j end
function Obj:GetStringWidth()
	local size = (self._font and self._font[2]) or 12
	return #tostring(self._text or "") * size * 0.52
end
function Obj:GetStringHeight() return ((self._font and self._font[2]) or 12) * 1.2 end

-- backdrop
function Obj:SetBackdrop(b) self._backdrop = b end
function Obj:GetBackdrop() return self._backdrop end
function Obj:SetBackdropColor(r, g, b, a) self._bdColor = { r, g, b, a or 1 } end
function Obj:SetBackdropBorderColor(r, g, b, a) self._bdBorder = { r, g, b, a or 1 } end

-- buttons
function Obj:Enable() self._enabled = true end
function Obj:Disable() self._enabled = false end
function Obj:IsEnabled() return self._enabled ~= false end
function Obj:RegisterForClicks() end
local function lazyTex(slot)
	return function(self)
		local key = "_tex_" .. slot
		local t = rawget(self, key)
		if not t then
			t = self:CreateTexture(nil, "ARTWORK")
			t:SetAllPoints(self)
			rawset(self, key, t)
		end
		return t
	end
end
Obj.GetNormalTexture = lazyTex("normal")
Obj.GetPushedTexture = lazyTex("pushed")
Obj.GetHighlightTexture = lazyTex("highlight")
Obj.GetDisabledTexture = lazyTex("disabled")
Obj.GetCheckedTexture = lazyTex("checked")
function Obj:SetNormalTexture() end
function Obj:GetFontString() return self._data.fs end
function Obj:SetChecked(c) self._checked = c end
function Obj:GetChecked() return self._checked end
function Obj:SetValue(v)
	if self._min and v < self._min then v = self._min end
	if self._max and v > self._max then v = self._max end
	local old = self._value
	self._value = v
	if old ~= v then
		local fn = self._scripts.OnValueChanged
		if fn then fn(self, v) end
	end
end
function Obj:GetValue() return self._value or 0 end
function Obj:SetMinMaxValues(a, b) self._min = a; self._max = b end
function Obj:GetMinMaxValues() return self._min or 0, self._max or 0 end
function Obj:SetNumeric() end
function Obj:SetAutoFocus() end
function Obj:SetFocus() end
function Obj:ClearFocus() end
function Obj:SetMaxLetters() end
function Obj:GetChildren()
	local out = {}
	for _, c in ipairs(self._children) do out[#out + 1] = c end
	return unpack(out)
end
function Obj:GetRegions()
	local out = {}
	for _, c in ipairs(self._regions) do out[#out + 1] = c end
	return unpack(out)
end

-- scroll frames
function Obj:SetScrollChild(c) self._scrollChild = c end
function Obj:GetScrollChild() return self._scrollChild end

-- tooltips
function Obj:SetOwner() end
function Obj:AddLine() end
function Obj:AddDoubleLine() end
function Obj:SetHyperlink() end

-- animation groups (just enough not to crash)
function Obj:CreateAnimationGroup() return newObj("AnimationGroup", nil, self, false) end
function Obj:CreateAnimation() return newObj("Animation", nil, self, false) end
function Obj:Play() end
function Obj:Stop() end

---------------------------------------------------------------- frame creation
M.allRegions = {}
local CHILD_FS = { Text = true, Low = true, High = true, Label = true, Count = true, Name = true, Value = true }
local CHILD_TEX = { ThumbTexture = true, Icon = true, Border = true, Left = true, Right = true, Middle = true, NormalTexture = true,
	PushedTexture = true, HighlightTexture = true, Background = true, Flash = true, Cooldown = true }

function CreateFrame(kind, name, parent, template)
	parent = parent or UIParent
	local f = newObj(kind, name, parent, true)
	f._level = (parent._level or 1) + 1
	f._template = template
	if kind == "ScrollFrame" then f._clips = true end
	parent._children[#parent._children + 1] = f
	M.frames[#M.frames + 1] = f
	if kind == "Button" or kind == "CheckButton" then
		local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		fs:SetPoint("CENTER")
		f._data.fs = fs
	end
	if template then
		if template:find("AchievementAlertFrame") then
			for _, k in ipairs({ "glow", "shine", "Background", "Icon" }) do rawset(f, k, f:CreateTexture()) end
			for _, k in ipairs({ "Name", "Unlocked" }) do rawset(f, k, f:CreateFontString()) end
			local shield = CreateFrame("Frame", nil, f)
			rawset(shield, "Icon", shield:CreateTexture()); rawset(shield, "Points", shield:CreateFontString())
			rawset(f, "Shield", shield)
		end
		if template:find("UIPanelButtonTemplate") then
			f:SetHeight(f._h or 22)
		end
	end
	return f
end

-- Auto-create template children referenced via globals like getglobal(name.."Text").
setmetatable(_G, {
	__index = function(t, k)
		if type(k) == "string" then
			for fname, f in pairs(M.named) do
				if #k > #fname and k:sub(1, #fname) == fname then
					local suffix = k:sub(#fname + 1)
					if suffix:match("^[A-Z][%w]*$") then
						local child
						if CHILD_FS[suffix] then
							child = f:CreateFontString(k)
						elseif CHILD_TEX[suffix] then
							child = f:CreateTexture(k)
						else
							child = CreateFrame("Button", k, f)
						end
						rawset(f, suffix, child)
						return child
					end
				end
			end
		end
		return nil
	end,
})

---------------------------------------------------------------- script calling / event driving
function M.call(fn, where, ...)
	-- Lua 5.1's xpcall cannot forward arguments, so close over them.
	local n, args = select("#", ...), { ... }
	local ok, err = xpcall(function() return fn(unpack(args, 1, n)) end, function(e) return tostring(e) .. "\n" .. debug.traceback("", 2) end)
	if not ok then
		M.errors[#M.errors + 1] = { where = where, msg = err }
	end
	return ok
end

function M.fire(event, ...)
	for _, f in ipairs(M.frames) do
		if f._events[event] then
			local fn = f._scripts.OnEvent
			if fn then M.call(fn, "OnEvent " .. event .. " " .. (f._name or f._kind), f, event, ...) end
		end
	end
end

function M.advance(dt)
	M.time = M.time + dt
	-- timers
	local due = {}
	for i = #M.timers, 1, -1 do
		local t = M.timers[i]
		if t.at <= M.time then
			table.remove(M.timers, i)
			due[#due + 1] = t
		end
	end
	table.sort(due, function(a, b) return a.at < b.at end)
	for _, t in ipairs(due) do
		if not t.cancelled then
			M.call(t.fn, "timer", t)
			if t.interval and not t.cancelled then
				t.at = M.time + t.interval
				M.timers[#M.timers + 1] = t
			end
		end
	end
	for _, f in ipairs(M.frames) do
		local fn = f._scripts.OnUpdate
		if fn and f:IsVisible() then
			M.call(fn, "OnUpdate " .. (f._name or f._kind), f, dt)
		end
	end
end

-- Finds the first frame whose own text (or button label) equals `text`.
function M.findByText(text, visibleOnly)
	for _, f in ipairs(M.frames) do
		if f._text == text and (not visibleOnly or f:IsVisible()) then return f end
		local fs = f._data and f._data.fs
		if fs and fs._text == text and (not visibleOnly or f:IsVisible()) then return f end
	end
	-- also match font strings and return their owning frame
	for _, r in ipairs(M.allRegions) do
		if r._kind == "FontString" and r._text == text and (not visibleOnly or r._parent:IsVisible()) then return r._parent end
	end
end

function M.hover(frame)
	local fn = frame._scripts.OnEnter
	if fn then M.call(fn, "OnEnter", frame) end
end
function M.unhover(frame)
	local fn = frame._scripts.OnLeave
	if fn then M.call(fn, "OnLeave", frame) end
end

function M.click(frame, button)
	button = button or "LeftButton"
	M.hover(frame)
	local l, b, r, t = layout(frame)
	M.mouse.x, M.mouse.y = (l + r) / 2, (b + t) / 2
	local down = frame._scripts.OnMouseDown
	if down then M.call(down, "OnMouseDown", frame, button) end
	local up = frame._scripts.OnMouseUp
	if up then M.call(up, "OnMouseUp", frame, button) end
	local fn = frame._scripts.OnClick
	if fn then M.call(fn, "OnClick " .. (frame._name or "?"), frame, button) end
	M.unhover(frame)
end

function M.setMouse(x, y) M.mouse.x, M.mouse.y = x, y end

---------------------------------------------------------------- global API
UIParent = newObj("Frame", "UIParent", nil, true)
UIParent._level = 0
UIParent._strata = "MEDIUM"
M.frames[#M.frames + 1] = UIParent
WorldFrame = newObj("Frame", "WorldFrame", nil, true)
Minimap = CreateFrame("Frame", "Minimap", UIParent)
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
ChatFrame1 = CreateFrame("Frame", "ChatFrame1", UIParent)
DEFAULT_CHAT_FRAME = ChatFrame1
function ChatFrame1:AddMessage(msg) M.printed[#M.printed + 1] = tostring(msg) end

function GetTime() return M.time end
function GetCursorPosition() return M.mouse.x, M.mouse.y end
function IsMouseButtonDown(b) return M.mouse.down[b or "LeftButton"] and true or false end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end
function GetScreenWidth() return M.screen.w end
function GetScreenHeight() return M.screen.h end
function GetFramerate() return 60 end
function GetCVar() return "1" end
function SetCVar() end
function GetLocale() return "enUS" end
function GetRealmName() return "TestRealm" end
function GetNormalizedRealmName() return "TestRealm" end
NONE = "None"
M.playerName = "Tester"
function UnitName() return M.playerName end
function UnitFullName() return M.playerName, "TestRealm" end
function UnitClass() return "Warrior", "WARRIOR" end
function UnitFactionGroup() return "Alliance", "Alliance" end
function UnitOnTaxi() return false end
function UnitIsAFK() return false end
function UnitAffectingCombat() return false end
function InCombatLockdown() return false end
function IsInGroup() return false end
function IsInRaid() return false end
function IsInGuild() return false end
function GetNumGroupMembers() return 0 end
function GetGuildInfo() return nil end
function GetNumGuildMembers() return 0 end
function GetChannelList() return end
function EnumerateServerChannels() return end
function GetGuildRosterShowOffline() return false end
function SetGuildRosterShowOffline() end
function GuildRoster() end
function GetGuildRosterInfo() return nil end
function GetNumFriends() return 0 end
function GetFriendInfo() return nil end
function GetNumRaidMembers() return 0 end
function GetNumPartyMembers() return 0 end
function GetRaidRosterInfo() return nil end
function UnitIsConnected() return true end
function UnitExists() return false end
function UnitIsPlayer() return false end
function UnitGUID() return "Player-1-00000001" end
function UnitLevel() return 60 end
function UnitRace() return "Human", "Human" end
function UnitSex() return 2 end
function GetServerTime() return 1760800000 end
function IsInInstance() return false, "none" end
function IsResting() return false end
function GetItemInfo() return nil end
function GetMouseFocus() return nil end
function GetMouseFoci() return {} end
function EasyMenu() end
function GetBuildInfo() return "1.60.1", "70450", "Oct 1 2026", 16001 end
function PlaySound(id, channel) M.sounds[#M.sounds + 1] = "kit:" .. tostring(id) end
function PlaySoundFile(path, channel) M.sounds[#M.sounds + 1] = path end
function StopSound() end
function hooksecurefunc(a, b, c)
	local tbl, name, fn = _G, a, b
	if type(a) == "table" then tbl, name, fn = a, b, c end
	local orig = tbl[name]
	tbl[name] = function(...)
		local r = orig and { orig(...) } or {}
		fn(...)
		return unpack(r)
	end
end
function ChatFrame_AddMessageEventFilter() end
function GetAddOnMetadata(name, field) return field == "Version" and "2.4.2" or nil end
function UIParentLoadAddOn() end
function IsAddOnLoaded(name) return name ~= "Peggle" or M.originalPeggle == true end -- M.originalPeggle: pretend the original add-on is installed
function LoadAddOn() return true end
function SendChatMessage() end
function GetChannelName() return 0 end
function JoinTemporaryChannel() end
function IsLoggedIn() return true end
function GetServerTime() return 1760800000 end
function RegisterAddonMessagePrefix() return true end
function CopyToClipboard() end
function Tooltip_Show() end
function Tooltip_Hide() end
function GameTooltip_Hide() end
function ToggleDropDownMenu() end
function CloseDropDownMenus() end
function UIDropDownMenu_Initialize() end
function UIDropDownMenu_SetWidth() end
function UIDropDownMenu_SetText() end
function UIDropDownMenu_SetSelectedValue() end
function UIDropDownMenu_SetSelectedName() end
function UIDropDownMenu_AddButton() end
function UIDropDownMenu_SetAnchor() end
function UIDropDownMenu_GetCurrentDropDown() return nil end
function UIDropDownMenu_CreateInfo() return {} end
function CreateFont(name) local f = newObj("Font", name, nil, false); return f end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
function Mixin(t, ...) for _, m in ipairs({ ... }) do for k, v in pairs(m) do t[k] = v end end return t end
function CreateFromMixins(...) return Mixin({}, ...) end
function SecondsToTime(s) return tostring(s) .. "s" end
function GetCoinTextureString(c) return tostring(c) end
function BreakUpLargeNumbers(n) return tostring(n) end
function FormatLargeNumber(n) return tostring(n) end
function geterrorhandler() return function(e) M.errors[#M.errors + 1] = { where = "errorhandler", msg = tostring(e) } end end
function seterrorhandler() end
function issecurevariable() return false end
function InterfaceOptions_AddCategory() end

BackdropTemplateMixin = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 }
NORMAL_FONT_COLOR = { r = 1, g = .82, b = 0 }
TOOLTIP_TALENT_LEARN = "Click to learn"
TOOLTIP_TALENT_NEXT_RANK = "Next rank:"
ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."
WOW_PROJECT_ID = 2
WOW_PROJECT_MAINLINE = 1
WOW_PROJECT_CLASSIC = 2
SlashCmdList = {}
LE_PARTY_CATEGORY_HOME = 1

C_Timer = {
	After = function(sec, fn) M.timers[#M.timers + 1] = { at = M.time + sec, fn = fn } end,
	NewTimer = function(sec, fn)
		local t = { at = M.time + sec, fn = fn }
		t.Cancel = function() t.cancelled = true end
		M.timers[#M.timers + 1] = t
		return t
	end,
	NewTicker = function(sec, fn)
		local t = { at = M.time + sec, fn = fn, interval = sec }
		t.Cancel = function() t.cancelled = true end
		M.timers[#M.timers + 1] = t
		return t
	end,
}
C_AddOns = { GetAddOnMetadata = function(n, f) return f == "Version" and "2.4.2" or nil end, IsAddOnLoaded = function(name) return IsAddOnLoaded(name) end }
C_DateAndTime = {
	GetCurrentCalendarTime = function() return { weekday = 1, month = 10, monthDay = 18, year = 2026, hour = 12, minute = 0 } end,
	GetTodaysDate = function() return { weekDay = 1, month = 10, day = 18, year = 2026 } end,
}
M.addonOut = {}   -- addon messages the addon sent: {prefix, message, channel, target}
C_ChatInfo = { SendAddonMessage = function(prefix, msg, chan, target) M.addonOut[#M.addonOut + 1] = { prefix, msg, chan, target } end, RegisterAddonMessagePrefix = function() return true end, InChatMessagingLockdown = function() return false end }
C_FriendList = { GetNumFriends = function() return 0 end, GetFriendInfoByIndex = function() return nil end }
C_Texture = { GetAtlasInfo = function(a) return nil end }
C_PartyInfo = {}
C_GuildInfo = {}
C_BattleNet = {}
C_Map = {}

function GetGameTime() return 12, 0 end
function date(f, t) return os.date(f, t) end

-- WoW's Lua extras
strsplit = function(delim, str, pieces)
	local out, start = {}, 1
	while true do
		local s, e = string.find(str, delim, start, true)
		if not s or (pieces and #out >= pieces - 1) then break end
		out[#out + 1] = str:sub(start, s - 1); start = e + 1
	end
	out[#out + 1] = str:sub(start)
	return unpack(out)
end
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
tinsert, tremove = table.insert, table.remove
table.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
string.split = function(d, s, n) return strsplit(d, s, n) end
string.trim = function(s) return strtrim(s) end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
floor, ceil, abs, max, min, sqrt, sin, cos, rad, deg, random = math.floor, math.ceil, math.abs, math.max, math.min, math.sqrt, math.sin, math.cos, math.rad, math.deg, math.random
format, gsub, strfind, strlen, strlower, strupper, strsub, strmatch, strbyte, strchar, strrep = string.format, string.gsub, string.find, string.len, string.lower, string.upper, string.sub, string.match, string.byte, string.char, string.rep
for _, fname in ipairs({ "acos", "asin", "atan", "atan2", "exp", "frexp", "ldexp", "log", "log10", "tan", "cosh", "sinh", "tanh", "pow" }) do
	if math[fname] and not _G[fname] then _G[fname] = math[fname] end
end
-- WoW overrides the trig globals to work in DEGREES (the addon relies on this: atan2 returns degrees).
do
	local r, d = math.rad, math.deg
	atan = function(x) return d(math.atan(x)) end
	atan2 = function(y, x) return d(math.atan2 and math.atan2(y, x) or math.atan(y, x)) end
	asin = function(x) return d(math.asin(x)) end
	acos = function(x) return d(math.acos(x)) end
	sin = function(x) return math.sin(r(x)) end
	cos = function(x) return math.cos(r(x)) end
	tan = function(x) return math.tan(r(x)) end
end
getn = table.getn or function(t) return #t end
mod = math.fmod
time = os.time
bit = bit or {
	band = function(a, b) local r, p = 0, 1; while a > 0 and b > 0 do if a % 2 == 1 and b % 2 == 1 then r = r + p end a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2 end return r end,
	bor = function(a, b) local r, p = 0, 1; while a > 0 or b > 0 do if a % 2 == 1 or b % 2 == 1 then r = r + p end a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2 end return r end,
	bxor = function(a, b) local r, p = 0, 1; while a > 0 or b > 0 do if (a % 2) ~= (b % 2) then r = r + p end a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2 end return r end,
	lshift = function(a, n) return a * 2 ^ n end,
	rshift = function(a, n) return math.floor(a / 2 ^ n) end,
}
function print(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	M.printed[#M.printed + 1] = table.concat(parts, " ")
end

---------------------------------------------------------------- addon loading
-- Loads the TOC's Lua files (skipping Libs) into one shared config table.
function M.loadAddon(root, addonName)
	local config = {}
	M.config = config
	-- libs: real LibStub/CallbackHandler/LibDataBroker, fake LibDBIcon
	for _, rel in ipairs({ "Libs/LibStub/LibStub.lua", "Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua", "Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua" }) do
		local fn = assert(loadfile(root .. "/" .. rel))
		fn(addonName, config)
	end
	local DBIcon = LibStub:NewLibrary("LibDBIcon-1.0", 1)
	function DBIcon:Register() end
	local toc = assert(io.open(root .. "/" .. addonName .. ".toc", "r"))
	local files = {}
	for line in toc:lines() do
		line = line:gsub("\r", "")
		if line:match("%.lua$") and not line:match("^#") and not line:match("^Libs") then
			files[#files + 1] = line:gsub("\\", "/")
		end
	end
	toc:close()
	for _, rel in ipairs(files) do
		local fn, err = loadfile(root .. "/" .. rel)
		if not fn then error(err) end
		local ok, e = xpcall(function() fn(addonName, config) end, function(m) return tostring(m) .. "\n" .. debug.traceback("", 2) end)
		if not ok then
			M.errors[#M.errors + 1] = { where = "load " .. rel, msg = e }
		end
	end
	return files
end

-- Fire the events the client sends after loading an addon.
function M.login(addonName)
	M.fire("ADDON_LOADED", addonName)
	M.fire("VARIABLES_LOADED")
	M.fire("PLAYER_LOGIN")
	M.fire("PLAYER_ENTERING_WORLD", true, false)
end

---------------------------------------------------------------- render list
-- Returns a flat list of draw items sorted back-to-front for the Python renderer.
function M.renderList()
	local items = {}
	local function eff(o)
		local a, p = 1, o
		while p do a = a * (p._alpha or 1); p = p._parent end
		return a
	end
	local function strataIdx(f) return STRATA[f:GetFrameStrata()] or 4 end
	local function clipOf(f)
		local cl, cb, cr, ct
		local p = f._parent
		while p do
			if p._clips then
				local l, b, r, t = layout(p)
				if not cl then cl, cb, cr, ct = l, b, r, t
				else cl, cb, cr, ct = math.max(cl, l), math.max(cb, b), math.min(cr, r), math.min(ct, t) end
			end
			p = p._parent
		end
		return cl, cb, cr, ct
	end
	local function emitFrame(f)
		if not f:IsVisible() then return end
		local l, b, r, t = layout(f)
		local ccl, ccb, ccr, cct = clipOf(f)
		local key1, key2 = strataIdx(f), f._level or 1
		local alpha = eff(f)
		if f._backdrop then
			items[#items + 1] = { kind = "backdrop", ccl = ccl, ccb = ccb, ccr = ccr, cct = cct, l = l, b = b, r = r, t = t, bd = f._backdrop, color = f._bdColor, border = f._bdBorder, a = alpha, k1 = key1, k2 = key2, k3 = 0, ord = f._order, name = f._name }
		end
		for _, reg in ipairs(f._regions) do
			if reg._shown then
				local rl, rb, rr, rt = layout(reg)
				local layer = LAYER[reg._layer] or 3
				local it = { l = rl, b = rb, r = rr, t = rt, a = alpha * (reg._alpha or 1), k1 = key1, k2 = key2, k3 = layer, ord = reg._order, name = reg._name, ccl = ccl, ccb = ccb, ccr = ccr, cct = cct }
				if reg._kind == "Texture" then
					it.kind = "tex"; it.rot = reg._Rotation and reg._Rotation[1] or 0; it.path = reg._tex; it.color = reg._color; it.coord = reg._coord; it.vcolor = reg._vcolor
					it.masked = reg._masked; it.blend = reg._blend; it.desat = reg._desat; it.atlas = reg._atlas
					if it.path or it.color or it.atlas then items[#items + 1] = it end
				else
					it.kind = "text"; it.text = reg._text; it.size = reg._font and reg._font[2] or 12; it.font = reg._font and reg._font[1]
					it.color = reg._tcolor; it.justH = reg._justH; it.w = reg._w
					if it.text and it.text ~= "" then items[#items + 1] = it end
				end
			end
		end
	end
	for _, f in ipairs(M.frames) do emitFrame(f) end
	table.sort(items, function(a, b)
		if a.k1 ~= b.k1 then return a.k1 < b.k1 end
		if a.k2 ~= b.k2 then return a.k2 < b.k2 end
		if a.k3 ~= b.k3 then return a.k3 < b.k3 end
		return a.ord < b.ord
	end)
	return items
end

GROUP = GROUP or "Group" -- Blizzard global string
UISpecialFrames = UISpecialFrames or {}
M.screenshots = 0
function Screenshot() M.screenshots = M.screenshots + 1 end
return M
