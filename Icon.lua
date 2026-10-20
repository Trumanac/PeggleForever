local AddOn, config = ...
if config.disabled then return end
local function TogglePeggleWindow()
	local m = PeggleWindow.minimap
	m:GetScript("OnMouseUp")(m, "LeftButton")
end

local ldb = LibStub("LibDataBroker-1.1"):NewDataObject("PeggleForeverLDB", {
	type = "data source",
	text = "Peggle Forever",
	icon = "Interface\\AddOns\\"..AddOn.."\\images\\minimap",
	OnClick = TogglePeggleWindow,
	OnTooltipShow = function(tt)
		tt:AddLine("|cFFFFFFFFPeggle Forever")
		tt:AddLine("Click to show or hide the game. Drag to move this icon.")
		tt:AddLine("/peggle or /peg also opens it.", .6, .6, .6)
	end,
})

local icon = LibStub("LibDBIcon-1.0")

local function OnEvent(self, event, addon)
	if addon == AddOn then
		PeggleForeverData.minimap = PeggleForeverData.minimap or {}
		icon:Register("PeggleForeverIcon", ldb, PeggleForeverData.minimap)
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", OnEvent)

-- A duel invite (Options: "Mini-map Icon Alert") blinks the icon until it is answered or runs out, as the
-- original add-on's own minimap button did.
local plain, notice = ldb.icon, "Interface\\AddOns\\"..AddOn.."\\images\\minimapNotice"
local lit = false
C_Timer.NewTicker(.5, function()
	local win = PeggleWindow
	local waiting = win and win.minimap and win.minimap.notice and win.duelTimer and win.duelTimer:IsShown()
	if waiting then
		lit = not lit
	else
		lit = false
	end
	local want = lit and notice or plain
	if ldb.icon ~= want then
		ldb.icon = want
	end
end)
