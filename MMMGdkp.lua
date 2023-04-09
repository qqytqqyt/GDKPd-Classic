local addonName, MMMGdkpGlobal = ...
-- GLOBALS: MMMGdkp, MMMGdkp_PotData, MMMGdkp_Anchor, MMMGdkp_BalanceData, SlashCmdList, SLASH_MMMGdkp1, SLASH_MMMGdkp2, SLASH_MMMGdkp3
-- fetch all used functions into locals to improve performance
local table, tinsert, tremove, pairs, ipairs, unpack, math, tostring, tonumber, select, _G, strlen, setmetatable, string, print, next, type, rawget, date =
table, tinsert, tremove, pairs, ipairs, unpack, math, tostring, tonumber, select, _G, strlen, setmetatable, string, print
	, next, type, rawget, date
local SendAddonMessage, SendChatMessage, UnitIsRaidOfficer, UnitIsUnit, UnitIsGroupLeader, GetMasterLootCandidate, GetNumLootItems, GetLootSlotLink, GiveMasterLoot, UnitName, GetUnitName, CreateFrame, GetCVar, GetCVarBool, GetTime, StaticPopup_Show, GetItemInfo, GameTooltip, LibStub, ITEM_QUALITY_COLORS, InCombatLockdown, ERR_TRADE_COMPLETE, GetPlayerTradeMoney, GetTargetTradeMoney, GetItemIcon, ClearCursor, GetNumGroupMembers, GetRaidRosterInfo, GetLootThreshold, GetLootSlotType, GetLootSlotInfo, EditBox_HandleTabbing, GetCursorInfo, PickupItem, IsInRaid, IsInGroup, SendMail, SetSendMailMoney, ClearSendMail =
C_ChatInfo.SendAddonMessage, SendChatMessage, UnitIsRaidOfficer, UnitIsUnit, UnitIsGroupLeader, GetMasterLootCandidate,
	GetNumLootItems, GetLootSlotLink, GiveMasterLoot, UnitName, GetUnitName, CreateFrame, GetCVar, GetCVarBool, GetTime,
	StaticPopup_Show, GetItemInfo, GameTooltip, LibStub, ITEM_QUALITY_COLORS, InCombatLockdown, ERR_TRADE_COMPLETE,
	GetPlayerTradeMoney, GetTargetTradeMoney, GetItemIcon, ClearCursor, GetNumGroupMembers, GetRaidRosterInfo,
	GetLootThreshold, GetLootSlotType, GetLootSlotInfo, EditBox_HandleTabbing, GetCursorInfo, PickupItem, IsInRaid,
	IsInGroup, SendMail, SetSendMailMoney, ClearSendMail
local _
local UIParent, MailFrame =
UIParent, MailFrame

-- Fetch all the different realm separators into a table
local REALM_SEPARATOR_LIST = {}
for s in REALM_SEPARATORS:gmatch(".") do tinsert(REALM_SEPARATOR_LIST, s) end

-- table handling to prevent any memory leakage from accumulating.
local emptytable = select(2, ...).emptytable

local MMMGdkp_ProcessingItems = {}

local DEBUGFORCEVERSION

local MMMGdkp_waitFrame = nil;
local MMMGdkp_waitTable = {};

function MMMGdkp_wait(delay, func, ...)
	if(type(delay)~="number" or type(func)~="function") then
	  return false;
	end
	if (MMMGdkp_waitFrame == nil) then
	  MMMGdkp_waitFrame = CreateFrame("Frame","MMMGdkp_waitFrame", UIParent);
	  MMMGdkp_waitFrame:SetScript("onUpdate",function (self,elapse)
		local count = #MMMGdkp_waitTable;
		local i = 1;
		while(i<=count) do
		  local waitRecord = tremove(MMMGdkp_waitTable,i);
		  local d = tremove(waitRecord,1);
		  local f = tremove(waitRecord,1);
		  local p = tremove(waitRecord,1);
		  if(d>elapse) then
			tinsert(MMMGdkp_waitTable,i,{d-elapse,f,p});
			i = i + 1;
		  else
			count = count - 1;
			f(unpack(p));
		  end
		end
	  end);
	end
	tinsert(MMMGdkp_waitTable,{delay,func,{...}});
	return true;
  end

--[===[@debug@
DEBUGFORCEVERSION="2.0.0"
--@end-debug@]==]]===]
-- fetch locale data
local L = LibStub("AceLocale-3.0"):GetLocale("MMMGdkp")
-- versioning info
local VERSIONING_STRINGS = {
	VERSION_NONFUNCTIONAL = L["This version of MMMGdkp was never functional due to internal errors."],
	INCOMPATIBLE_AUCTIONSTART = L["This version will be unable to recognize auctions started by you."],
	INCOMPATIBLE_DISTRIBUTE = L["This version's player balance window will be unable to recognize distributions by you."],
	INCOMPATIBLE_AUCTIONCANCEL = L["This version will be unable to recognize auctions cancelled by you."],
	INCOMPATIBLE_VERSIONCHECK = L[
		"This version will be unable to recognize version check requests by you. Version check requests sent by this version of MMMGdkp will not be answered."
		],
}
local COMPATIBLE_VERSIONS = {
	["2.0.0"] = true,
}
local INCOMPATIBLE_VERSIONS = {
	["beta-1"] = { "INCOMPATIBLE_AUCTIONSTART", "INCOMPATIBLE_AUCTIONCANCEL", "INCOMPATIBLE_DISTRIBUTE" },
}

-- define a few old API functions that I can't be bothered to replace everywhere
local function IsRaidOfficer()
	return IsInRaid() and UnitIsRaidOfficer("player")
end

local function IsRaidLeader()
	return IsInRaid() and UnitIsGroupLeader("player")
end

local function LootSlotIsItem(i)
	return (GetLootSlotType(i) == 1)
end

-- static popup dialog definition
StaticPopupDialogs["MMMGdkp_RESETPOT"] = {
	text = L["Do you want to save your pot or reset without saving? You can also add a note to the pot."],
	button1 = SAVE .. " & " .. RESET,
	button2 = RESET,
	button3 = CANCEL,
	hasEditBox = true,
	EditBoxOnEnterPressed = function(self) self:GetParent().button1:Click() end,
	OnAccept = function(self)
		tinsert(MMMGdkp_PotData.history,
			{ size = MMMGdkp_PotData.potAmount, date = date(), items = MMMGdkp_PotData.curPotHistory,
				note = (strlen(self.editBox:GetText()) > 0 and self.editBox:GetText()) })
		MMMGdkp_PotData.potAmount = 0
		MMMGdkp_PotData.prevDist = 0
		MMMGdkp_PotData.curPotHistory = {}
		MMMGdkp_PotData.playerBalance = setmetatable({}, { __index = function() return 0 end })
		MMMGdkp.status:Update()
		MMMGdkp.balance:Update()
		if MMMGdkp.history:IsShown() then
			MMMGdkp.history:Update()
		end
	end,
	OnCancel = function(self)
		MMMGdkp_PotData.potAmount = 0
		MMMGdkp_PotData.prevDist = 0
		MMMGdkp_PotData.curPotHistory = {}
		MMMGdkp_PotData.playerBalance = setmetatable({}, { __index = function() return 0 end })
		MMMGdkp.status:Update()
		MMMGdkp.balance:Update()
	end,
	timeout = 0,
}
StaticPopupDialogs["MMMGdkp_SLIMMLWARN"] = {
	text = L[
		"WARNING!\n\nIf you use the slim bidding frame, you will be unable to cancel auctions and revert bids!\nAre you certain you want to do this?"
		],
	button1 = YES,
	button2 = NO,
	OnShow = function(self)
		--elevate it above aceconfig
		self:SetFrameStrata("FULLSCREEN_DIALOG")
		self.button1:SetFrameLevel(10000)
		self.button2:SetFrameLevel(10000)
	end,
	OnAccept = function()
		MMMGdkp.opt.slimML = true
		MMMGdkp.opt.slimMLConfirmed = true
	end,
	OnHide = function(self)
		self:SetFrameStrata("DIALOG")
	end,
	timeout = 0,
	hideOnEscape = true,
	whileDead = true,
	showAlert = true,
	cancels = "MMMGdkp_SLIMMLWARN",
}
StaticPopupDialogs["MMMGdkp_ADDTOPOT"] = {
	text = L["Enter the amount you want to add to the pot:"],
	button1 = ADD,
	button2 = CANCEL,
	hasEditBox = true,
	OnShow = function(self)
		self.button1:Disable()
	end,
	EditBoxOnEnterPressed = function(self) self:GetParent().button1:Click() end,
	EditBoxOnTextChanged = function(self)
		if strlen(self:GetText()) > 0 then
			self:GetParent().button1:Enable()
		else
			self:GetParent().button1:Disable()
		end
	end,
	OnAccept = function(self)
		MMMGdkp_PotData.potAmount = (tonumber(self.editBox:GetText()) or 0) + MMMGdkp_PotData.potAmount
		tinsert(MMMGdkp_PotData.curPotHistory, tonumber(self.editBox:GetText()) or 0)
		MMMGdkp.status:Update()
	end,
	timeout = 0,
	whileDead = true,
}
StaticPopupDialogs["MMMGdkp_REMFROMPOT"] = {
	text = L["Enter the amount you want to subtract from the pot:"],
	button1 = REMOVE,
	button2 = CANCEL,
	hasEditBox = true,
	OnShow = function(self)
		self.button1:Disable()
	end,
	EditBoxOnEnterPressed = function(self) self:GetParent().button1:Click() end,
	EditBoxOnTextChanged = function(self)
		if strlen(self:GetText()) > 0 then
			self:GetParent().button1:Enable()
		else
			self:GetParent().button1:Disable()
		end
	end,
	OnAccept = function(self)
		MMMGdkp_PotData.potAmount = math.max(0, MMMGdkp_PotData.potAmount - (tonumber(self.editBox:GetText()) or 0))
		tinsert(MMMGdkp_PotData.curPotHistory, (tonumber(self.editBox:GetText()) or 0) * (-1))
		MMMGdkp.status:Update()
	end,
	timeout = 0,
	whileDead = true,
}
StaticPopupDialogs["MMMGdkp_ADDTOPLAYER"] = {
	text = L["Enter the amount you want to add to player %s:"],
	button1 = ADD,
	button2 = CANCEL,
	hasEditBox = true,
	OnShow = function(self)
		self.button1:Disable()
	end,
	EditBoxOnEnterPressed = function(self) self:GetParent().button1:Click() end,
	EditBoxOnTextChanged = function(self)
		if strlen(self:GetText()) > 0 then
			self:GetParent().button1:Enable()
		else
			self:GetParent().button1:Disable()
		end
	end,
	OnAccept = function(self, data)
		MMMGdkp_PotData.playerBalance[data] = (MMMGdkp_PotData.playerBalance[data] + (tonumber(self.editBox:GetText()) or 0))
		SendAddonMessage("MMMGdkp MANADJ", tostring((tonumber(self.editBox:GetText()) or 0) * (-1)), "WHISPER", data)
		MMMGdkp.balance:Update()
		if MMMGdkp.opt.linkBalancePot then
			MMMGdkp_PotData.potAmount = math.max(0, MMMGdkp_PotData.potAmount - (tonumber(self.editBox:GetText()) or 0))
			tinsert(MMMGdkp_PotData.curPotHistory, (tonumber(self.editBox:GetText()) or 0) * (-1))
			MMMGdkp.status:Update()
		end
	end,
	timeout = 0,
	whileDead = true,
}
StaticPopupDialogs["MMMGdkp_REMFROMPLAYER"] = {
	text = L["Enter the amount you want to subtract from player %s:"],
	button1 = REMOVE,
	button2 = CANCEL,
	hasEditBox = true,
	OnShow = function(self)
		self.button1:Disable()
	end,
	EditBoxOnEnterPressed = function(self) self:GetParent().button1:Click() end,
	EditBoxOnTextChanged = function(self)
		if strlen(self:GetText()) > 0 then
			self:GetParent().button1:Enable()
		else
			self:GetParent().button1:Disable()
		end
	end,
	OnAccept = function(self, data)
		MMMGdkp_PotData.playerBalance[data] = (MMMGdkp_PotData.playerBalance[data] - (tonumber(self.editBox:GetText()) or 0))
		SendAddonMessage("MMMGdkp MANADJ", tostring(tonumber(self.editBox:GetText()) or 0), "WHISPER", data)
		MMMGdkp.balance:Update()
		if MMMGdkp.opt.linkBalancePot then
			MMMGdkp_PotData.potAmount = MMMGdkp_PotData.potAmount + (tonumber(self.editBox:GetText()) or 0)
			tinsert(MMMGdkp_PotData.curPotHistory, tonumber(self.editBox:GetText()) or 0)
			MMMGdkp.status:Update()
		end
	end,
	timeout = 0,
	whileDead = true,
}
StaticPopupDialogs["MMMGdkp_MAILGOLD"] = {
	text = L["Are you sure you want to mail %s gold to player %s?"],
	button1 = L["Mail money"],
	button2 = CANCEL,
	OnAccept = function(self, data)
		MMMGdkp:MailBalanceGold(data)
	end,
	timeout = 0,
	whileDead = true,
	showAlert = true,
	hideOnEscape = true,
}
StaticPopupDialogs["MMMGdkp_WIPEHISTORY"] = {
	text = L[
		"This will completely wipe your auction history and is IRREVERSIBLE.\nAre you completely SURE you want to do this?"],
	button1 = L["Wipe history"],
	button2 = CANCEL,
	OnAccept = function()
		table.wipe(MMMGdkp_PotData.history)
		if MMMGdkp.history:IsShown() then
			MMMGdkp.history:Update()
		end
	end,
	timeout = 0,
	hideOnEscape = true,
	whileDead = true,
	showAlert = true,
	cancels = "MMMGdkp_WIPEHISTORY",
}
StaticPopupDialogs["MMMGdkp_AUTOBID"] = {
	text = L["Enter the maximum amount of money you want to bid on %s:"],
	button1 = BID,
	button2 = CANCEL,
	hasEditBox = true,
	OnShow = function(self)
		self.button1:Disable()
	end,
	EditBoxOnEnterPressed = function(self) self:GetParent().button1:Click() end,
	EditBoxOnTextChanged = function(self)
		if strlen(self:GetText()) > 0 then
			self:GetParent().button1:Enable()
		else
			self:GetParent().button1:Disable()
		end
	end,
	OnAccept = function(self, data)
		data.maxAutoBid = tonumber(self.editBox:GetText())
		if (data.curbidismine == false) and data.maxAutoBid then
			local newBid = data.curbidamount + data.bidIncrement
			if newBid <= data.maxAutoBid then
				if data.isMultiBid then
					SendChatMessage(data.itemlink .. " " .. newBid, "RAID")
				else
					SendChatMessage(tostring(newBid), "RAID")
				end
			end
		end
		data.autobid:Hide()
		data.stopautobid:Show()
	end,
	timeout = 0,
}
StaticPopupDialogs["MMMGdkp_CURPOTCLICK"] = {
	text = L["You have selected the current pot, size %d gold.\nWhat do you want to do with this pot?"],
	button1 = L["Export"],
	button2 = DELETE,
	button3 = CANCEL,
	OnShow = function(self) self.button3:Disable() end,
	OnAccept = function(self)
		MMMGdkp.exportframe:Show()
		MMMGdkp.exportframe:Set("", MMMGdkp_PotData.curPotHistory)
	end,
	timeout = 0,
	whileDead = true,
}
StaticPopupDialogs["MMMGdkp_HISTORYCLICK"] = {
	text = "%s",
	button1 = L["Export"],
	button2 = DELETE,
	button3 = CANCEL,
	OnAccept = function(self, data)
		print("onaccept")
		local output = "MMMGdkp pot data for " .. data.date .. "\nPot size: " .. data.size .. " gold"
		if data.note then
			output = output .. "\nNote: " .. data.note
		end
		--[[if data.items then
			for _, aucdata in ipairs(data.items) do
				if type(aucdata) == "table" then
					output = output.."\n"..(aucdata.item:match("(|h.+|h)"))..": "..aucdata.name.." ("..aucdata.bid.." gold)"
				else
					output = output.."\n"..L["Manual adjustment"]..": "..(aucdata > 0 and "+" or "")..aucdata.." gold"
				end
			end
		end--]]
		MMMGdkp.exportframe:Show()
		MMMGdkp.exportframe:Set(output, data.items)
	end,
	OnCancel = function(self, data, clickType)
		if clickType == "override" then return end
		for num, t in ipairs(MMMGdkp_PotData.history) do
			if t == data then
				tremove(MMMGdkp_PotData.history, num)
				break
			end
		end
		MMMGdkp.history:Update()
	end,
	timeout = 0,
	whileDead = 0,
}
StaticPopupDialogs["MMMGdkp_CUSTOMSETTINGSID"] = {
	text = L["Please enter the itemID of an item you want to drop here:"],
	button1 = OKAY,
	button2 = CANCEL,
	hasEditBox = true,
	OnShow = function(self)
		self.button1:Disable()
	end,
	EditBoxOnEnterPressed = function(self) self:GetParent().button1:Click() end,
	hideOnEscape = true,
	EditBoxOnTextChanged = function(self)
		if (tonumber(self:GetText())) and (tonumber(self:GetText()) >= 0) and
			(not MMMGdkp.opt.customItemSettings[tonumber(self:GetText())]) then
			self:GetParent().button1:Enable()
		else
			self:GetParent().button1:Disable()
		end
	end,
	OnAccept = function(self)
		MMMGdkp.opt.customItemSettings[tonumber(self.editBox:GetText())] = {}
		MMMGdkp.itemsettings:Update()
	end,
	timeout = 0,
}
StaticPopupDialogs["MMMGdkp_42_ADDONMSG"] = {
	text = L[
		"Due to the changes to the addon message system implemented in patch 4.2, MMMGdkp is no longer able to communicate using its old version checking standard.\nThus, this version of MMMGdkp will only be able to send and receive version checks from and to versions 1.2.0 and above of MMMGdkp.\nWhile all other functionalities of MMMGdkp should still be compatible with previous versions, we |cffff0000strongly recommend updating MMMGdkp to version 1.2.0 or above|r."
		],
	button1 = OKAY,
	showAlert = true,
	hideOnEscape = false,
	timeout = 0,
}
local function round(num, places)
	return tonumber(string.format("%." .. (places or 0) .. "f", num))
end

-- if GetUnitName cannot parse the name as a unitID, that means they're from our realm - parse manually
local function localNameOnly(name)
	for _, s in ipairs(REALM_SEPARATOR_LIST) do
		local i = name:find(s, 1, true)
		if i then name = name:sub(1, i - 1) end
	end
	return name
end

local function pruneCrossRealm(name) -- only use for people in the raid group!
	return GetUnitName(name, true) or localNameOnly(name)
end

MMMGdkp = CreateFrame("Frame")
local MMMGdkp = MMMGdkp
MMMGdkp.frames = {}
MMMGdkp.curAuction = {}
MMMGdkp.curAuctions = {}
MMMGdkp.auctionList = {}
MMMGdkp.ignoredLinks = {}
MMMGdkp.versions = {}
MMMGdkp:Hide()
MMMGdkp:SetScript("OnUpdate", function(self, elapsed)
	if (not self.curAuction.item) and (not next(self.curAuctions)) then self:Hide() return end
	if not self.opt.allowMultipleAuctions then
		-- old code for single auctions
		local curPot = math.floor(self.curAuction.timeRemains / self.opt.countdownTimerJump)
		self.curAuction.timeRemains = self.curAuction.timeRemains - elapsed
		if (curPot ~= math.floor(self.curAuction.timeRemains / self.opt.countdownTimerJump)) and
			(curPot * self.opt.countdownTimerJump < self.opt.auctionTimer) and
			(not (next(self.curAuction.bidders, nil) and (curPot * self.opt.countdownTimerJump == self.opt.auctionTimerRefresh)))
			and (curPot > 0) then
			SendChatMessage("[Caution] " .. (curPot * self.opt.countdownTimerJump) .. " seconds remaining!", "RAID")
		end
		if self.curAuction.timeRemains <= 0 then
			self:Hide()
			self:FinishAuction()
		end
	else
		-- new code for multiple auctions
		local auctionsToFinish = emptytable()
		for item, aucdata in pairs(self.curAuctions) do
			local curPot = math.floor(aucdata.timeRemains / self.opt.countdownTimerJump)
			aucdata.timeRemains = aucdata.timeRemains - elapsed
			if (curPot ~= math.floor(aucdata.timeRemains / self.opt.countdownTimerJump)) and
				(curPot * self.opt.countdownTimerJump < self.opt.auctionTimer) and
				(not (next(aucdata.bidders, nil) and (curPot * self.opt.countdownTimerJump == self.opt.auctionTimerRefresh))) and
				(curPot > 0) and (aucdata.timeRemains < 6) then
				SendChatMessage("[Caution] " ..
					(curPot * self.opt.countdownTimerJump) .. " seconds remaining for item " .. item ..
					"!", "RAID")
			end
			if aucdata.timeRemains <= 0 then
				tinsert(auctionsToFinish, item)
			end
		end
		if #auctionsToFinish > 0 then
			for _, link in ipairs(auctionsToFinish) do
				self:FinishAuction(link)
			end
		end
		auctionsToFinish:Release()
		-- there are no keys
		if not next(self.curAuctions) then
			self:Hide()
		end
	end
end)
local anchor = CreateFrame("Frame", "MMMGdkp_Anchor", UIParent)
anchor:SetClampedToScreen(true)
anchor:EnableMouse(true)
anchor:SetScript("OnMouseDown", function(self)
	self:StartMoving()
end)
anchor:SetMovable(true)
anchor:SetScript("OnMouseUp", function(self)
	self:StopMovingOrSizing()
	MMMGdkp.opt.point.point, _, MMMGdkp.opt.point.relative, MMMGdkp.opt.point.x, MMMGdkp.opt.point.y = self:GetPoint()
end)
anchor:SetSize(300, 60)
anchor:SetFrameStrata("DIALOG")
anchor:Hide()
anchor.movetx = anchor:CreateTexture()
anchor.movetx:SetAllPoints()
anchor.movetx:SetTexture(0.3, 0.3, 0.9)
anchor.movetx:SetAlpha(0.5)
anchor.movetx.text = anchor:CreateFontString()
anchor.movetx.text:SetFontObject(GameFontHighlightLarge)
anchor.movetx.text:SetText(L["MMMGdkp: Drag to move\n/MMMGdkp and check \"Lock\" to hide"])
anchor.movetx.text:SetAllPoints()
MMMGdkp.status = CreateFrame("Frame", "MMMGdkp_Status", nil, BackdropTemplateMixin and "BackdropTemplate")
local status = MMMGdkp.status
status:SetSize(200, 90)
status:Hide()
status:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
	tileSize = 32,
	edgeSize = 24,
	tile = true,
	insets = {
		top = 6,
		bottom = 6,
		right = 6,
		left = 6,
	},
})
function status:UpdateVisibility(forceCombat)
	if MMMGdkp.opt.hide then
		self:Hide()
		return
	end
	if ((not MMMGdkp.opt.hideCombat.status) or (not (forceCombat ~= nil and forceCombat or InCombatLockdown()))) and
		MMMGdkp:PlayerIsML((UnitName("player")), true) then
		self:Show()
	else
		self:Hide()
	end
end

status.header = CreateFrame("Button", nil, status)
status.header:SetNormalTexture("Interface\\DialogFrame\\UI-DialogBox-Gold-Header")
status.header:SetSize(133, 34)
status.header.text = status.header:CreateFontString()
status.header.text:SetPoint("TOP", 0, -7)
status.header.text:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
status.header.text:SetTextColor(1, 1, 1)
status.header.text:SetText("MMMGdkp")
status.header:SetMovable(true)
status.header:SetScript("OnMouseDown", function(self)
	self:StartMoving()
end)
status.header:SetScript("OnMouseUp", function(self)
	self:StopMovingOrSizing()
	MMMGdkp.opt.statuspoint.point, _, MMMGdkp.opt.statuspoint.relative, MMMGdkp.opt.statuspoint.x, MMMGdkp.opt.statuspoint.y = self
		:GetPoint()
end)
status:SetPoint("TOP", status.header, "TOP", 0, -6)
status:SetScript("OnShow", function(self)
	self:UpdateSize()
end)
status.text = status:CreateFontString()
status.text:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
status.text:SetTextColor(1, 1, 1)
status.text:SetPoint("TOPLEFT", 15, -15)
status.text:SetJustifyH("LEFT")
status.distribute = CreateFrame("Button", nil, status, "UIPanelButtonTemplate")
status.distribute:SetSize(65, 15)
status.distribute:SetPoint("TOPLEFT", status.text, "BOTTOMLEFT", 0, -5)
status.distribute:SetText(L["Distribute"])
status.distribute:SetScript("OnClick", function(self)
	MMMGdkp:DistributePot()
end)
status.reset = CreateFrame("Button", nil, status, "UIPanelButtonTemplate")
status.reset:SetSize(65, 15)
status.reset:SetPoint("LEFT", status.distribute, "RIGHT")
status.reset:SetText(RESET)
status.reset:SetScript("OnClick", function(self)
	StaticPopup_Show("MMMGdkp_RESETPOT")
end)
status.add = CreateFrame("Button", nil, status, "UIPanelButtonTemplate")
status.add:SetSize(15, 15)
status.add:SetPoint("LEFT", status.reset, "RIGHT", 10, 0)
status.add:SetText("+")
status.add:SetScript("OnClick", function(self)
	StaticPopup_Show("MMMGdkp_ADDTOPOT")
end)
status.rem = CreateFrame("Button", nil, status, "UIPanelButtonTemplate")
status.rem:SetSize(15, 15)
status.rem:SetPoint("LEFT", status.add, "RIGHT")
status.rem:SetText("-")
status.rem:SetScript("OnClick", function(self)
	StaticPopup_Show("MMMGdkp_REMFROMPOT")
end)
status.rules = CreateFrame("Button", nil, status, "UIPanelButtonTemplate")
status.rules:SetSize(170, 15)
status.rules:SetPoint("TOPLEFT", status.distribute, "BOTTOMLEFT")
status.rules:SetText(L["Broadcast rules"])
status.rules:SetScript("OnClick", function()
	local announceStrings = emptytable("")
	for line in string.gmatch(MMMGdkp.opt.rulesString, "[^\n]+") do
		for word in string.gmatch(line, "%S+") do
			if strlen(announceStrings[#announceStrings]) + 1 + strlen(word) > 255 then
				tinsert(announceStrings, word)
			else
				if strlen(announceStrings[#announceStrings]) > 0 then
					announceStrings[#announceStrings] = announceStrings[#announceStrings] .. " " .. word
				else
					announceStrings[#announceStrings] = word
				end
			end
		end
		tinsert(announceStrings, "")
	end
	for _, msg in ipairs(announceStrings) do
		SendChatMessage(msg, "RAID")
	end
	announceStrings:Release()
end)
status.rules:Disable()

status.itemhistory = CreateFrame("Button", nil, status, "UIPanelButtonTemplate")
status.itemhistory:SetSize(170, 15)
status.itemhistory:SetPoint("TOPLEFT", status.rules, "BOTTOMLEFT")
status.itemhistory:SetText(L["Auction history"])
status.itemhistory:SetScript("OnEnter", function(self)
	GameTooltip:ClearAllPoints()
	GameTooltip:ClearLines()
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:AddLine(L["MMMGdkp auction history"], 1, 1, 1)
	for _, aucdata in ipairs(MMMGdkp_PotData.curPotHistory) do
		if type(aucdata) == "table" then
			GameTooltip:AddDoubleLine("|T" .. GetItemIcon(aucdata.item) .. ":12|t " .. aucdata.item,
				aucdata.name .. " (" .. aucdata.bid .. "|cffffd100g|r)", 1, 1, 1, 1, 1, 1)
		else
			GameTooltip:AddDoubleLine("|T:12|t " .. L["Manual adjustment"], (aucdata > 0 and "+" or "") ..
				aucdata .. "|cffffd100g|r", 1, 1, 1, 1, 1, 1)
		end
	end
	GameTooltip:SetPoint("BOTTOM", self, "TOP", 0, 5)
	GameTooltip:Show()
end)
status.itemhistory:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)
status.itemhistory:SetScript("OnClick", function()
	MMMGdkp.history:Show()
end)
status.announcetext = status:CreateFontString()
status.announcetext:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
status.announcetext:SetTextColor(1, 1, 1)
status.announcetext:SetPoint("TOPLEFT", status.itemhistory, "BOTTOMLEFT", 0, -5)
status.announcetext:SetJustifyH("LEFT")
status.announcetext:SetText(L["You have looted a monster!\nDo you want MMMGdkp to announce loot?"])
status.announcetext:Hide()
status.announce1 = CreateFrame("Button", nil, status, "UIPanelButtonTemplate")
status.announce1:SetSize(170, 15)
status.announce1:SetPoint("TOPLEFT", status.announcetext, "BOTTOMLEFT", 0, -5)
status.announce1:SetText(L["Announce & auto-auction"])
status.announce1:SetScript("OnClick", function(self)
	MMMGdkp:AnnounceLoot(true)
	status.announcetext:Hide()
	self:Hide()
	status.announce2:Hide()
	status.noannounce:Hide()
	status:UpdateSize()
end)
status.announce1:Hide()
status.announce2 = CreateFrame("Button", nil, status, "UIPanelButtonTemplate")
status.announce2:SetSize(170, 15)
status.announce2:SetPoint("TOPLEFT", status.announce1, "BOTTOMLEFT", 0, -5)
status.announce2:SetText(L["Announce loot"])
status.announce2:SetScript("OnClick", function(self)
	MMMGdkp:AnnounceLoot(false)
	status.announcetext:Hide()
	status.announce1:Hide()
	self:Hide()
	status.noannounce:Hide()
	status:UpdateSize()
end)
status.announce2:Hide()
status.noannounce = CreateFrame("Button", nil, status, "UIPanelButtonTemplate")
status.noannounce:SetSize(170, 15)
status.noannounce:SetPoint("TOPLEFT", status.announce2, "BOTTOMLEFT", 0, -5)
status.noannounce:SetText(L["Do not announce"])
status.noannounce:SetScript("OnClick", function(self)
	status.announcetext:Hide()
	status.announce1:Hide()
	status.announce2:Hide()
	self:Hide()
	status:UpdateSize()
end)
status.noannounce:Hide()
function status:UpdateSize()
	local height = 80
	height = height + status.text:GetHeight()
	if status.announcetext:IsShown() then
		height = height + status.announcetext:GetHeight() + 5
	end
	if status.announce1:IsShown() then
		height = height + 20
	end
	if status.announce2:IsShown() then
		height = height + 20
	end
	if status.noannounce:IsShown() then
		height = height + 20
	end
	self:SetHeight(height)
end

function status:Update()
	local potAmount = (MMMGdkp_PotData.potAmount or 0)
	local lastDist = (MMMGdkp_PotData.prevDist or 0)
	if lastDist > 0 then
		self.text:SetText(L["Pot size: %d|cffffd100g|r"]:format(potAmount) ..
			L[" |cffaa0000(Distribute: %dg)|r"]:format(potAmount - lastDist))
	else
		self.text:SetText(L["Pot size: %d|cffffd100g|r"]:format(potAmount))
	end
	self:UpdateSize()
end

MMMGdkp.history = CreateFrame("Frame", "MMMGdkp_History", UIParent, BackdropTemplateMixin and "BackdropTemplate")
local history = MMMGdkp.history
history:SetSize(200, 95)
history:Hide()
history:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
	tileSize = 32,
	edgeSize = 24,
	tile = true,
	insets = {
		top = 6,
		bottom = 6,
		right = 6,
		left = 6,
	},
})
history.header = CreateFrame("Button", nil, history)
history.header:SetNormalTexture("Interface\\DialogFrame\\UI-DialogBox-Gold-Header")
history.header:SetSize(133, 34)
history.header:SetHitRectInsets(31.5, 31.5, 4.5, 14.5)
history.header.text = history.header:CreateFontString()
history.header.text:SetPoint("TOP", 0, -7)
history.header.text:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
history.header.text:SetTextColor(1, 1, 1)
history.header.text:SetText(L["History"])
history.header:SetMovable(true)
history.header:SetScript("OnMouseDown", function(self)
	self:StartMoving()
end)
history.header:SetScript("OnMouseUp", function(self)
	self:StopMovingOrSizing()
end)
history.header:SetPoint("CENTER", UIParent, "CENTER")
history:SetPoint("TOP", history.header, "TOP", 0, -6)
history:SetScript("OnShow", function(self)
	self:Update()
end)
history.entries = setmetatable({}, { __index = function(t, v)
	local f = CreateFrame("Button", nil, history)
	if v > 1 then
		f:SetPoint("TOPLEFT", t[v - 1], "BOTTOMLEFT", 0, -5)
		f:SetPoint("TOPRIGHT", t[v - 1], "BOTTOMRIGHT", 0, -5)
	else
		f:SetPoint("TOPLEFT", 15, -15)
		f:SetPoint("TOPRIGHT", -15, -15)
	end
	function f:UpdateHeight()
		self:SetHeight(f.date:GetHeight())
	end

	f.date = f:CreateFontString()
	f.date:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
	f.date:SetTextColor(1, 1, 1)
	f.date:SetPoint("TOPLEFT")
	f.date:SetWidth(55)
	f.amount = f:CreateFontString()
	f.amount:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
	f.amount:SetTextColor(1, 1, 1)
	f.amount:SetPoint("TOPLEFT", f.date, "TOPRIGHT", 5, 0)
	f.amount:SetPoint("BOTTOMLEFT", f.date, "BOTTOMRIGHT", 5, 0)
	f.amount:SetWidth(40)
	f.amount:SetJustifyH("RIGHT")
	f.note = f:CreateFontString()
	f.note:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
	f.note:SetTextColor(1, 1, 1)
	f.note:SetPoint("BOTTOMLEFT", f.amount, "BOTTOMRIGHT", 5, 0)
	f.note:SetPoint("TOPRIGHT")
	f.note:SetJustifyH("LEFT")
	function f:SetDataTable(data)
		self.date:SetText(data.date:match("%S+"))
		self.rawdate = data.date
		self.amount:SetText(data.size .. "|cffffd100g|r")
		self.rawamount = data.size
		self.note:SetText(data.note)
		self.itemtable = data.items
		self.data = data
		self:UpdateHeight()
	end

	function f:SetRawData(date, amount, note, items)
		self.date:SetText(date)
		self.rawdate = date
		self.amount:SetText(amount .. "|cffffd100g|r")
		self.rawamount = amount
		self.note:SetText(note)
		self.itemtable = items
		self:UpdateHeight()
	end

	f:SetScript("OnEnter", function(self)
		GameTooltip:ClearAllPoints()
		GameTooltip:ClearLines()
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		if self.itemtable then
			GameTooltip:AddLine(L["MMMGdkp auction history for %s"]:format(self.rawdate), 1, 1, 1)
			if self.note:GetText() then
				GameTooltip:AddLine(L["Auction note: %s"]:format(self.note:GetText()), 1, 1, 1)
			end
			for _, aucdata in ipairs(self.itemtable) do
				if type(aucdata) == "table" then
					GameTooltip:AddDoubleLine("|T" .. GetItemIcon(aucdata.item) .. ":12|t " .. aucdata.item,
						aucdata.name .. " (" .. aucdata.bid .. "|cffffd100g|r)", 1, 1, 1, 1, 1, 1)
				else
					GameTooltip:AddDoubleLine("|T:12|t " .. L["Manual adjustment"],
						(aucdata > 0 and "+" or "") .. aucdata .. "|cffffd100g|r", 1, 1, 1, 1, 1, 1)
				end
			end
		else
			GameTooltip:AddLine(L["MMMGdkp: No detailed data available"], 1, 1, 1)
		end
		GameTooltip:SetPoint("TOPRIGHT", self, "LEFT", -5, 0)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)
	f:SetScript("OnClick", function(self)
		ClearCursor()
		if self.data then
			StaticPopup_Show("MMMGdkp_HISTORYCLICK",
				L["You have selected the following pot:\n%s, dated %s, size %d gold.\nWhat do you want to do with this pot?"]:format(self
					.note:GetText(), self.date:GetText(), self.rawamount)).data = self.data
		else
			StaticPopup_Show("MMMGdkp_CURPOTCLICK", MMMGdkp_PotData.potAmount)
		end
	end)
	t[v] = f
	return f
end })
history.hide = CreateFrame("Button", nil, history, "UIPanelButtonTemplate")
history.hide:SetSize(170, 15)
history.hide:SetPoint("BOTTOM", 0, 15)
history.hide:SetText(L["Hide"])
history.hide:SetScript("OnClick", function() history:Hide() end)
function history:Update()
	for _, f in ipairs(self.entries) do
		f:Hide()
	end
	local c = 1
	local size = 45
	for _, potdata in ipairs(MMMGdkp_PotData.history) do
		local f = self.entries[c]
		f:Show()
		f:SetDataTable(potdata)
		size = size + f:GetHeight() + 5
		c = c + 1
	end
	if MMMGdkp_PotData.potAmount > 0 then
		local f = self.entries[c]
		f:Show()
		f:SetRawData("Current pot", MMMGdkp_PotData.potAmount, nil, MMMGdkp_PotData.curPotHistory)
		size = size + f:GetHeight() + 5
		c = c + 1
	end
	self:SetHeight(size)
end

MMMGdkp.itemsettings = CreateFrame("Frame", "MMMGdkp_ItemSettings", UIParent, BackdropTemplateMixin and "BackdropTemplate")
local itemsettings = MMMGdkp.itemsettings
itemsettings:SetWidth(250)
itemsettings:Hide()
itemsettings:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
	tileSize = 32,
	edgeSize = 24,
	tile = true,
	insets = {
		top = 6,
		bottom = 6,
		right = 6,
		left = 6,
	},
})
itemsettings.header = CreateFrame("Button", nil, itemsettings)
itemsettings.header:SetNormalTexture("Interface\\DialogFrame\\UI-DialogBox-Gold-Header")
itemsettings.header:SetSize(133, 34)
itemsettings.header:SetHitRectInsets(31.5, 31.5, 4.5, 14.5)
itemsettings.header.text = itemsettings.header:CreateFontString()
itemsettings.header.text:SetPoint("TOP", 0, -7)
itemsettings.header.text:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
itemsettings.header.text:SetTextColor(1, 1, 1)
itemsettings.header.text:SetText(L["Item settings"])
itemsettings.header:SetMovable(true)
itemsettings.header:SetScript("OnMouseDown", function(self)
	self:StartMoving()
end)
itemsettings.header:SetScript("OnMouseUp", function(self)
	self:StopMovingOrSizing()
end)
itemsettings.header:SetPoint("CENTER", UIParent, "CENTER")
itemsettings:SetPoint("TOP", itemsettings.header, "TOP", 0, -6)
itemsettings:SetScript("OnShow", function(self)
	self:Update()
end)
itemsettings.thead = CreateFrame("Frame", nil, itemsettings)
itemsettings.thead:SetPoint("TOPLEFT", 15, -15)
itemsettings.thead:SetPoint("TOPRIGHT", -15, -15)
itemsettings.thead:SetHeight(15)
itemsettings.thead.item = itemsettings.thead:CreateFontString()
itemsettings.thead.item:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
itemsettings.thead.item:SetTextColor(1, 0.82, 0)
--itemsettings.thead.item:SetText(L["Itm"])
itemsettings.thead.item:SetPoint("LEFT")
itemsettings.thead.item:SetWidth(15)
itemsettings.thead.startbid = itemsettings.thead:CreateFontString()
itemsettings.thead.startbid:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
itemsettings.thead.startbid:SetTextColor(1, 0.82, 0)
itemsettings.thead.startbid:SetText(L["Starting bid"])
itemsettings.thead.startbid:SetPoint("LEFT", itemsettings.thead.item, "RIGHT")
itemsettings.thead.startbid:SetWidth(102.5)
itemsettings.thead.minincre = itemsettings.thead:CreateFontString()
itemsettings.thead.minincre:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
itemsettings.thead.minincre:SetTextColor(1, 0.82, 0)
itemsettings.thead.minincre:SetText(L["Minimum increment"])
itemsettings.thead.minincre:SetPoint("LEFT", itemsettings.thead.startbid, "RIGHT")
itemsettings.thead.minincre:SetPoint("RIGHT")
itemsettings.scroll = CreateFrame("ScrollFrame", nil, itemsettings)
itemsettings.scroll:SetPoint("TOPLEFT", itemsettings.thead, "BOTTOMLEFT", 0, -5)
itemsettings.scroll.child = CreateFrame("Frame", nil, itemsettings.scroll)
itemsettings.scroll.child:EnableMouseWheel(true)
itemsettings.scroll.child:SetScript("OnMouseWheel", function(self, delta)
	if delta == 1 then
		itemsettings.scroll:SetVerticalScroll(math.max(itemsettings.scroll:GetVerticalScroll() - 10, 0))
	else
		itemsettings.scroll:SetVerticalScroll(math.min(itemsettings.scroll:GetVerticalScroll() + 10,
			itemsettings.scroll:GetVerticalScrollRange()))
	end
end)
itemsettings.scroll.child:SetWidth(itemsettings.scroll:GetWidth())
itemsettings.scroll:SetScrollChild(itemsettings.scroll.child)
itemsettings.scroll:SetScript("OnSizeChanged", function(self, width)
	self.child:SetWidth(width)
	self:UpdateScrollChildRect()
end)
itemsettings.entries = setmetatable({}, { __index = function(t, v)
	local f = CreateFrame("Frame", nil, itemsettings.scroll.child)
	if v > 1 then
		f:SetPoint("TOPLEFT", t[v - 1], "BOTTOMLEFT", 0, -5)
		f:SetPoint("TOPRIGHT", t[v - 1], "BOTTOMRIGHT", 0, -5)
	else
		f:SetPoint("TOPLEFT"--[[, itemsettings.thead, "BOTTOMLEFT", 0, -5--]] )
		f:SetPoint("TOPRIGHT"--[[, itemsettings.thead, "BOTTOMRIGHT", 0, -5--]] )
	end
	f:SetHeight(15)
	f.itemicon = CreateFrame("Button", nil, f)
	f.itemicon:SetScript("OnEnter", function()
		if not f.itemID then return end
		GameTooltip:ClearAllPoints()
		GameTooltip:ClearLines()
		GameTooltip:SetOwner(f, "ANCHOR_NONE")
		GameTooltip:SetHyperlink("item:" .. f.itemID)
		GameTooltip:SetPoint("RIGHT", itemsettings, "LEFT", -5, 0)
		GameTooltip:Show()
	end)
	f.itemicon:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	f.itemicon:SetSize(15, 15)
	f.itemicon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
	f.itemicon:SetPoint("LEFT")
	f.itemicon:SetScript("OnMouseUp", function(self)
		if (select(1, GetCursorInfo())) == "item" then
			local id = (select(2, GetCursorInfo()))
			if MMMGdkp.opt.customItemSettings[id] then ClearCursor() return end
			if f.itemID then
				MMMGdkp.opt.customItemSettings[id] = MMMGdkp.opt.customItemSettings[f.itemID]
				MMMGdkp.opt.customItemSettings[f.itemID] = nil
			else
				MMMGdkp.opt.customItemSettings[id] = {}
			end
			ClearCursor()
			itemsettings:Update()
		else
			if f.itemID then
				local cis = MMMGdkp.opt.customItemSettings[f.itemID]
				if cis.minBid or cis.minIncrement then
					PickupItem(f.itemID)
				else
					MMMGdkp.opt.customItemSettings[f.itemID] = nil
					itemsettings:Update()
				end
			else
				StaticPopup_Show("MMMGdkp_CUSTOMSETTINGSID")
			end
		end
	end)
	f.itemicon:EnableMouse(true)
	f.minBid = CreateFrame("EditBox", nil, f)
	f.minBid:SetMultiLine(nil)
	f.minBid:SetScript("OnEditFocusGained", function(self) if not f.itemID then self:ClearFocus() end end)
	f.minBid:SetScript("OnEnterPressed",
		function(self) MMMGdkp.opt.customItemSettings[f.itemID].minBid = self:GetNumber() > 0 and self:GetNumber() or nil
			self:
				ClearFocus()
			itemsettings:Update()
		end)
	f.minBid:SetScript("OnEscapePressed",
		function(self) self:SetNumber(MMMGdkp.opt.customItemSettings[f.itemID].minBid) self:ClearFocus() end)
	f.minBid:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
	f.minBid:SetTextColor(1, 1, 1)
	f.minBid:SetPoint("TOPLEFT", f.itemicon, "TOPRIGHT")
	f.minBid:SetPoint("BOTTOMLEFT", f.itemicon, "BOTTOMRIGHT")
	f.minBid:SetJustifyH("RIGHT")
	f.minBid:SetAutoFocus(false)
	f.minBid:SetWidth(102.5)
	f.minBid:SetTextInsets(5, 5, 2, 2)
	f.minBid:SetNumeric(true)
	f.minBid:SetScript("OnTextChanged", function(self, userInput)
		if strlen(self:GetText()) > 0 then
			self.g:Show()
		else
			self.g:Hide()
		end
	end)
	f.minBid.g = f:CreateFontString()
	f.minBid.g:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
	f.minBid.g:SetTextColor(1, 0.82, 0)
	f.minBid.g:SetText("g")
	f.minBid.g:SetPoint("TOPRIGHT", f.itemicon, "TOPRIGHT", 102.5, 0)
	f.minBid.g:SetPoint("BOTTOMRIGHT", f.itemicon, "BOTTOMRIGHT", 102.5, 0)
	f.minBid:SetPoint("RIGHT", f.minBid.g, "LEFT")
	f.minBid.tex = f:CreateTexture(nil, "BACKGROUND")
	f.minBid.tex:SetPoint("TOPLEFT", f.minBid, 20, 0)
	f.minBid.tex:SetPoint("BOTTOMRIGHT", f.minBid.g)
	f.minBid.tex:SetAlpha(0.2)
	f.minBid.tex:SetTexture(0.5, 0.5, 0.5)
	f.minIncrement = CreateFrame("EditBox", nil, f)
	f.minIncrement:SetMultiLine(nil)
	f.minIncrement:SetScript("OnEditFocusGained", function(self) if not f.itemID then self:ClearFocus() end end)
	f.minIncrement:SetScript("OnEnterPressed",
		function(self) MMMGdkp.opt.customItemSettings[f.itemID].minIncrement = self:GetNumber() > 0 and self:GetNumber() or nil
			self
				:ClearFocus()
			itemsettings:Update()
		end)
	f.minIncrement:SetScript("OnEscapePressed",
		function(self) if MMMGdkp.opt.customItemSettings[f.itemID].minIncrement then self:SetNumber(MMMGdkp.opt.customItemSettings
					[f.itemID].minIncrement)
			else self:SetText("") end
			self:ClearFocus()
		end)
	f.minIncrement:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
	f.minIncrement:SetTextColor(1, 1, 1)
	f.minIncrement:SetPoint("TOPLEFT", f.minBid.g, "TOPRIGHT")
	f.minIncrement:SetPoint("BOTTOMLEFT", f.minBid.g, "BOTTOMRIGHT")
	f.minIncrement:SetJustifyH("RIGHT")
	f.minIncrement:SetAutoFocus(false)
	--f.minIncrement:Setp(102.5)
	f.minIncrement:SetTextInsets(5, 5, 2, 2)
	f.minIncrement:SetScript("OnTextChanged", function(self, userInput)
		if strlen(self:GetText()) > 0 then
			self.g:Show()
		else
			self.g:Hide()
		end
	end)
	f.minIncrement.g = f:CreateFontString()
	f.minIncrement.g:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
	f.minIncrement.g:SetTextColor(1, 0.82, 0)
	f.minIncrement.g:SetText("g")
	f.minIncrement.g:SetPoint("TOPRIGHT", f.minBid.g, "TOPRIGHT", 102.5, 0)
	f.minIncrement.g:SetPoint("BOTTOMRIGHT", f.minBid.g, "BOTTOMRIGHT", 102.5, 0)
	f.minIncrement:SetPoint("TOPRIGHT", f.minIncrement.g, "TOPLEFT")
	f.minIncrement:SetPoint("BOTTOMRIGHT", f.minIncrement.g, "BOTTOMLEFT")
	f.minIncrement.tex = f:CreateTexture(nil, "BACKGROUND")
	f.minIncrement.tex:SetPoint("TOPLEFT", f.minIncrement, 20, 0)
	f.minIncrement.tex:SetPoint("BOTTOMRIGHT", f.minIncrement.g, "BOTTOMRIGHT")
	f.minIncrement.tex:SetAlpha(0.2)
	f.minIncrement.tex:SetTexture(0.5, 0.5, 0.5)
	function f:SetItemID(itemID)
		if (not itemID) or (not MMMGdkp.opt.customItemSettings[itemID]) then
			self.itemicon:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
			self.minBid:SetText("")
			self.minIncrement:SetText("")
			self.itemID = nil
		else
			self.itemicon:SetNormalTexture((select(10, GetItemInfo(itemID))))
			if MMMGdkp.opt.customItemSettings[itemID].minBid then
				self.minBid:SetText(MMMGdkp.opt.customItemSettings[itemID].minBid)
			else
				self.minBid:SetText("")
			end
			if MMMGdkp.opt.customItemSettings[itemID].minIncrement then
				self.minIncrement:SetText(MMMGdkp.opt.customItemSettings[itemID].minIncrement)
			else
				self.minIncrement:SetText("")
			end
			self.itemID = itemID
		end
	end

	t[v] = f
	return f
end })
function itemsettings:Update()
	for _, btn in ipairs(self.entries) do btn:Hide() end
	local f = self.entries[1]
	f:Show()
	f:SetItemID()
	local c = 2
	for iID in pairs(MMMGdkp.opt.customItemSettings) do
		f = self.entries[c]
		f:Show()
		f:SetItemID(iID)
		c = c + 1
	end
	self.scroll.child:SetHeight(20 * (c - 1) - 5)
	self:SetHeight(70 + 20 * math.min(c - 1, 10))
end

itemsettings.hide = CreateFrame("Button", nil, itemsettings, "UIPanelButtonTemplate")
itemsettings.hide:SetSize(220, 15)
itemsettings.hide:SetPoint("BOTTOM", 0, 15)
itemsettings.hide:SetText(L["Hide"])
itemsettings.hide:SetScript("OnClick", function() itemsettings:Hide() end)
itemsettings.scroll:SetPoint("BOTTOMRIGHT", itemsettings.hide, "TOPRIGHT", 0, 10)
MMMGdkp.itemLevels = CreateFrame("Frame", "MMMGdkp_ItemLevels", UIParent, BackdropTemplateMixin and "BackdropTemplate")
local itemlevels = MMMGdkp.itemLevels
itemlevels:SetWidth(250)
itemlevels:Hide()
itemlevels:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
	tileSize = 32,
	edgeSize = 24,
	tile = true,
	insets = {
		top = 6,
		bottom = 6,
		right = 6,
		left = 6,
	},
})
itemlevels.header = CreateFrame("Button", nil, itemlevels)
itemlevels.header:SetNormalTexture("Interface\\DialogFrame\\UI-DialogBox-Gold-Header")
itemlevels.header:SetSize(133, 34)
itemlevels.header:SetHitRectInsets(31.5, 31.5, 4.5, 14.5)
itemlevels.header.text = itemlevels.header:CreateFontString()
itemlevels.header.text:SetPoint("TOP", 0, -7)
itemlevels.header.text:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
itemlevels.header.text:SetTextColor(1, 1, 1)
itemlevels.header.text:SetText(L["iLvL ranges"])
itemlevels.header:SetMovable(true)
itemlevels.header:SetScript("OnMouseDown", function(self)
	self:StartMoving()
end)
itemlevels.header:SetScript("OnMouseUp", function(self)
	self:StopMovingOrSizing()
end)
itemlevels.header:SetPoint("CENTER", UIParent, "CENTER")
itemlevels:SetPoint("TOP", itemlevels.header, "TOP", 0, -6)
itemlevels:SetScript("OnShow", function(self)
	self:Update()
end)
itemlevels.thead = CreateFrame("Frame", nil, itemlevels)
itemlevels.thead:SetPoint("TOPLEFT", 15, -15)
itemlevels.thead:SetPoint("TOPRIGHT", -15, -15)
itemlevels.thead:SetHeight(15)
itemlevels.thead.min = itemlevels.thead:CreateFontString()
itemlevels.thead.min:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
itemlevels.thead.min:SetTextColor(1, 0.82, 0)
itemlevels.thead.min:SetPoint("LEFT")
itemlevels.thead.min:SetWidth(25)
itemlevels.thead.min:SetText("Min")
itemlevels.thead.max = itemlevels.thead:CreateFontString()
itemlevels.thead.max:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
itemlevels.thead.max:SetTextColor(1, 0.82, 0)
itemlevels.thead.max:SetPoint("LEFT", itemlevels.thead.min, "RIGHT", 5, 0)
itemlevels.thead.max:SetWidth(25)
itemlevels.thead.max:SetText("Max")
itemlevels.thead.minbid = itemlevels.thead:CreateFontString()
itemlevels.thead.minbid:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
itemlevels.thead.minbid:SetTextColor(1, 0.82, 0)
itemlevels.thead.minbid:SetPoint("LEFT", itemlevels.thead.max, "RIGHT", 5, 0)
itemlevels.thead.minbid:SetWidth(60)
itemlevels.thead.minbid:SetText(L["Starting bid"])
itemlevels.thead.mininc = itemlevels.thead:CreateFontString()
itemlevels.thead.mininc:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
itemlevels.thead.mininc:SetTextColor(1, 0.82, 0)
itemlevels.thead.mininc:SetPoint("LEFT", itemlevels.thead.minbid, "RIGHT", 5, 0)
itemlevels.thead.mininc:SetWidth(80)
itemlevels.thead.mininc:SetText(L["Min increment"])
itemlevels.hide = CreateFrame("Button", nil, itemlevels, "UIPanelButtonTemplate")
itemlevels.hide:SetSize(220, 15)
itemlevels.hide:SetPoint("BOTTOM", 0, 15)
itemlevels.hide:SetText(L["Hide"])
itemlevels.hide:SetScript("OnClick", function() itemlevels:Hide() end)
itemlevels.add = CreateFrame("Frame", nil, itemlevels)
itemlevels.add:SetPoint("BOTTOMLEFT", 15, 35)
itemlevels.add:SetPoint("BOTTOMRIGHT", -15, 35)
itemlevels.add:SetHeight(20)
local tablist = { "MMMGdkpItemLevelFrameAddEditBoxMinItemLevel", "MMMGdkpItemLevelFrameAddEditBoxMaxItemLevel",
	"MMMGdkpItemLevelFrameAddEditBoxMinBid", "MMMGdkpItemLevelFrameAddEditBoxMinIncrement" }
local tabfunc = function(self) EditBox_HandleTabbing(self, tablist) end
itemlevels.add.min = CreateFrame("EditBox", "MMMGdkpItemLevelFrameAddEditBoxMinItemLevel", itemlevels.add,
	"InputBoxTemplate")
itemlevels.add.min:SetAutoFocus(false)
itemlevels.add.min:SetPoint("TOPLEFT", 2.5, 0)
itemlevels.add.min:SetPoint("BOTTOMLEFT", 2.5, 0)
itemlevels.add.min:SetWidth(25)
itemlevels.add.min:SetNumeric(true)
itemlevels.add.min:SetScript("OnEnterPressed", itemlevels.add.min:GetScript("OnEscapePressed"))
itemlevels.add.min:SetMaxLetters(3)
itemlevels.add.min:SetScript("OnTabPressed", tabfunc)
--itemlevels.add.min:SetJustifyH("RIGHT")
itemlevels.add.max = CreateFrame("EditBox", "MMMGdkpItemLevelFrameAddEditBoxMaxItemLevel", itemlevels.add,
	"InputBoxTemplate")
itemlevels.add.max:SetAutoFocus(false)
itemlevels.add.max:SetPoint("TOPLEFT", itemlevels.add.min, "TOPRIGHT", 5, 0)
itemlevels.add.max:SetPoint("BOTTOMLEFT", itemlevels.add.min, "BOTTOMRIGHT", 5, 0)
--itemlevels.add.max:SetPoint("TOPLEFT", 30, 0)
--itemlevels.add.max:SetPoint("BOTTOMLEFT", 30, 0)
itemlevels.add.max:SetWidth(25)
itemlevels.add.max:SetScript("OnEnterPressed", itemlevels.add.max:GetScript("OnEscapePressed"))
itemlevels.add.max:SetNumeric(true)
itemlevels.add.max:SetMaxLetters(3)
itemlevels.add.max:SetScript("OnTabPressed", tabfunc)
--itemlevels.add.max:SetJustifyH("RIGHT")
itemlevels.add.minbid = CreateFrame("EditBox", "MMMGdkpItemLevelFrameAddEditBoxMinBid", itemlevels.add, "InputBoxTemplate")
itemlevels.add.minbid:SetAutoFocus(false)
itemlevels.add.minbid:SetPoint("TOPLEFT", itemlevels.add.max, "TOPRIGHT", 5, 0)
itemlevels.add.minbid:SetPoint("BOTTOMLEFT", itemlevels.add.max, "BOTTOMRIGHT", 5, 0)
itemlevels.add.minbid:SetWidth(60)
itemlevels.add.minbid:SetScript("OnEnterPressed", itemlevels.add.minbid:GetScript("OnEscapePressed"))
itemlevels.add.minbid:SetNumeric(true)
itemlevels.add.minbid:SetMaxLetters(6)
itemlevels.add.minbid:SetScript("OnTabPressed", tabfunc)
--itemlevels.add.minbid:SetJustifyH("RIGHT")
itemlevels.add.mininc = CreateFrame("EditBox", "MMMGdkpItemLevelFrameAddEditBoxMinIncrement", itemlevels.add,
	"InputBoxTemplate")
itemlevels.add.mininc:SetAutoFocus(false)
itemlevels.add.mininc:SetPoint("TOPLEFT", itemlevels.add.minbid, "TOPRIGHT", 5, 0)
itemlevels.add.mininc:SetPoint("BOTTOMLEFT", itemlevels.add.minbid, "BOTTOMRIGHT", 5, 0)
itemlevels.add.mininc:SetWidth(80)
itemlevels.add.mininc:SetScript("OnEnterPressed", itemlevels.add.mininc:GetScript("OnEscapePressed"))
itemlevels.add.mininc:SetNumeric(true)
itemlevels.add.mininc:SetMaxLetters(5)
itemlevels.add.mininc:SetScript("OnTabPressed", tabfunc)
--itemlevels.add.mininc:SetJustifyH("RIGHT")
itemlevels.add.add = CreateFrame("Button", nil, itemlevels.add)
itemlevels.add.add:SetSize(20, 20)
itemlevels.add.add:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
itemlevels.add.add:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
itemlevels.add.add:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-DOWN")
itemlevels.add.add:SetPoint("RIGHT", 5, 0)
itemlevels.add.add:SetScript("OnClick", function()
	local minl = itemlevels.add.min:GetNumber()
	local maxl = itemlevels.add.max:GetNumber()
	local minbid = itemlevels.add.minbid:GetNumber()
	local mininc = itemlevels.add.mininc:GetNumber()
	if minbid ~= 0 and mininc ~= 0 then
		tinsert(MMMGdkp.opt.itemLevelPricing, { min = minl, max = maxl, minbid = minbid, mininc = mininc })
		itemlevels:Update()
		itemlevels.add.min:SetText("")
		itemlevels.add.max:SetText("")
		itemlevels.add.minbid:SetText("")
		itemlevels.add.mininc:SetText("")
	end
end)
itemlevels.entries = setmetatable({}, { __index = function(t, v)
	local f = CreateFrame("Frame", nil, itemlevels)
	if v > 1 then
		f:SetPoint("TOPLEFT", t[v - 1], "BOTTOMLEFT", 0, -5)
		f:SetPoint("TOPRIGHT", t[v - 1], "BOTTOMRIGHT", 0, -5)
	else
		f:SetPoint("TOPLEFT", itemlevels.thead, "BOTTOMLEFT", 0, -5)
		f:SetPoint("TOPRIGHT", itemlevels.thead, "BOTTOMRIGHT", 0, -5)
	end
	f:SetHeight(15)
	f.min = f:CreateFontString()
	f.min:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
	f.min:SetTextColor(1, 1, 1)
	f.min:SetPoint("LEFT")
	f.min:SetWidth(25)
	f.min:SetJustifyH("RIGHT")
	f.max = f:CreateFontString()
	f.max:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
	f.max:SetTextColor(1, 1, 1)
	f.max:SetPoint("LEFT", f.min, "RIGHT", 5, 0)
	f.max:SetWidth(25)
	f.max:SetJustifyH("RIGHT")
	f.minbid = f:CreateFontString()
	f.minbid:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
	f.minbid:SetTextColor(1, 1, 1)
	f.minbid:SetPoint("LEFT", f.max, "RIGHT", 5, 0)
	f.minbid:SetWidth(60)
	f.minbid:SetJustifyH("RIGHT")
	f.mininc = f:CreateFontString()
	f.mininc:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
	f.mininc:SetTextColor(1, 1, 1)
	f.mininc:SetPoint("LEFT", f.minbid, "RIGHT", 5, 0)
	f.mininc:SetWidth(80)
	f.mininc:SetJustifyH("RIGHT")
	function f:SetValues(min, max, minbid, mininc)
		self.min:SetText(min)
		self.max:SetText(max)
		self.minbid:SetText(minbid .. "|cffffd100g|r")
		self.mininc:SetText(mininc .. "|cffffd100g|r")
	end

	f.del = CreateFrame("Button", nil, f)
	f.del:SetSize(15, 15)
	f.del:SetPoint("RIGHT", 5, 0)
	f.del:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-UP")
	--minus uses pluses' highlight
	f.del:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
	f.del:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-DOWN")
	f.del:SetScript("OnClick", function()
		tremove(MMMGdkp.opt.itemLevelPricing, v)
		itemlevels:Update()
	end)
	t[v] = f
	return f
end })
function itemlevels:Update()
	--self:SetHeight(100)
	-- 30 borders
	-- 5 list
	-- 15 thead
	for _, f in ipairs(self.entries) do f:Hide() end
	local height = 95
	for num, data in ipairs(MMMGdkp.opt.itemLevelPricing) do
		local f = self.entries[num]
		f:Show()
		f:SetValues(data.min, data.max, data.minbid, data.mininc)
		height = height + 20
	end
	self:SetHeight(height)
end

MMMGdkp.version = CreateFrame("Frame", "MMMGdkp_Versions", UIParent, BackdropTemplateMixin and "BackdropTemplate")
local version = MMMGdkp.version
version:SetSize(200, 85)
version:Hide()
version:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
	tileSize = 32,
	edgeSize = 24,
	tile = true,
	insets = {
		top = 6,
		bottom = 6,
		right = 6,
		left = 6,
	},
})
version.header = CreateFrame("Button", nil, version)
version.header:SetNormalTexture("Interface\\DialogFrame\\UI-DialogBox-Gold-Header")
version.header:SetSize(133, 34)
version.header:SetHitRectInsets(31.5, 31.5, 4.5, 14.5)
version.header.text = version.header:CreateFontString()
version.header.text:SetPoint("TOP", 0, -7)
version.header.text:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
version.header.text:SetTextColor(1, 1, 1)
version.header.text:SetText(L["Versions"])
version.header:SetMovable(true)
version.header:SetScript("OnMouseDown", function(self)
	self:StartMoving()
end)
version.header:SetScript("OnMouseUp", function(self)
	self:StopMovingOrSizing()
end)
version.header:SetPoint("CENTER", UIParent, "CENTER")
version:SetPoint("TOP", version.header, "TOP", 0, -6)
version:SetScript("OnShow", function(self)
	self:Update()
end)
version.entries = setmetatable({}, { __index = function(t, v)
	local f = CreateFrame("Button", nil, version)
	if v > 1 then
		f:SetPoint("TOPLEFT", t[v - 1], "BOTTOMLEFT", 0, -5)
		f:SetPoint("TOPRIGHT", t[v - 1], "BOTTOMRIGHT", 0, -5)
	else
		f:SetPoint("TOPLEFT", 15, -15)
		f:SetPoint("TOPRIGHT", -15, -15)
	end
	function f:UpdateHeight()
		self:SetHeight(f.name:GetHeight())
	end

	f.name = f:CreateFontString()
	f.name:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
	f.name:SetTextColor(1, 1, 1)
	f.name:SetPoint("TOPLEFT")
	f.name:SetWidth(110)
	f.name:SetJustifyH("LEFT")
	f.version = f:CreateFontString()
	f.version:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
	f.version:SetPoint("BOTTOMLEFT", f.name, "BOTTOMRIGHT", 5, 0)
	f.version:SetPoint("TOPRIGHT")
	f.version:SetJustifyH("LEFT")
	function f:SetVersion(name, versionstring)
		if not versionstring then
			f.version:SetTextColor(0.8, 0, 0)
			f.name:SetText(name)
			f.version:SetText("n/A")
			f.status = "not_installed"
			MMMGdkp.version.notify:Enable()
			self:UpdateHeight()
			return
		end
		if versionstring == (DEBUGFORCEVERSION or "2.0.0") then
			f.version:SetTextColor(0, 0.8, 0)
			f.name:SetText(name)
			f.version:SetText(versionstring)
			f.status = "updated"
		elseif COMPATIBLE_VERSIONS[versionstring] then
			f.version:SetTextColor(0.8, 0.8, 0)
			f.name:SetText(name)
			f.version:SetText(versionstring)
			f.status = "outdated_compatible"
			MMMGdkp.version.notify:Enable()
		elseif INCOMPATIBLE_VERSIONS[versionstring] then
			f.version:SetTextColor(0.8, 0, 0)
			f.name:SetText(name)
			f.version:SetText(versionstring)
			f.status = "outdated_incompatible"
			MMMGdkp.version.notify:Enable()
		else
			f.version:SetTextColor(0.3, 0.3, 1)
			f.name:SetText(name)
			f.version:SetText(versionstring)
			f.status = "self_outdated"
		end
		self:UpdateHeight()
	end

	f:SetScript("OnEnter", function(self)
		GameTooltip:ClearAllPoints()
		GameTooltip:ClearLines()
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		GameTooltip:AddLine(L["Version status for player %s"]:format(self.name:GetText()))
		if self.status == "updated" then
			GameTooltip:AddLine(L["This player has the same version of MMMGdkp as you do. Full compability is ensured."])
		elseif self.status == "outdated_compatible" then
			GameTooltip:AddLine(L[
				"This player's version of MMMGdkp is outdated. However, their version should be fully compatible with yours."])
		elseif self.status == "outdated_incompatible" then
			GameTooltip:AddLine(L[
				"This player's version of MMMGdkp is outdated and one or more functionalities are not compatible:"])
			for _, incompatible_string in ipairs(INCOMPATIBLE_VERSIONS[f.version:GetText()]) do
				GameTooltip:AddLine(" - " .. VERSIONING_STRINGS[incompatible_string])
			end
		elseif self.status == "self_outdated" then
			GameTooltip:AddLine(L[
				"This player's version of MMMGdkp is more advanced than yours. Please consult your Curse Client for updates or manually check the curse.com page."
				])
		elseif self.status == "not_installed" then
			GameTooltip:AddLine(L[
				"This player does not have MMMGdkp running or his version of MMMGdkp does not yet support version checks."])
		end
		GameTooltip:SetPoint("TOPRIGHT", self, "LEFT", -5, 0)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)
	t[v] = f
	return f
end })
version.hide = CreateFrame("Button", nil, version, "UIPanelButtonTemplate")
version.hide:SetSize(170, 15)
version.hide:SetPoint("BOTTOM", 0, 15)
version.hide:SetText(L["Hide"])
version.hide:SetScript("OnClick", function() version:Hide() end)
version.notify = CreateFrame("Button", nil, version, "UIPanelButtonTemplate")
version.notify:SetSize(170, 15)
version.notify:SetPoint("BOTTOM", version.hide, "TOP", 0, 5)
version.notify:SetText(L["Notify outdated versions"])
version.notify:SetScript("OnClick", function()
	local c = 1
	local f = rawget(version.entries, c)
	while (f and f:IsShown()) do
		if f.status == "outdated_compatible" and MMMGdkp.opt.notifyVersions.notifyCompatibleOutdated then
			SendChatMessage(L[
				"Your version of MMMGdkp is slightly outdated compared to the raid leader's. Full compability should be possible, however, you might want to take some time and update MMMGdkp."
				], "WHISPER", nil, f.name:GetText())
		elseif f.status == "outdated_incompatible" and MMMGdkp.opt.notifyVersions.notifyIncompatibleOutdated then
			SendChatMessage(L[
				"Your version of MMMGdkp is outdated and no longer compatible with the raid leader's in one or more functionalities. In order to ensure smooth performance, please update MMMGdkp."
				], "WHISPER", nil, f.name:GetText())
		elseif f.status == "not_installed" and MMMGdkp.opt.notifyVersions.notifyNotInstalled then
			SendChatMessage(L[
				"This raid uses MMMGdkp to faciliate its GDKP bidding process. While you can bid on items without having MMMGdkp installed, installing it provides you with a GUI bidding panel, auto bidding functions, auction timers, chat filtering and more!"
				], "WHISPER", nil, f.name:GetText())
		end
		c = c + 1
		f = rawget(version.entries, c)
	end
end)
version.notify:Disable()
version.request = CreateFrame("Button", nil, version, "UIPanelButtonTemplate")
version.request:SetSize(170, 15)
version.request:SetPoint("BOTTOM", version.notify, "TOP", 0, 5)
version.request:SetText(L["Request version data"])
version.request:SetScript("OnClick",
	function() MMMGdkp.hasRequestedData = true SendAddonMessage("MMMGdkp VREQ", "poptix", "RAID") end)
function version:Update()
	if not MMMGdkp.hasRequestedData then return end
	for _, f in ipairs(self.entries) do
		f:Hide()
	end
	self.notify:Disable()
	local size = 85
	for numRaid = 1, GetNumGroupMembers() do
		local pName = UnitName("raid" .. numRaid)
		local f = self.entries[numRaid]
		f:Show()
		f:SetVersion(pName, MMMGdkp.versions[pName])
		size = size + f:GetHeight() + 5
	end
	self:SetHeight(size)
end

function MMMGdkp:MailBalanceGold(targetName)
	local moneyToMail = MMMGdkp_PotData.playerBalance[targetName]
	if moneyToMail <= 0 then return end
	ClearSendMail()
	SetSendMailMoney(moneyToMail * 10000)
	SendMail(targetName, "<MMMGdkp> " .. moneyToMail .. " gold")
	MMMGdkp_PotData.playerBalance[targetName] = 0
	self.balance:Update()
end

MMMGdkp.balance = CreateFrame("Frame", "MMMGdkp_PlayerBalance", status, BackdropTemplateMixin and "BackdropTemplate")
local balance = MMMGdkp.balance
balance:SetSize(200, 95)
balance:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
	tileSize = 32,
	edgeSize = 24,
	tile = true,
	insets = {
		top = 6,
		bottom = 6,
		right = 6,
		left = 6,
	},
})
balance.header = CreateFrame("Button", nil, balance)
balance.header:SetNormalTexture("Interface\\DialogFrame\\UI-DialogBox-Gold-Header")
balance.header:SetSize(133, 34)
balance.header:SetHitRectInsets(31.5, 31.5, 4.5, 14.5)
balance.header.text = balance.header:CreateFontString()
balance.header.text:SetPoint("TOP", 0, -7)
balance.header.text:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
balance.header.text:SetTextColor(1, 1, 1)
balance.header.text:SetText(L["Balance"])
balance.header:SetMovable(true)
balance.header:SetScript("OnMouseDown", function(self)
	if self:IsMovable() then
		self:StartMoving()
	end
end)
balance.header:SetScript("OnMouseUp", function(self)
	if self:IsMovable() then
		self:StopMovingOrSizing()
		MMMGdkp.opt.balancepoint.point, _, MMMGdkp.opt.balancepoint.relative, MMMGdkp.opt.balancepoint.x, MMMGdkp.opt.balancepoint.y = self
			:GetPoint()
	end
end)
balance:SetPoint("TOP", balance.header, "TOP", 0, -6)
balance:SetScript("OnShow", function(self)
	self:Update()
end)
balance.entries = setmetatable({}, { __index = function(t, v)
	local f = CreateFrame("Button", nil, balance)
	if v > 1 then
		f:SetPoint("TOPLEFT", t[v - 1], "BOTTOMLEFT", 0, -5)
		f:SetPoint("TOPRIGHT", t[v - 1], "BOTTOMRIGHT", 0, -5)
	else
		f:SetPoint("TOPLEFT", 15, -35)
		f:SetWidth(170)
	end
	function f:UpdateHeight()
		self:SetHeight(math.max(self.name:GetHeight(), self.amount:GetHeight()))
	end

	f.name = f:CreateFontString()
	f.name:SetPoint("TOPLEFT")
	f.name:SetPoint("BOTTOMLEFT")
	f.name:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
	f.name:SetTextColor(1, 1, 1)
	f.name:SetJustifyH("LEFT")
	f.amount = f:CreateFontString()
	f.amount:SetPoint("TOPLEFT", f.name, "TOPRIGHT", 5, 0)
	f.amount:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
	f.amount:SetTextColor(1, 1, 1)
	f.amount:SetJustifyH("RIGHT")
	f.add = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.add:SetSize(15, 15)
	f.add:SetText("+")
	f.add:SetScript("OnClick", function(self)
		StaticPopup_Show("MMMGdkp_ADDTOPLAYER", f.name:GetText()).data = f.name:GetText()
	end)
	f.rem = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.rem:SetSize(15, 15)
	f.rem:SetText("-")
	f.rem:SetScript("OnClick", function(self)
		StaticPopup_Show("MMMGdkp_REMFROMPLAYER", f.name:GetText()).data = f.name:GetText()
	end)
	--f.rem:SetPoint("TOPRIGHT")
	f.rem:SetPoint("RIGHT")
	f.add:SetPoint("RIGHT", f.rem, "LEFT")
	--f.add:SetPoint("BOTTOMRIGHT", f.rem, "BOTTOMLEFT")
	f.amount:SetPoint("BOTTOMRIGHT", f.add, "BOTTOMLEFT")
	function f.amount:SetAmount(gAmount)
		if gAmount > 0 then
			self:SetText("|cff00ff00" .. gAmount .. "|r|cffffd100g|r")
		elseif gAmount < 0 then
			self:SetText("|cffff0000" .. gAmount .. "|r|cffffd100g|r")
		else
			self:SetText("0|cffffd100g|r")
		end
	end

	f.mail = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.mail:SetSize(40, 15)
	f.mail:SetText(L["Mail"])
	f.mail:SetScript("OnClick", function(self)
		local targetName = f.name:GetText()
		if MMMGdkp.opt.confirmMail then
			StaticPopup_Show("MMMGdkp_MAILGOLD", MMMGdkp_PotData.playerBalance[targetName], targetName).data = targetName
		else
			MMMGdkp:MailBalanceGold(targetName)
		end
	end)
	function f.mail:UpdateState()
		local shouldDisable = (not MailFrame) or (not MailFrame:IsShown())
		shouldDisable = shouldDisable or (MMMGdkp_PotData.playerBalance[f.name:GetText()] <= 0)
		if shouldDisable then
			self:Disable()
			return false
		else
			self:Enable()
			return true
		end
	end

	f.mail:SetPoint("LEFT", f.rem, "RIGHT", 5, 0)
	t[v] = f
	return f
end })
function balance:UpdatePosition()
	local f = self.header
	f:ClearAllPoints()
	if not MMMGdkp.opt.anchorBalance then
		f:SetPoint(MMMGdkp.opt.balancepoint.point, UIParent, MMMGdkp.opt.balancepoint.relative, MMMGdkp.opt.balancepoint.x,
			MMMGdkp.opt.balancepoint.y)
		f:SetMovable(true)
	else
		f:SetPoint("TOP", status, "BOTTOM", 0, -15)
		f:StopMovingOrSizing()
		f:SetMovable(false)
	end
end

function balance:Update()
	for _, f in ipairs(self.entries) do
		f:Hide()
	end
	local c = 1
	local size = 50
	local isWidthIncreased = false
	if (MMMGdkp.isTrading) then
		local f = self.entries[c]
		f:Show()
		f.amount:SetAmount(MMMGdkp_PotData.playerBalance[(UnitName("NPC"))])
		--MoneyInputFrame_SetCopper(TradePlayerInputMoneyFrame, (MMMGdkp_PotData.playerBalance[(UnitName("NPC"))] * 10000));
		f.name:SetText((UnitName("NPC")))
		f:UpdateHeight()
		isWidthIncreased = f.mail:UpdateState() or isWidthIncreased
		c = c + 1
		size = size + f:GetHeight() + 5
	end
	for name, amount in pairs(MMMGdkp_PotData.playerBalance) do
		if ((not MMMGdkp.isTrading) or (name ~= (UnitName("NPC")))) and (amount ~= 0) and (name ~= (UnitName("player"))) then
			local f = self.entries[c]
			f:Show()
			f.name:SetText(name)
			f.amount:SetAmount(amount)
			f:UpdateHeight()
			isWidthIncreased = f.mail:UpdateState() or isWidthIncreased
			c = c + 1
			size = size + f:GetHeight() + 5
		end
	end
	self:SetHeight(size)
	if size == 50 then
		self:Hide()
	else
		self:Show()
	end
	if isWidthIncreased then
		for _, f in ipairs(self.entries) do
			f.mail:Show()
		end
		self:SetWidth(245)
	else
		for _, f in ipairs(self.entries) do
			f.mail:Hide()
		end
		self:SetWidth(200)
	end
end

MMMGdkp.playerBalance = CreateFrame("Frame", "MMMGdkp_PlayerBalance", UIParent, BackdropTemplateMixin and "BackdropTemplate")
local playerBalance = MMMGdkp.playerBalance
playerBalance:SetSize(200, 95)
playerBalance:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
	tileSize = 32,
	edgeSize = 24,
	tile = true,
	insets = {
		top = 6,
		bottom = 6,
		right = 6,
		left = 6,
	},
})
playerBalance.header = CreateFrame("Button", nil, playerBalance)
playerBalance.header:SetNormalTexture("Interface\\DialogFrame\\UI-DialogBox-Gold-Header")
playerBalance.header:SetSize(133, 34)
playerBalance.header:SetHitRectInsets(31.5, 31.5, 4.5, 14.5)
playerBalance.header.text = playerBalance.header:CreateFontString()
playerBalance.header.text:SetPoint("TOP", 0, -7)
playerBalance.header.text:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
playerBalance.header.text:SetTextColor(1, 1, 1)
playerBalance.header.text:SetText(L["Player balance"])
playerBalance.header:SetMovable(true)
playerBalance.header:SetScript("OnMouseDown", function(self)
	self:StartMoving()
end)
playerBalance.header:SetScript("OnMouseUp", function(self)
	self:StopMovingOrSizing()
	MMMGdkp.opt.playerbalancepoint.point, _, MMMGdkp.opt.playerbalancepoint.relative, MMMGdkp.opt.playerbalancepoint.x,
		MMMGdkp.opt.playerbalancepoint.y = self:GetPoint()
end)
playerBalance:SetPoint("TOP", playerBalance.header, "TOP", 0, -6)
playerBalance:SetScript("OnShow", function(self)
	self:Update()
end)
playerBalance.reset = CreateFrame("Button", nil, playerBalance, "UIPanelButtonTemplate")
playerBalance.reset:SetSize(170, 15)
playerBalance.reset:SetPoint("BOTTOM", 0, 15)
playerBalance.reset:SetText(RESET)
playerBalance.reset:SetScript("OnClick",
	function() MMMGdkp_BalanceData = setmetatable({}, { __index = function() return 0 end }) MMMGdkp.playerBalance:Update() end)
playerBalance.entries = setmetatable({}, { __index = function(t, v)
	local f = CreateFrame("Button", nil, playerBalance)
	if v > 1 then
		f:SetPoint("TOPLEFT", t[v - 1], "BOTTOMLEFT", 0, -5)
		f:SetPoint("TOPRIGHT", t[v - 1], "BOTTOMRIGHT", 0, -5)
	else
		f:SetPoint("TOPLEFT", 15, -15)
		f:SetPoint("TOPRIGHT", -15, -15)
	end
	function f:UpdateHeight()
		self:SetHeight(math.max(self.name:GetHeight(), self.amount:GetHeight()))
	end

	f.name = f:CreateFontString()
	f.name:SetPoint("TOPLEFT")
	f.name:SetPoint("BOTTOMLEFT")
	f.name:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
	f.name:SetTextColor(1, 1, 1)
	f.name:SetJustifyH("LEFT")
	f.amount = f:CreateFontString()
	f.amount:SetPoint("TOPLEFT", f.name, "TOPRIGHT", 5, 0)
	f.amount:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
	f.amount:SetTextColor(1, 1, 1)
	f.amount:SetJustifyH("RIGHT")
	f.amount:SetPoint("BOTTOMRIGHT")
	function f.amount:SetAmount(gAmount)
		if gAmount > 0 then
			self:SetText("|cff00ff00" .. gAmount .. "|r|cffffd100g|r")
		elseif gAmount < 0 then
			self:SetText("|cffff0000" .. gAmount .. "|r|cffffd100g|r")
		else
			self:SetText("0|cffffd100g|r")
		end
	end

	t[v] = f
	return f
end })
function playerBalance:UpdateVisibility(forceCombat)
	if MMMGdkp.opt.hide then
		self:Hide()
		return
	end
	if (self:GetHeight() > 50) and
		((not MMMGdkp.opt.hideCombat.status) or (not (forceCombat ~= nil and forceCombat or InCombatLockdown()))) then
		self:Show()
	else
		self:Hide()
	end
end

function playerBalance:Update()
	for _, f in ipairs(self.entries) do
		f:Hide()
	end
	local c = 1
	local size = 45
	if (MMMGdkp.isTrading) then
		local f = self.entries[c]
		f:Show()
		f.amount:SetAmount(MMMGdkp_BalanceData[(UnitName("NPC"))])
		f.name:SetText((UnitName("NPC")))
		f:UpdateHeight()
		c = c + 1
		size = size + f:GetHeight() + 5
	end
	for name, amount in pairs(MMMGdkp_BalanceData) do
		if ((not MMMGdkp.isTrading) or (name ~= (UnitName("NPC")))) and (amount ~= 0) and (name ~= (UnitName("player"))) then
			local f = self.entries[c]
			f:Show()
			f.name:SetText(name)
			f.amount:SetAmount(amount)
			f:UpdateHeight()
			c = c + 1
			size = size + f:GetHeight() + 5
		end
	end
	self:SetHeight(size)
	self:UpdateVisibility()
end

MMMGdkp.exportframe = CreateFrame("Frame", "MMMGdkp_Export", UIParent, BackdropTemplateMixin and "BackdropTemplate")
local export = MMMGdkp.exportframe
export:Hide()
export:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
	tileSize = 32,
	edgeSize = 24,
	tile = true,
	insets = {
		top = 6,
		bottom = 6,
		right = 6,
		left = 6,
	},
})
export.header = CreateFrame("Button", nil, export)
export.header:SetNormalTexture("Interface\\DialogFrame\\UI-DialogBox-Gold-Header")
export.header:SetSize(133, 34)
export.header:SetHitRectInsets(31.5, 31.5, 4.5, 14.5)
export.header.text = export.header:CreateFontString()
export.header.text:SetPoint("TOP", 0, -7)
export.header.text:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
export.header.text:SetTextColor(1, 1, 1)
export.header.text:SetText(L["Pot export"])
export.header:SetMovable(true)
export.header:SetScript("OnMouseDown", function(self)
	self:StartMoving()
end)
export.header:SetScript("OnMouseUp", function(self)
	self:StopMovingOrSizing()
end)
export.header:SetPoint("TOP", history, "BOTTOM", 0, -10)
export.box = CreateFrame("EditBox", nil, export)
export.box:SetMultiLine(true)
export.box:SetAutoFocus(false)
export.box:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
export.box:SetPoint("TOP", export.header, "TOP", 0, -21)
export.box:SetJustifyH("LEFT")
export.box:SetWidth(50)
do
	local st = export.box.SetText
	local dummy_text = UIParent:CreateFontString()
	dummy_text:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
	function export.box:SetText(text)
		dummy_text:SetText(text)
		self:SetWidth(dummy_text:GetStringWidth())
		self.text = text
		st(self, text)
	end
end
export.box:SetScript("OnTextChanged", function(self, userInput)
	if userInput then
		self:SetText(self.text or "")
	end
	self:HighlightText()
	self:SetFocus()
end)
export.box:SetScript("OnEscapePressed", function(self)
	self:ClearFocus()
	export:Hide()
end)
export.box:SetScript("OnEnterPressed", function(self)
	self:ClearFocus()
end)
export:SetPoint("TOPLEFT", export.box, "TOPLEFT", -15, 15)
export:SetPoint("BOTTOMRIGHT", export.box, "BOTTOMRIGHT", 15, -15)

export.toggleBB = CreateFrame("Button", nil, export, "UIPanelButtonTemplate")
export.toggleBB:SetSize(150, 20)
export.toggleBB:SetPoint("TOP", export, "BOTTOM", 0, 10)
export.toggleBB:SetText("BBCode")
export.toggleBB:SetScript("OnClick", function() export:SetType('BB') end)

export.toggleDefault = CreateFrame("Button", nil, export, "UIPanelButtonTemplate")
export.toggleDefault:SetSize(150, 20)
export.toggleDefault:SetPoint("RIGHT", export.toggleBB, "LEFT")
export.toggleDefault:SetText("Tab Delimited")
export.toggleDefault:SetScript("OnClick", function() export:SetType('Default') end)

export.toggleBN = CreateFrame("Button", nil, export, "UIPanelButtonTemplate")
export.toggleBN:SetSize(150, 20)
export.toggleBN:SetPoint("LEFT", export.toggleBB, "RIGHT")
export.toggleBN:SetText("Battle.net forums")
export.toggleBN:SetScript("OnClick", function() export:SetType('BN') end)

function export:Update()
	local text = self.header
	for _, aucdata in ipairs(self.data) do
		if type(aucdata) == "table" then
			if self.exportType == "BB" then
				text = text ..
					"\n[color=#" ..
					aucdata.item:match("|c[fF][fF]([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])") ..
					"][url=http://www.wowhead.com/item=" ..
					aucdata.item:match("|Hitem:(%d+):") ..
					"]" .. (aucdata.item:match("(|h.+|h)")) .. "[/url][/color]: " .. aucdata.name .. " (" .. aucdata.bid .. " gold)"
			elseif self.exportType == "BN" then
				text = text ..
					"\n[item=\"" .. aucdata.item:match("|Hitem:(%d+):") .. "\" /]: " .. aucdata.name .. " (" .. aucdata.bid .. " gold)"
			else
				text = text ..
					"\n=HYPERLINK(\"http://classic.wowhead.com/item=" ..
					(aucdata.item:match("|Hitem:(%d+):")) ..
					"\",\"" .. aucdata.item:match("(|h.+|h)") .. "\")\t" .. aucdata.name .. "\t" .. aucdata.bid
			end
		else
			text = text .. "\n" .. L["Manual adjustment"] .. ": " .. (aucdata > 0 and "+" or "") .. aucdata .. " gold"
		end
	end
	self.box:SetText(text)
end

function export:Set(header, data)
	self.header = header
	self.data = data
	self:Update()
end

function export:SetType(t)
	self["toggle" .. self.exportType]:UnlockHighlight()
	self.exportType = t
	self["toggle" .. t]:LockHighlight()
	self:Update()
end

export.exportType = "Default"
export.toggleDefault:LockHighlight()

function MMMGdkp:SetMovable(movable)
	if movable then
		anchor:EnableMouse(true)
		anchor:Show()
	else
		anchor:EnableMouse(false)
		anchor:Hide()
	end
end

function MMMGdkp:GetStartBid(id, customStartPrice)
	if customStartPrice then
		return customStartPrice
	end
	local ilvl = (select(4, GetItemInfo(id)))
	if self.opt.customItemSettings[id] then
		return self.opt.customItemSettings[id].minBid
	end
	if ilvl then
		for _, d in ipairs(self.opt.itemLevelPricing) do
			if (d.min <= ilvl) and (d.max >= ilvl) then
				return d.minbid
			end
		end
	end
	
	return self.opt.startBid
end

function MMMGdkp:GetMinIncrement(id)
	local ilvl = (select(4, GetItemInfo(id)))
	if self.opt.customItemSettings[id] then
		return self.opt.customItemSettings[id].minIncrement
	end
	if ilvl then
		for _, d in ipairs(self.opt.itemLevelPricing) do
			if (d.min <= ilvl) and (d.max >= ilvl) then
				return d.mininc
			end
		end
	end
	return self.opt.increment
end

function MMMGdkp:FetchFrameFromLink(itemLink)
	for num, frame in ipairs(MMMGdkp.frames) do
		if (frame.itemlink == itemLink) and frame.isActive then
			return frame, num
		end
	end
end

function MMMGdkp:PlayerIsML(playerName, invert)
	for raidID = (invert and GetNumGroupMembers() or 1), (invert and 1 or GetNumGroupMembers()), (invert and -1 or 1) do
		local name, _, _, _, _, _, _, _, _, _, isML = GetRaidRosterInfo(raidID)
		if playerName == name then
			return isML
		end
	end
end

function MMMGdkp:AnnounceLoot(shouldQueueAuctions)
	if GetNumLootItems() <= 0 then return end
	local lootList = emptytable()
	local minQuality = (self.opt.minQuality == -1 and GetLootThreshold() or self.opt.minQuality)
	local playerName = (UnitName("player"))
	for numLoot = 1, GetNumLootItems() do
		if LootSlotIsItem(numLoot) then
			local tex, item, quantity, currency, quality, isLocked = GetLootSlotInfo(numLoot)
			if quality >= minQuality then
				tinsert(lootList, GetLootSlotLink(numLoot))
				if self.opt.awardToML then
					local candidateIndex = 1
					local candidateName = GetMasterLootCandidate(numLoot, candidateIndex)
					while candidateName do
						if candidateName == playerName then
							GiveMasterLoot(numLoot, candidateIndex)
							break
						end
						candidateIndex = candidateIndex + 1
						candidateName = GetMasterLootCandidate(numLoot, candidateIndex)
					end
				end
			end
		end
	end
	local lootString = L["Loot dropped: "] .. lootList[1]
	for lootNum, link in ipairs(lootList) do
		if lootNum > 1 then
			if strlen(lootString) + strlen(link) + 2 > 255 then
				SendChatMessage(lootString, "RAID_WARNING")
				lootString = link
			else
				lootString = lootString .. ", " .. link
			end
		end
	end
	SendChatMessage(lootString, "RAID_WARNING")
	for _, item in ipairs(lootList) do
		if shouldQueueAuctions then
			local itemID = tonumber(item:match("|Hitem:(%d+):"))
			--local iLvL = (select(4, GetItemInfo(itemID)))
			--local startBid = (MMMGdkp.opt.customItemSettings[itemID] and MMMGdkp.opt.customItemSettings[itemID].minBid) or  or self.opt.startBid
			--local increment = (MMMGdkp.opt.customItemSettings[itemID] and MMMGdkp.opt.customItemSettings[itemID].minIncrement) or self.opt.increment
			--MMMGdkp:QueueAuction(item, startBid, increment)
			MMMGdkp:QueueAuction(item, MMMGdkp:GetStartBid(itemID), MMMGdkp:GetMinIncrement(itemID))
		else
			--SendAddonMessage("MMMGdkp START", item, "RAID")
		end
	end
	lootList:Release()
end

function QueueAuctionOS(item, minbid, increment)
	if (not MMMGdkp.curAuction.item) or MMMGdkp.opt.allowMultipleAuctions then
		MMMGdkp:AuctionOffItem(item, minbid, increment, true)
	else
		SendAddonMessage("MMMGdkp START", item, "RAID")
		tinsert(MMMGdkp.auctionList, emptytable(item, minbid, increment))
	end
end

function MMMGdkp:QueueAuction(item, minbid, increment)
	if (not MMMGdkp.curAuction.item) or MMMGdkp.opt.allowMultipleAuctions then
		MMMGdkp:AuctionOffItem(item, minbid, increment, false)
	else
		SendAddonMessage("MMMGdkp START", item, "RAID")
		tinsert(MMMGdkp.auctionList, emptytable(item, minbid, increment))
	end
end

function MMMGdkp:AuctionOffItem(item, minbid, increment, os)
	if (MMMGdkp.curAuction.item) and (not self.opt.allowMultipleAuctions) then return end
	if (self.opt.allowMultipleAuctions) and (self.curAuctions[item]) then return end
	if (not self.opt.allowMultipleAuctions) then
		-- old code
	else
		-- new code
		local itemId = GetItemInfoFromHyperlink(item)
		local maxBid = MaxBidSmall
		local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType,
		itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType,
		expacID, setID, isCraftingReagent = GetItemInfo(itemId) 
		local inventoryType = C_Item.GetItemInventoryTypeByID(itemId)
		if (itemLevel == 238) then
			minbid = 4000
			maxBid = 15000
		elseif (itemLevel == 252) then
			minbid = 5000
			maxBid = 25000
		elseif (itemQuality == 4 and itemLevel == 80) then
			minbid = 2500
			maxBid = 10000
		elseif (inventoryType == 12) then
			minbid = 4000
			maxBid = 15000
		else
			minbid = 1000
			maxBid = 5000
		end
		if (LargeBidItems[itemId]) then
			maxBid = LargeBidItems[itemId]
		end
		if os then
			minbid = minbid / 2
		end

		MMMGdkp_ProcessingItems[itemId] = {}
		MMMGdkp_ProcessingItems[itemId].itemLink = itemLink
		MMMGdkp_ProcessingItems[itemId].maxRoll = 0
		SendChatMessage((
			"Bidding starts on %s. Starting bid %dg, minimum increment %dg. Maximum bid %dg. TTL: %d/%d"):
			format(item, minbid, increment, maxBid, self.opt.auctionTimer, self.opt.auctionTimerRefresh),
			(self.opt.announceRaidWarning and (IsRaidOfficer() or IsRaidLeader())) and "RAID_WARNING" or "RAID")
		local aucTable = emptytable()
		aucTable.item = item
		aucTable.curBid = (minbid - increment)
		aucTable.increment = increment
		aucTable.bidders = emptytable()
		aucTable.timeRemains = self.opt.auctionTimer
		MMMGdkp.curAuctions[item] = aucTable
		MMMGdkp.curAuctions[item].canOs = not os
	end
	MMMGdkp:Show()
end

function MMMGdkp:RevertHighestBid(link)
	if self.opt.allowMultipleAuctions then
		if not link then return end
		local aucdata = self.curAuctions[link]
		if not aucdata then return end
		if #aucdata.bidders < 2 then return end
		table.sort(aucdata.bidders, function(a, b) return a.bidAmount > b.bidAmount end)
		aucdata.bidders[aucdata.bidders[1].bidderName] = nil
		tremove(aucdata.bidders, 1)
		SendChatMessage(("New highest bidder on %s: %s (%d gold)"):format(link, aucdata.bidders[1].bidderName,
			aucdata.bidders[1].bidAmount),
			(self.opt.announceBidRaidWarning and (IsRaidOfficer() or IsRaidLeader())) and "RAID_WARNING" or "RAID")
		-- fix name-to-index assigns
		for num, t in ipairs(aucdata.bidders) do
			aucdata.bidders[t.bidderName] = num
		end
		aucdata.timeRemains = math.max(aucdata.timeRemains, self.opt.auctionTimerRefresh)
		aucdata.curBid = aucdata.bidders[1].bidAmount
	else
		if #self.curAuction.bidders < 2 then return end
		table.sort(self.curAuction.bidders, function(a, b) return a.bidAmount > b.bidAmount end)
		self.curAuction.bidders[self.curAuction.bidders[1].bidderName] = nil
		tremove(self.curAuction.bidders, 1)
		SendChatMessage(("New highest bidder: %s (%d gold)"):format(self.curAuction.bidders[1].bidderName,
			self.curAuction.bidders[1].bidAmount),
			(self.opt.announceBidRaidWarning and (IsRaidOfficer() or IsRaidLeader())) and "RAID_WARNING" or "RAID")
		for num, t in ipairs(self.curAuction.bidders) do
			self.curAuction.bidders[t.bidderName] = num
		end
		self.curAuction.timeRemains = math.max(self.curAuction.timeRemains, self.opt.auctionTimerRefresh)
		self.curAuction.curBid = self.curAuction.bidders[1].bidAmount
	end
end

function MMMGdkp:CancelAuction(link)
	if self.opt.allowMultipleAuctions then
		if not link then return end
		local aucdata = self.curAuctions[link]
		if not aucdata then return end
		SendChatMessage(("Auction cancelled for %s."):format(link),
			(self.opt.announceRaidWarning and (IsRaidOfficer() or IsRaidLeader())) and "RAID_WARNING" or "RAID")
		self.curAuctions[link] = nil
	else
		SendChatMessage("Auction cancelled.",
			(self.opt.announceRaidWarning and (IsRaidOfficer() or IsRaidLeader())) and "RAID_WARNING" or "RAID")
		table.wipe(self.curAuction)
		if self.auctionList[1] then
			self:AuctionOffItem(unpack(self.auctionList[1]))
			self.auctionList[1]:Release()
			tremove(self.auctionList, 1)
		end
	end
end

function MMMGdkp:FinishAuction(link)
	if self.opt.allowMultipleAuctions then
		-- new code
		if not link then return end
		local aucdata = self.curAuctions[link]
		if aucdata then
			if not aucdata.maxBid or not tonumber(aucdata.maxBid) == tonumber(totalAmount) then
				table.sort(aucdata.bidders, function(a, b) return a.bidAmount > b.bidAmount end)
			end
			if aucdata.bidders[1] then
				local totalAmount = aucdata.bidders[1].bidAmount
				local remAmount = totalAmount
				local paymentString = "%d to pot"
				if self.opt.shareSecondEnable and aucdata.bidders[2] then
					local secondShare = round(totalAmount * self.opt.shareSecondAmount)
					remAmount = remAmount - secondShare
					paymentString = paymentString .. ", " .. secondShare .. " to " .. aucdata.bidders[2].bidderName
				end
				if self.opt.shareThirdEnable and aucdata.bidders[3] then
					local thirdShare = round(totalAmount * self.opt.shareThirdAmount)
					remAmount = remAmount - thirdShare
					paymentString = paymentString .. ", " .. thirdShare .. " to " .. aucdata.bidders[3].bidderName
				end
				paymentString = paymentString:format(remAmount)
				
				if aucdata.maxBid and tonumber(aucdata.maxBid) == tonumber(totalAmount) then					
					SendChatMessage(("Auction finished for %s. Winner: %s. %s."):format(link, aucdata.bidders[1].bidderName,
						paymentString), "RAID")
				else
					SendChatMessage(("Auction finished for %s. Winner: %s. %s."):format(link, aucdata.bidders[1].bidderName,
						paymentString), "RAID")
				end
				MMMGdkp_PotData.potAmount = (MMMGdkp_PotData.potAmount or 0) + remAmount
				MMMGdkp_PotData.playerBalance[aucdata.bidders[1].bidderName] = MMMGdkp_PotData.playerBalance[
					aucdata.bidders[1].bidderName] - remAmount
				MMMGdkp.balance:Update()
				if self.opt.announcePotAfterAuction then
					SendChatMessage("Current pot: " .. MMMGdkp_PotData.potAmount .. " gold", "RAID")
				end
				tinsert(MMMGdkp_PotData.curPotHistory, { item = link, bid = totalAmount, name = aucdata.bidders[1].bidderName })
				self.status:Update()
				if self.opt.autoAwardLoot then
					local bestBidderName = aucdata.bidders[1].bidderName
					for lootSlot = 1, GetNumLootItems() do
						if GetLootSlotLink(lootSlot) == link then
							local candidateIndex = 1
							local candidateName = GetMasterLootCandidate(lootSlot, candidateIndex)
							while candidateName do
								if candidateName == bestBidderName then
									GiveMasterLoot(lootSlot, candidateIndex)
									break
								end
								candidateIndex = candidateIndex + 1
								candidateName = GetMasterLootCandidate(candidateIndex)
							end
							break
						end
					end
				end
			else
				SendChatMessage(("Auction finished for %s. No bids recieved."):format(link), "RAID")
				if (aucdata.osWanted) then
					local itemID = tonumber(link:match("|Hitem:(%d+):"))
					aucdata:Release()
					self.curAuctions[link] = nil
					
					MMMGdkp_wait(2, QueueAuctionOS, link, MMMGdkp:GetStartBid(itemID), MMMGdkp:GetMinIncrement(itemID) / 2)
				end
			end
			aucdata:Release()
		end
		self.curAuctions[link] = nil
	else
		-- old code
		table.sort(self.curAuction.bidders, function(a, b) return a.bidAmount > b.bidAmount end)
		if self.curAuction.bidders[1] then
			local totalAmount = self.curAuction.bidders[1].bidAmount
			local remAmount = totalAmount
			local paymentString = "%d to pot"
			if self.opt.shareSecondEnable and self.curAuction.bidders[2] then
				local secondShare = round(totalAmount * self.opt.shareSecondAmount)
				remAmount = remAmount - secondShare
				paymentString = paymentString .. ", " .. secondShare .. " to " .. self.curAuction.bidders[2].bidderName
			end
			if self.opt.shareThirdEnable and self.curAuction.bidders[3] then
				local thirdShare = round(totalAmount * self.opt.shareThirdAmount)
				remAmount = remAmount - thirdShare
				paymentString = paymentString .. ", " .. thirdShare .. " to " .. self.curAuction.bidders[3].bidderName
			end
			paymentString = paymentString:format(remAmount)
			SendChatMessage(("Auction finished. Winner: %s. %s."):format(self.curAuction.bidders[1].bidderName, paymentString),
				"RAID")
			MMMGdkp_PotData.potAmount = (MMMGdkp_PotData.potAmount or 0) + remAmount
			MMMGdkp_PotData.playerBalance[self.curAuction.bidders[1].bidderName] = MMMGdkp_PotData.playerBalance[
				self.curAuction.bidders[1].bidderName] - remAmount
			MMMGdkp.balance:Update()
			if self.opt.announcePotAfterAuction then
				SendChatMessage("Current pot: " .. MMMGdkp_PotData.potAmount .. " gold", "RAID")
			end
			tinsert(MMMGdkp_PotData.curPotHistory,
				{ item = self.curAuction.item, bid = totalAmount, name = self.curAuction.bidders[1].bidderName })
			self.status:Update()
			if self.opt.autoAwardLoot then
				local bestBidderName = self.curAuction.bidders[1].bidderName
				local candidateIndex = 1
				local candidateName = GetMasterLootCandidate(candidateIndex)
				while candidateName do
					if candidateName == bestBidderName then
						for lootSlot = 1, GetNumLootItems() do
							if GetLootSlotLink(lootSlot) == self.curAuction.item then
								GiveMasterLoot(lootSlot, candidateIndex)
								break
							end
						end
						break
					end
					candidateIndex = candidateIndex + 1
					candidateName = GetMasterLootCandidate(candidateIndex)
				end
			end
		else
			SendChatMessage("Auction finished. No bids recieved.", "RAID")
		end
		self.curAuction.bidders:Release()
		table.wipe(self.curAuction)
		if self.auctionList[1] then
			self:AuctionOffItem(unpack(self.auctionList[1]))
			self.auctionList[1]:Release()
			tremove(self.auctionList, 1)
		end
	end
end

function MMMGdkp:DistributePot()
	local numraid = GetNumGroupMembers()
	if not (numraid > 0) then return end
	local distAmount = (MMMGdkp_PotData.potAmount or 0) - (MMMGdkp_PotData.prevDist or 0)
	if distAmount <= 0 then return end
	local numadditionalmemb = self.opt.AdditonalRaidMembersAmount
	if self.opt.AdditionalRaidMembersEnable then
		SendChatMessage((
			"Distributing pot. Pot size: %d gold. Amount to distribute: %d gold. Players in raid: %d(%d). Share per player: %d gold."
			):format((MMMGdkp_PotData.potAmount or 0), distAmount, numraid, numadditionalmemb,
				(distAmount or 0) / (numraid + numadditionalmemb)), "RAID")
	else
		SendChatMessage((
			"Distributing pot. Pot size: %d gold. Amount to distribute: %d gold. Players in raid: %d. Share per player: %d gold."
			):format((MMMGdkp_PotData.potAmount or 0), distAmount, numraid, (distAmount or 0) / numraid), "RAID")
	end
	for numRaid = 1, numraid do
		if self.opt.AdditionalRaidMembersEnable then
			MMMGdkp_PotData.playerBalance[(UnitName("raid" .. numRaid))] = MMMGdkp_PotData.playerBalance[
				(UnitName("raid" .. numRaid)
					)] + math.floor((distAmount or 0) / (numraid + numadditionalmemb))
		else
			MMMGdkp_PotData.playerBalance[(UnitName("raid" .. numRaid))] = MMMGdkp_PotData.playerBalance[
				(UnitName("raid" .. numRaid)
					)] + math.floor((distAmount or 0) / numraid)
		end
	end
	MMMGdkp_PotData.prevDist = MMMGdkp_PotData.potAmount
	MMMGdkp.balance:Update()
end

function MMMGdkp:GetUnoccupiedFrame()
	local c = 1
	while MMMGdkp.frames[c] do
		if not MMMGdkp.frames[c]:IsShown() then
			MMMGdkp.frames[c].hide:Disable()
			MMMGdkp.frames[c].bidbox:SetNumber(0)
			MMMGdkp.frames[c].autobid:Disable()
			MMMGdkp.frames[c].bidbox:Hide()
			MMMGdkp.frames[c].bid:Disable()
			MMMGdkp.frames[c].itemlink = nil
			MMMGdkp.frames[c].maxAutoBid = nil
			MMMGdkp.frames[c].curbidamount = nil
			MMMGdkp.frames[c].curbidismine = nil
			MMMGdkp.frames[c].bidIncrement = nil
			MMMGdkp.frames[c].initialBid = nil
			MMMGdkp.frames[c].autobid:Show()
			MMMGdkp.frames[c].stopautobid:Hide()
			MMMGdkp.frames[c].curbid:Hide()
			MMMGdkp.frames[c].isActive = false
			MMMGdkp.frames[c].restartAuction:Hide()
			MMMGdkp.frames[c].bigHide:Hide()
			if (MMMGdkp:PlayerIsML((UnitName("player")), true) and (not MMMGdkp.opt.slimML)) then
				MMMGdkp.frames[c].cancelAuction:Show()
				MMMGdkp.frames[c].reverseBid:Show()
			else
				MMMGdkp.frames[c].cancelAuction:Hide()
				MMMGdkp.frames[c].reverseBid:Hide()
			end
			MMMGdkp.frames[c].reverseBid:Disable()
			MMMGdkp.frames[c]:UpdateSize()
			return MMMGdkp.frames[c]
		end
		c = c + 1
	end
	local f = CreateFrame("Frame", "MMMGdkpBidFrame" .. c, UIParent, BackdropTemplateMixin and "BackdropTemplate")
	f:SetSize(360, 60)
	f:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		tileSize = 16,
		edgeSize = 24,
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		edgeSize = 16,
		insets = { top = 5, bottom = 5, left = 5, right = 5 },
	})
	if c > 1 then
		f:SetPoint("TOPLEFT", MMMGdkp.frames[c - 1], "BOTTOMLEFT")
	else
		f:SetPoint("TOPLEFT", anchor, "TOPLEFT")
	end
	--f:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, (-60)*(c-1))
	f:Hide()
	f:SetFrameStrata("DIALOG")
	f.icon = f:CreateTexture()
	f.icon:SetSize(40, 40)
	f.icon:SetTexture(1, 1, 1)
	f.icon:SetPoint("TOPLEFT", 10, -10)
	f.itemstring = f:CreateFontString()
	f.itemstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
	f.itemstring:SetTextColor(1, 1, 1)
	f.itemstring:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 5, 0)
	f.itemstring:SetWidth(260)
	f.itemstring:SetWordWrap(false)
	f.itemstring:SetJustifyH("LEFT")
	f.curbid = f:CreateFontString()
	f.curbid:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
	f.curbid:SetTextColor(1, 1, 1)
	f.curbid:SetPoint("TOPLEFT", f.itemstring, "BOTTOMLEFT", 0, -5)
	f.curbid:Hide()
	f.highestbid = f:CreateFontString()
	f.highestbid:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
	f.highestbid:SetTextColor(0, 0.8, 0)
	f.highestbid:SetPoint("TOPLEFT", f.curbid, "BOTTOMLEFT", 0, -5)
	f.highestbid:SetText("You are the top bidder!")
	f.highestbidder = f:CreateFontString()
	f.highestbidder:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
	f.highestbidder:SetTextColor(1, 1, 1)
	f.highestbidder:SetPoint("TOPLEFT", f.curbid, "BOTTOMLEFT", 0, -5)
	f.timer = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
	-- omnicc stuff
	f.timer.noCooldownCount = true
	f.timer:SetReverse(true)
	f.timer:SetAllPoints(f.icon)
	f.timer.update = CreateFrame("Frame")
	-- f.timer.update:Hide()
	f.timer.update:SetScript("OnUpdate", function(self)
		local timeRemain = self.endTime - GetTime()
		if timeRemain <= 0 then
			self:Hide()
			f.timer.text:Hide()
		end
		if timeRemain % 1 > 0.5 then
			f.timer.text:SetTextColor(1, 0, 0)
		else
			f.timer.text:SetTextColor(1, 1, 0)
		end
		f.timer.text:SetText(math.ceil(timeRemain))
	end)
	f.timer.text = f.timer:CreateFontString()
	f.timer.text:SetFont("Fonts\\FRIZQT__.TTF", GetCVarBool("useUiScale") and (32 * (GetCVar("uiScale") or 1)) or 28,
		"OUTLINE")
	f.timer.text:SetAllPoints()
	f.timer.text:Hide()

	f.autobid = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.autobid:SetText(L["Auto bid"])
	f.autobid:SetSize(0, 0)
	f.autobid:SetScript("OnClick", function(self)
		StaticPopup_Show("MMMGdkp_AUTOBID", f.itemlink).data = f
		f.hide:Disable()
	end)
	f.autobid:SetPoint("TOPRIGHT", -10, -10)
	f.stopautobid = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.stopautobid:SetText(L["Stop bid"])
	f.stopautobid:SetAllPoints(f.autobid)
	f.stopautobid:Hide()
	f.stopautobid:SetScript("OnClick", function(self)
		self:Hide()
		f.maxAutoBid = nil
		f.autobid:Show()
		f.hide:Enable()
	end)
	
	f.bidbox = CreateFrame("EditBox", nil, f, BackdropTemplateMixin and "BackdropTemplate")
	f.bidbox:SetMultiLine(nil)
	f.bidbox:SetScript("OnEditFocusGained", function(self)
		if self.disabled then
			self:ClearFocus()
		end
	end)
	function f.bidbox:Enable()
		self.disabled = false
	end

	function f.bidbox:Disable()
		self.disabled = true
	end

	f.bidbox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	f.bidbox:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	f.bidbox:SetBackdrop({ bgFile = "Interface\\ChatFrame\\UI-ChatInputBorder", tile = false })
	f.bidbox:SetTextInsets(5, 5, 2, 2)
	f.bidbox:SetSize(60, 16)
	f.bidbox:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
	f.bidbox:SetAutoFocus(false)
	f.bidbox:SetPoint("LEFT", f.curbid, "RIGHT", 5, 0)
	f.bidbox:SetJustifyH("RIGHT")
	f.bidbox:SetNumeric(true)
	f.bidbox:SetNumber(0)
	f.bidbox:SetScript("OnUpdate", function(self)
		local wantBid = f.bidbox:GetNumber()
		if wantBid < (f.bidIncrement + f.curbidamount) then
			f.bid:Disable()
			return
		end

		if wantBid >= f.maxBid then
			f.bid:Disable()
			return
		end
		
		if f.bid.shouldEnable then
			f.bid:Enable()
			return
		end
	end)
	f.bidbox:Hide()
	f.bid = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.bid:SetText(L["Bid"])
	f.bid:SetSize(50, 16)
	f.bid:SetPoint("RIGHT", f.bidbox, "RIGHT", 115, 0)
	f.bid:SetScript("OnClick", function(self)
		local newBid = f.curbidamount + f.bidIncrement
		local wantBid = f.bidbox:GetNumber()
		if wantBid < (f.bidIncrement + f.curbidamount) then
			return
		end

		if wantBid > f.maxBid * 2 then
			print("Please type a valid number in the box")
			return
		end
		
		if (wantBid >= f.maxBid) then
			wantBid = f.maxBid
			if (not self.rolled) then
				RandomRoll(f.itemId, f.itemId + 999)
			end
			self.rolled = true
		end
		if f.isMultiBid then
			SendChatMessage(f.itemlink .. " " .. wantBid, "RAID")
		else
			SendChatMessage(tostring(wantBid), "RAID")
		end
	end)
	f.bid:Disable()
	f.bid.shouldEnable = false
	f.bid.enabledelay = CreateFrame("Frame", nil, f.bid)
	f.bid.enabledelay:Hide()
	f.bid.enabledelay:SetScript("OnUpdate", function(self)
		if not self.reenabletime then self:Hide() return end
		if self.curbidamount and self.maxBid and self.curbidamount >= self.maxBid then return end
		if GetTime() >= self.reenabletime then 
			f.bid.shouldEnable = true 

			local wantBid = f.bidbox:GetNumber()
			if wantBid > (f.bidIncrement + f.curbidamount) and wantBid < f.maxBid then
				f.bid:Enable()
			end
			self.reenabletime = nil self:Hide() end
	end)

	f.roll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.roll:SetText("Roll")
	f.roll:SetSize(50, 16)
	f.roll:SetPoint("LEFT", f.bid, "LEFT", -55, 0)
	f.rolled = false
	f.roll:SetScript("OnClick", function(self)
		local newBid = f.maxBid
		if (f.rolled) then
			return
		end

		f.rolled = true
		if f.isMultiBid then
			SendChatMessage(f.itemlink .. " " .. newBid, "RAID")
		else
			SendChatMessage(tostring(newBid), "RAID")
		end
		RandomRoll(f.itemId, f.itemId + 999)
	end)

	f.roll:Disable()
	f.roll.enabledelay = CreateFrame("Frame", nil, f.bid)
	f.roll.enabledelay:Hide()
	f.roll.enabledelay:SetScript("OnUpdate", function(self)
		if not self.reenabletime then self:Hide() return end
		if GetTime() >= self.reenabletime then f.roll:Enable() self.reenabletime = nil self:Hide() end
	end)

	f.increment = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.increment:SetText("+")
	f.increment:SetSize(50, 16)
	f.increment:SetPoint("BOTTOM", f.roll, "BOTTOM", 0, -16)
	f.increment:SetScript("OnClick", function(self)
		local newBid = f.curbidamount + f.bidIncrement
		if (newBid >= f.maxBid) then
			newBid = f.maxBid
			if (not self.rolled) then
				RandomRoll(f.itemId, f.itemId + 999)
			end
			self.rolled = true
		end
		if f.isMultiBid then
			SendChatMessage(f.itemlink .. " " .. newBid, "RAID")
		else
			SendChatMessage(tostring(newBid), "RAID")
		end
	end)

	f.increment:Disable()
	f.increment.enabledelay = CreateFrame("Frame", nil, f.bid)
	f.increment.enabledelay:Hide()
	f.increment.enabledelay:SetScript("OnUpdate", function(self)
		if not self.reenabletime then self:Hide() return end
		if self.curbidamount and self.maxBid and self.curbidamount >= self.maxBid then return end
		if GetTime() >= self.reenabletime then f.increment:Enable() self.reenabletime = nil self:Hide() end
	end)

	f.osrequest = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	function f.osrequest:Active() 
		self:Enable()
		self:SetText("OS")
	end

	function f.osrequest:Requested() 
		self:Disable()
		self:SetText("OS wanted")
	end

	f.osrequest:SetSize(70, 16)
	f.osrequest:SetPoint("BOTTOM", f.increment, "RIGHT", 35, -8)
	f.osrequest:Active()
	f.osrequest:SetScript("OnClick", function(self)
		SendChatMessage(f.itemlink .. " is OS wanted", "RAID")
	end)

	--f.hide = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.hide = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	--f.hide:SetText(L["Hide"])
	f.hide:SetSize(16, 16)
	f.hide:SetPoint("TOPRIGHT")
	f.hide:SetScript("OnClick", function(self)
		MMMGdkp.ignoredLinks[f.itemlink] = true
		f:Hide()
	end)
	f.hide:SetScript("OnEnter", function(self)
		self:SetAlpha(1)
	end)
	f.hide:SetScript("OnLeave", function(self)
		if (not MMMGdkp.opt.forceHideShow) then
			self:SetAlpha(0)
		end
	end)
	f.hide:SetAlpha(MMMGdkp.opt.forceHideShow and 1 or 0)
	f.hide:SetDisabledTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Disabled")
	f.autobid:Disable()
	f.hide:Disable()
	f.bigHide = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.bigHide:SetText(L["Hide"])
	f.bigHide:SetHeight(15)
	f.bigHide:SetPoint("BOTTOMLEFT", 10, 10)
	f.bigHide:SetPoint("BOTTOMRIGHT", -10, 10)
	f.bigHide:SetScript("OnClick", function(self)
		f:Hide()
	end)
	f.bigHide:Hide()
	f.restartAuction = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.restartAuction:SetText(L["Restart auction"])
	f.restartAuction:SetHeight(15)
	f.restartAuction:SetPoint("BOTTOMLEFT", f.bigHide, "TOPLEFT", 0, 2)
	f.restartAuction:SetPoint("BOTTOMRIGHT", f.bigHide, "TOPRIGHT", 0, 2)
	f.restartAuction:SetScript("OnClick", function(self)
		f:Hide()
		local itemLink = f.itemlink
		local itemID = tonumber(itemLink:match("|Hitem:(%d+):"))
		MMMGdkp:QueueAuction(itemLink, MMMGdkp:GetStartBid(itemID), MMMGdkp:GetMinIncrement(itemID))
	end)
	f.restartAuction:Hide()
	f.cancelAuction = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.cancelAuction:SetText(L["Cancel auction"])
	f.cancelAuction:SetAllPoints(f.restartAuction)
	f.cancelAuction:SetScript("OnClick", function(self)
		MMMGdkp:CancelAuction(f.itemlink)
		self:Hide()
		f.reverseBid:Hide()
		f.bigHide:Show()
		f.restartAuction:Show()
	end)
	f.reverseBid = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.reverseBid:SetText(L["Revert highest bid"])
	f.reverseBid:SetAllPoints(f.bigHide)
	f.reverseBid:SetScript("OnClick", function(self)
		MMMGdkp:RevertHighestBid(f.itemlink)
	end)
	if (not self:PlayerIsML((UnitName("player")), true)) or self.opt.slimML then
		f.cancelAuction:Hide()
		f.reverseBid:Hide()
	end
	f.reverseBid:Disable()
	function f:SetItem(itemlink)
		self.itemId = GetItemInfoFromHyperlink(itemlink)
		self.maxBid = MaxBidSmall
		if (LargeBidItems[self.itemId]) then
			self.maxBid = LargeBidItems[self.itemId]
		end

		self.icon:SetTexture((select(10, GetItemInfo(itemlink))))
		self.itemstring:SetText(itemlink .. " Max: " .. tostring(self.maxBid) .. "g")
		self:EnableMouse(true)
		self.autobid:Enable()
		self.bidbox:Enable()
		--self.hide:Enable()
		self.highestbid:Hide()
		self.itemlink = itemlink
		self.osrequest:Active()
	end

	function f:SetCurBid(goldAmount, bidderName, isMine, isInitial)
		self.curbid:SetText((isInitial and L["Minimum bid: "] or L["Current bid: "]) .. goldAmount .. "|cffffd100g|r")
		if (not isMine and self.curbidamount and tonumber(self.curbidamount) == tonumber(goldAmount) and self.maxBid and tonumber(goldAmount) >= tonumber(self.maxBid)) then
			-- don't change
		elseif bidderName and (not isMine) then
			self.highestbidder:Show()
			self.highestbidder:SetText(L["Highest bidder: %s"]:format(bidderName))
			self.highestbid:Hide()
		elseif isMine then
			if self.maxBid and tonumber(goldAmount) >= tonumber(self.maxBid) then
				-- self.highestbid:SetText("You are one of the top bidders!")
			else
			   self.highestbid:SetText("You are the top bidder!")
			end
			self.highestbid:Show()
			self.highestbidder:Hide()
		else
			self.highestbid:Hide()
			self.highestbidder:Hide()
		end
		self.curbidamount = goldAmount - (isInitial and self.bidIncrement or 0)
		self.curbidismine = not not isMine
		self.curbid:Show()
		self.bidbox:Show()
		self.bid.shouldEnable = true
		self.bid:Enable()
		self.roll:Enable()
		self.increment:Enable()
		if not isInitial then
			-- self.bid:Disable()
			-- self.bid.shouldEnable = false
			self.roll:Disable()
			self.increment:Disable()
			if not isMine then
				if (not self.rolled) then
					self.bid.enabledelay.reenabletime = GetTime() + MMMGdkp.opt.bidButtonReenableDelay
					self.bid.enabledelay:Show()
					
					self.increment.enabledelay.reenabletime = GetTime() + MMMGdkp.opt.bidButtonReenableDelay
					self.increment.enabledelay:Show()

					self.roll.enabledelay.reenabletime = GetTime() + MMMGdkp.opt.bidButtonReenableDelay
					self.roll.enabledelay:Show()
				end
			end
			if goldAmount > (self.initialBid or math.huge) then
				self.reverseBid:Enable()
			end
		else
			self.initialBid = goldAmount
		end
	end

	function f:SetAuctionTimer(timerDuration, timerResetDuration)
		if (not timerDuration) then return end
		local ctime = GetTime()
		self.timer:SetCooldown(ctime, timerDuration)
		self.timer.update.endTime = ctime + timerDuration
		self.timer[MMMGdkp.opt.showAuctionDurationTimer and "Show" or "Hide"](self.timer)
		self.timer.text[MMMGdkp.opt.showAuctionDurationTimerText and "Show" or "Hide"](self.timer.text)
		self.timer.update[MMMGdkp.opt.showAuctionDurationTimerText and "Show" or "Hide"](self.timer.update)
		self.timerDuration = timerDuration
		self.timerResetDuration = timerResetDuration or timerDuration
	end

	function f:ResetAuctionTimer()
		if not self.timerResetDuration then return end
		if (self.timerResetDuration + GetTime()) < self.timer.update.endTime then return end
		self.timer:SetCooldown(GetTime() - (self.timerDuration - self.timerResetDuration), self.timerDuration)
		self.timer.update.endTime = GetTime() + self.timerResetDuration
	end

	f:SetScript("OnEnter", function(self)
		GameTooltip:ClearAllPoints()
		GameTooltip:ClearLines()
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		GameTooltip:SetHyperlink(self.itemlink)
		GameTooltip:SetPoint("RIGHT", self, "LEFT")
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f:SetScale(self.opt.appearScale)
	f:SetAlpha(self.opt.appearAlpha)
	f.isActive = false
	function f:UpdateSize()
		if (self.bigHide:IsShown() or self.cancelAuction:IsShown()) then
			self:SetHeight(100)
		else
			self:SetHeight(60)
		end
	end

	f:UpdateSize()
	MMMGdkp.frames[c] = f
	return f
end

function MMMGdkp:UpdateAllVisibilities()
	status:UpdateVisibility()
	playerBalance:UpdateVisibility()
end

local defaults = { profile = {
	point = {
		point = "CENTER",
		relative = "CENTER",
		x = 0,
		y = 0,
	},
	statuspoint = {
		point = "CENTER",
		relative = "CENTER",
		x = 0,
		y = 0,
	},
	balancepoint = {
		point = "CENTER",
		relative = "CENTER",
		x = 0,
		y = -50,
	},
	playerbalancepoint = {
		point = "CENTER",
		relative = "CENTER",
		x = 0,
		y = 50,
	},
	customItemSettings = {
	},
	itemLevelPricing = {
	},
	forceHideShow = true,
	countdownTimerJump = 5,
	shareSecondEnable = false,
	shareSecondAmount = 0.33,
	shareThirdEnable = false,
	shareThirdAmount = 0.11,
	AdditionalRaidMembers = false,
	AdditonalRaidMembersAmount = 0,
	auctionTimer = 20,
	auctionTimerRefresh = 20,
	movable = true,
	startBid = 20,
	increment = 5,
	minQuality = -1,
	autoAwardLoot = false,
	awardToML = false,
	showAuctionDurationTimer = true,
	showAuctionDurationTimerText = true,
	announceRaidWarning = true,
	announceBidRaidWarning = false,
	allowMultipleAuctions = true,
	announcePotAfterAuction = true,
	hideChatMessages = {
		auctionAnnounce = false,
		auctionAnnounceRW = false,
		newBid = false,
		bidFinished = false,
		secondsRemaining = false,
		bidChats = false,
		potValues = false,
		auctionCancel = false,
		auctionCancelRW = false,
	},
	notifyVersions = {
		notifyCompatibleOutdated = true,
		notifyIncompatibleOutdated = true,
		notifyNotInstalled = false,
	},
	hideCombat = {
	},
	appearAlpha = 1,
	appearScale = 1,
	controlScale = 1,
	bidButtonReenableDelay = 0.2,
	slimML = false,
	slimMLConfirmed = false,
	confirmMailAll = true,
	confirmMail = false,
	linkBalancePot = false,
} }

MMMGdkp.options = {
	type = "group",
	args = {
		lock = {
			type = "toggle",
			name = L["Lock"],
			desc = L["Prevent dragging and hide anchor"],
			get = function() return not MMMGdkp.opt.movable end,
			set = function(info, value) MMMGdkp.opt.movable = not value MMMGdkp:SetMovable(not value) end,
			order = 1,
			width = "half",
		},
		show = {
			type = "toggle",
			name = L["Show"],
			desc = L["Show addon frames"],
			get = function() return not MMMGdkp.opt.hide end,
			set = function(info, value) MMMGdkp.opt.hide = not value MMMGdkp:UpdateAllVisibilities() end,
			order = 2,
			width = "half",
		},
		behaviour = {
			type = "group",
			name = L["Behaviour options"],
			args = {
				startBid = {
					type = "range",
					name = L["Starting bid"],
					min = 0,
					max = 100000,
					softMax = 10000,
					softMin = 0,
					step = 1,
					get = function() return MMMGdkp.opt.startBid end,
					set = function(info, value) MMMGdkp.opt.startBid = value end,
					order = 1,
				},
				minIncrement = {
					type = "range",
					name = L["Minimum increment"],
					min = 1,
					max = 100000,
					softMax = 2000,
					softMin = 10,
					step = 1,
					get = function() return MMMGdkp.opt.increment end,
					set = function(info, value) MMMGdkp.opt.increment = value end,
					order = 2,
				},
				customSettings = {
					type = "execute",
					name = L["Per-item settings"],
					func = function() MMMGdkp.itemsettings:Show() LibStub("AceConfigDialog-3.0"):Close("MMMGdkp") end,
					order = 2.5,
					--					width="double",
				},
				customILvLSettings = {
					type = "execute",
					name = L["Item level settings"],
					func = function() MMMGdkp.itemLevels:Show() LibStub("AceConfigDialog-3.0"):Close("MMMGdkp") end,
					order = 2.7,
					--					width="double",
				},
				secondShare = {
					dialogInline = true,
					name = L["Second bidder share"],
					order = 3,
					type = "group",
					args = {
						isEnabled = {
							order = 1,
							type = "toggle",
							name = L["Enable"],
							set = function(info, value) MMMGdkp.opt.shareSecondEnable = value end,
							get = function() return MMMGdkp.opt.shareSecondEnable end,
						},
						shareAmount = {
							order = 2,
							type = "range",
							name = L["Amount"],
							min = 0.01,
							max = 0.99,
							isPercent = true,
							set = function(info, value) MMMGdkp.opt.shareSecondAmount = value end,
							get = function() return MMMGdkp.opt.shareSecondAmount end,
						},
					},
				},
				thirdShare = {
					dialogInline = true,
					name = L["Third bidder share"],
					order = 4,
					type = "group",
					args = {
						isEnabled = {
							order = 1,
							type = "toggle",
							name = L["Enable"],
							set = function(info, value) MMMGdkp.opt.shareThirdEnable = value end,
							get = function() return MMMGdkp.opt.shareThirdEnable end,
						},
						shareAmount = {
							order = 2,
							type = "range",
							name = L["Amount"],
							min = 0.01,
							max = 0.99,
							isPercent = true,
							set = function(info, value) MMMGdkp.opt.shareThirdAmount = value end,
							get = function() return MMMGdkp.opt.shareThirdAmount end,
						},
					},
				},
				AdditionalRaidMembers = {
					dialogInline = true,
					name = L["Additional Raid Members"],
					order = 5,
					type = "group",
					args = {
						isEnabled = {
							order = 1,
							type = "toggle",
							name = L["Enable"],
							set = function(info, value) MMMGdkp.opt.AdditionalRaidMembersEnable = value end,
							get = function() return MMMGdkp.opt.AdditionalRaidMembersEnable end,
						},
						shareAmount = {
							order = 2,
							type = "range",
							name = L["Amount"],
							min = 0,
							max = 40,
							step = 1,
							isPercent = false,
							set = function(info, value) MMMGdkp.opt.AdditonalRaidMembersAmount = value end,
							get = function() return MMMGdkp.opt.AdditonalRaidMembersAmount end,
						},
					},
				},
				minQuality = {
					type = "select",
					values = function()
						local vtab = {}
						for key, tab in pairs(ITEM_QUALITY_COLORS) do
							if _G["ITEM_QUALITY" .. key .. "_DESC"] then
								vtab[key] = tab.hex .. _G["ITEM_QUALITY" .. key .. "_DESC"] .. "|r"
							end
						end
						vtab[-1] = "|cffaa2222" .. L["Use looting system loot threshold setting"] .. "|r"
						return vtab
					end,
					name = L["Minimum quality"],
					set = function(info, value) MMMGdkp.opt.minQuality = value end,
					get = function() return MMMGdkp.opt.minQuality end,
					order = 6,
					width = "full",
				},
				auctionTimer = {
					type = "range",
					softMin = 5,
					softMax = 300,
					order = 7,
					name = L["Auction timeout"],
					desc = L["The amount of seconds that have to pass before the auction is closed without bids recieved"],
					set = function(info, value) MMMGdkp.opt.auctionTimer = value end,
					get = function() return MMMGdkp.opt.auctionTimer end,
				},
				auctionTimerRefresh = {
					type = "range",
					softMin = 5,
					softMax = 300,
					order = 8,
					name = L["Auction bid timeout refresh"],
					desc = L["The amount of seconds that have to pass after a bid before the auction is closed"],
					set = function(info, value) MMMGdkp.opt.auctionTimerRefresh = value end,
					get = function() return MMMGdkp.opt.auctionTimerRefresh end,
				},
				countdownTimerJump = {
					type = "range",
					softMin = 1,
					softMax = 10,
					order = 8.5,
					name = L["Countdown timer announce interval"],
					desc = L["The amount of seconds between each announcement of the remaining time"],
					set = function(info, value) MMMGdkp.opt.countdownTimerJump = value end,
					get = function() return MMMGdkp.opt.countdownTimerJump end,
				},
				autoAward = {
					type = "toggle",
					name = L["Auto-award loot to winner"],
					set = function(info, value) MMMGdkp.opt.autoAwardLoot = value end,
					get = function() return MMMGdkp.opt.autoAwardLoot end,
					width = "full",
					order = 9,
					disabled = function() return not not MMMGdkp.opt.awardToML end,
				},
				awardToML = {
					type = "toggle",
					name = L["Award loot to Master Looter when auto-auctioning"],
					set = function(info, value) MMMGdkp.opt.awardToML = value end,
					get = function() return MMMGdkp.opt.awardToML end,
					width = "full",
					order = 10,
					disabled = function() return not not MMMGdkp.opt.autoAwardLoot end,
				},
				announceRW = {
					type = "toggle",
					name = L["Announce auction start to raid warning"],
					set = function(info, value) MMMGdkp.opt.announceRaidWarning = value end,
					get = function() return MMMGdkp.opt.announceRaidWarning end,
					width = "full",
					order = 11,
				},
				announceRWBid = {
					type = "toggle",
					name = L["Announce bids to raid warning"],
					width = "full",
					set = function(info, value) MMMGdkp.opt.announceBidRaidWarning = value end,
					get = function() return MMMGdkp.opt.announceBidRaidWarning end,
					order = 12,
				},
				announcePotAfterAuction = {
					type = "toggle",
					name = L["Announce the current pot amount after each auction"],
					width = "full",
					set = function(info, value) MMMGdkp.opt.announcePotAfterAuction = value end,
					get = function() return MMMGdkp.opt.announcePotAfterAuction end,
					order = 14,
				},
				confirmMail = {
					type = "toggle",
					name = L["Require confirmation when mailing pot shares"],
					width = "full",
					set = function(info, value) MMMGdkp.opt.confirmMail = value end,
					get = function() return MMMGdkp.opt.confirmMail end,
					order = 15,
				},
				linkBalancePot = {
					type = "toggle",
					name = L["Link raid member balance to pot"],
					desc = L["Any money subtracted from raid members is added to the pot and vice versa"],
					width = "full",
					set = function(info, value) MMMGdkp.opt.linkBalancePot = value end,
					get = function() return MMMGdkp.opt.linkBalancePot end,
					order = 16,
				},
			},
			order = 1,
		},
		appearance = {
			type = "group",
			name = L["Appearance options"],
			args = {
				hideChats = {
					type = "multiselect",
					name = L["Hide chat messages"],
					values = {
						auctionAnnounce = L["Hide 'Bidding starts' announcements"],
						auctionAnnounceRW = L["Hide 'Bidding starts' announcements from raid warning"],
						newBid = L["Hide 'New highest bidder' announcements"],
						secondsRemaining = L["Hide 'Time remaining' announcements"],
						bidFinished = L["Hide 'Auction finished' announcements"],
						bidChats = L["Hide players' bid messages"],
						potValues = L["Hide 'Current pot:' announcements"],
						auctionCancel = L["Hide 'Auction cancelled' announcements"],
						auctionCancelRW = L["Hide 'Auction cancelled' announcements from raid warning"],
					},
					set = function(info, key, value) MMMGdkp.opt.hideChatMessages[key] = value end,
					get = function(info, key) return MMMGdkp.opt.hideChatMessages[key] end,
					order = 3,
					width = "full",
				},
				frameAlpha = {
					type = "range",
					min = 0,
					max = 1,
					bigStep = 0.1,
					name = L["Frame alpha"],
					order = 4,
					set = function(info, value) MMMGdkp.opt.appearAlpha = value for _, f in ipairs(MMMGdkp.frames) do f:SetAlpha(value) end end,
					get = function() return MMMGdkp.opt.appearAlpha end,
				},
				frameScale = {
					type = "range",
					min = 0.01,
					softMin = 0.5,
					softMax = 2,
					name = L["Frame scale"],
					order = 5,
					set = function(info, value) MMMGdkp.opt.appearScale = value
						for _, f in ipairs(MMMGdkp.frames) do f:SetScale(value) end
						MMMGdkp_Anchor
							:SetScale(value)
					end,
					get = function() return MMMGdkp.opt.appearScale end,
				},
				bidButtonReenableDelay = {
					type = "range",
					min = 0,
					max = 10,
					softMax = 1,
					softMin = 0,
					name = L["Bid button re-enable delay"],
					order = 6,
					set = function(info, value) MMMGdkp.opt.bidButtonReenableDelay = value end,
					get = function() return MMMGdkp.opt.bidButtonReenableDelay end,
				},
				controlScale = {
					type = "range",
					min = 0.01,
					softMin = 0.5,
					softMax = 2,
					name = L["Control panel scale"],
					order = 7,
					set = function(info, value)
						MMMGdkp.opt.controlScale = value
						MMMGdkp.status:SetScale(value)
						MMMGdkp.history:SetScale(value)
						MMMGdkp.version:SetScale(value)
					end,
					get = function() return MMMGdkp.opt.controlScale end,
				},
				useSlimML = {
					type = "toggle",
					set = function(info, value) if value and (not MMMGdkp.opt.slimMLConfirmed) then StaticPopup_Show("MMMGdkp_SLIMMLWARN") else MMMGdkp
								.opt.slimML = value
						end
					end,
					get = function() return MMMGdkp.opt.slimML end,
					name = L["Use slim bidding window even while Master Looter"],
					width = "full",
					order = 8,
				},
				forceHideShow = {
					type = "toggle",
					set = function(info, value) MMMGdkp.opt.forceHideShow = value
						for _, f in ipairs(MMMGdkp.frames) do f.hide:SetAlpha(value
								and 1 or 0)
						end
					end,
					get = function() return MMMGdkp.opt.forceHideShow end,
					order = 8.5,
					width = "full",
					name = L["Always show the \"Hide\" button on bid frames"],
				},
				anchorBalance = {
					type = "toggle",
					set = function(info, value) MMMGdkp.opt.anchorBalance = value MMMGdkp.balance:UpdatePosition() end,
					get = function() return MMMGdkp.opt.anchorBalance end,
					name = L["Anchor balance window to status window"],
					width = "full",
					order = 9,
				},
			},
			order = 2,
		},
		notification = {
			type = "group",
			name = L["Notification options"],
			args = {
				rules = {
					type = "input",
					name = L["Rules"],
					order = 1,
					multiline = true,
					get = function() return MMMGdkp.opt.rulesString or "" end,
					set = function(info, value)
						MMMGdkp.opt.rulesString = strlen(value) > 0 and value
						if MMMGdkp.opt.rulesString then
							MMMGdkp.status.rules:Enable()
						else
							MMMGdkp.status.rules:Disable()
						end
					end,
					width = "full",
				},
				notifyVersions = {
					type = "multiselect",
					name = L["Version notifications"],
					values = {
						notifyCompatibleOutdated = L["Notify outdated versions that are compatible with your version"],
						notifyIncompatibleOutdated = L["Notify outdated versions that aren't compatible with your version"],
						notifyNotInstalled = L["Notify raid members that do not have MMMGdkp installed"],
					},
					set = function(info, key, value) MMMGdkp.opt.notifyVersions[key] = value end,
					get = function(info, key) return MMMGdkp.opt.notifyVersions[key] end,
					order = 2,
					width = "full",
				},
			},
			order = 3,
		},
		visibility = {
			type = "group",
			name = L["Visibility settings"],
			args = {
				hideCombatFrames = {
					type = "multiselect",
					name = L["Hide frames in combat"],
					values = {
						status = L["Hide status and balance windows"],
						history = L["Hide history window"],
						vercheck = L["Hide version check window"],
					},
					set = function(info, key, value)
						MMMGdkp.opt.hideCombat[key] = value
						MMMGdkp.status:UpdateVisibility()
						MMMGdkp.playerBalance:UpdateVisibility()
						if InCombatLockdown() then
							if key == "history" and value then
								MMMGdkp.history:Hide()
							end
							if key == "vercheck" and value then
								MMMGdkp.version:Hide()
							end
						end
					end,
					get = function(info, key) return MMMGdkp.opt.hideCombat[key] end,
					order = 1,
					width = "full",
				},
			},
			order = 4,
		},
	},
}

function MMMGdkp:OnProfileEnable()
	self.opt = self.db.profile
	for _, f in ipairs(self.frames) do
		f:SetAlpha(self.opt.appearAlpha)
		f:SetScale(self.opt.appearScale)
	end
	MMMGdkp_Anchor:SetScale(self.opt.appearScale)
end

MMMGdkp:SetScript("OnEvent", function(self, event, ...)
	local arg = emptytable(...)
	if event == "ADDON_LOADED" and arg[1] == "MMMGdkp" then
		self:UnregisterEvent("ADDON_LOADED")
		local isFirstLogin = not (MMMGdkp_PotData or MMMGdkp_BalanceData)
		MMMGdkp_PotData = MMMGdkp_PotData or { history = {}, potAmount = 0 }
		--seperate line for savedvar upgrading purposes
		MMMGdkp_PotData.curPotHistory = MMMGdkp_PotData.curPotHistory or {}
		MMMGdkp_PotData.playerBalance = MMMGdkp_PotData.playerBalance or {}
		setmetatable(MMMGdkp_PotData.playerBalance, { __index = function() return 0 end })
		MMMGdkp_BalanceData = MMMGdkp_BalanceData or {}
		setmetatable(MMMGdkp_BalanceData, { __index = function() return 0 end })
		self.status:Update()
		self.db = LibStub("AceDB-3.0"):New("MMMGdkp_DB", defaults or {})
		self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileEnable")
		self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileEnable")
		self.db.RegisterCallback(self, "OnProfileReset", "OnProfileEnable")
		self.opt = self.db.profile
		if not self.db.global.shownPopupAddonMsg4_2 then
			self.db.global.shownPopupAddonMsg4_2 = true
			if not isFirstLogin then
				-- the user has moved the window, so he's already logged in
				-- at least i hope nobody will have their MMMGdkp windows in the center of their screen
				StaticPopup_Show("MMMGdkp_42_ADDONMSG")
			end
		end
		MMMGdkp_Anchor:SetScale(self.opt.appearScale)
		self.status:SetScale(self.opt.controlScale)
		if self.opt.rulesString then
			self.status.rules:Enable()
		else
			self.status.rules:Disable()
		end
		self.history:SetScale(self.opt.controlScale)
		self.version:SetScale(self.opt.controlScale)
		self.options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
		self.options.args.profiles.order = -1
		LibStub("AceConfig-3.0"):RegisterOptionsTable("MMMGdkp", self.options)
		SlashCmdList["MMMGdkp"] = function(input)
			local cmd, link = input:match("(%S+)%s+(|c........|Hitem:.+|r)")
			local _, _, customStartPrice = input:match("(%S+)%s+(|c........|Hitem:.+|r)%s+(%S+)")
			if (cmd and cmd:lower() == "a") and link then
				if self:PlayerIsML((UnitName("player")), true) then
					for itemLink in string.gmatch(link, "|c........|Hitem:.-|r") do
						local itemID = tonumber(itemLink:match("|Hitem:(%d+):"))
						self:QueueAuction(itemLink, MMMGdkp:GetStartBid(itemID, customStartPrice), MMMGdkp:GetMinIncrement(itemID))
					end
				else
					print(L["Cannot start auction without Master Looter privileges."])
				end
			elseif input:lower() == "ver" then
				print(L["MMMGdkp version %s. Packaged %s."]:format(DEBUGFORCEVERSION or "2.0.0", "2020-01-01T00:00:00Z"))
			elseif input:lower() == "history" then
				MMMGdkp.history:Show()
			elseif input:lower() == "wipe" then
				StaticPopup_Show("MMMGdkp_WIPEHISTORY")
			elseif input:lower() == "vercheck" then
				MMMGdkp.version:Show()
			else
				LibStub("AceConfigDialog-3.0"):Open("MMMGdkp")
			end
		end

		--Minimap Icon Creation
		self.LDB = LibStub("LibDataBroker-1.1"):NewDataObject(addonName, {
			type = "data source",
			text = addonName,
			icon = "Interface\\AddOns\\" .. addonName .. "\\Images\\MMMGdkp.tga",
			OnClick = function(self, button, down)
				if button == "LeftButton" then
					LibStub("AceConfigDialog-3.0"):Open("MMMGdkp")
				end
			end,
			OnTooltipShow = function(tooltip)
				tooltip:AddLine(addonName .. " (Wrath Classic)")
				tooltip:AddLine("Automate Your GDKP Auctions, Bids, & Payouts", 255, 255, 255, false)
				tooltip:AddLine(" ")
				tooltip:AddLine("Click|cffffffff : Open Settings|r ")
			end
		})

		self.minimapicon = LibStub("LibDBIcon-1.0")
		self.minimapicon:Register("MMMGdkpLDB", self.LDB, self.db.global)

		SLASH_MMMGdkp1 = "/MMMGdkp"
		SLASH_MMMGdkp2 = "/gdkp"
		SLASH_MMMGdkp3 = "/mg"
		anchor:SetPoint(self.opt.point.point, UIParent, self.opt.point.relative, self.opt.point.x, self.opt.point.y)
		self:SetMovable(self.opt.movable)
		self.status.header:SetPoint(self.opt.statuspoint.point, UIParent, self.opt.statuspoint.relative, self.opt.statuspoint.x
			, self.opt.statuspoint.y)
		--self.balance.header:SetPoint(self.opt.balancepoint.point, UIParent, self.opt.balancepoint.relative, self.opt.balancepoint.x, self.opt.balancepoint.y)
		self.balance:UpdatePosition()
		self.playerBalance.header:SetPoint(self.opt.playerbalancepoint.point, UIParent, self.opt.playerbalancepoint.relative,
			self.opt.playerbalancepoint.x, self.opt.playerbalancepoint.y)
		self.playerBalance:Update()
		self.status:UpdateVisibility()
		MMMGdkp.opt.allowMultipleAutions = true
		MMMGdkp.opt.showAuctionDurationTimer = true
		MMMGdkp.opt.showAuctionDurationTimerText = true
	end
	if (event == "CHAT_MSG_SYSTEM") then
		local msg, sender = arg[1], pruneCrossRealm(arg[2])
		local rollPattern = "(.+) rolls (%d+) %((%d+)%-(%d+)%)"
		local name, roll, rollMin, rollMax = msg:match(rollPattern)
		if (name and roll and rollMin and rollMax) then
			rollMin = tonumber(rollMin)
			name = pruneCrossRealm(name)
			roll = roll - rollMin + 1
			local itemId = rollMin
			if (MMMGdkp_ProcessingItems[itemId] ~= nil) then
				if (MMMGdkp_ProcessingItems[itemId].maxRoll < roll) then
					MMMGdkp_ProcessingItems[itemId].maxRoll = roll
					SendChatMessage(("%s rolls on item %s: %d HIGHEST ROLL!"):format(name, 
						MMMGdkp_ProcessingItems[itemId].itemLink, roll),
						(self.opt.announceBidRaidWarning and (IsRaidOfficer() or IsRaidLeader())) and "RAID_WARNING" or "RAID")
				else
					SendChatMessage(("%s rolls on item %s: %d"):format(name,
						MMMGdkp_ProcessingItems[itemId].itemLink, roll),
						(self.opt.announceBidRaidWarning and (IsRaidOfficer() or IsRaidLeader())) and "RAID_WARNING" or "RAID")
				end
			end
		end
	end
	if (event == "CHAT_MSG_RAID") or (event == "CHAT_MSG_RAID_LEADER") or (event == "CHAT_MSG_RAID_WARNING") then
		local msg, sender = arg[1], pruneCrossRealm(arg[2])
		
		-- this is code for single-auction mode. put into a do branch to avoid local clashes.
		-- deleted
		-- this is new code for multi-auction. slight variations are used rl-side to indicate this.
		do
			local highestName, rollItemLink, rollPoint = string.match(msg, "(%S+) rolls on item (|c........|Hitem:.+|r): (%d+) HIGHEST ROLL!")
			if highestName and rollItemLink then
				local f = self:FetchFrameFromLink(rollItemLink)
				local aucdata = self.curAuctions[rollItemLink]
				if (f ~= nil and aucdata ~= nil) then
					aucdata.bidders[1].bidderName = highestName
					f.highestbid:SetText(("Top roller: %s (%d)"):format(highestName, rollPoint))
				end
			end

			local itemLink, minBid, bidIncrement, maxBid, auctionTimer, auctionTimerRefresh = string.match(msg,
				"Bidding starts on (|c........|Hitem:.+|r). Starting bid (%d+)g, minimum increment (%d+)g. Maximum bid (%d+)g. TTL: (%d+)/(%d+)")

			auctionTimer = tonumber(auctionTimer) or 0
			auctionTimerRefresh = tonumber(auctionTimerRefresh) or 0
			
			if itemLink and self:PlayerIsML(sender, false) then
				
				local itemId = GetItemInfoFromHyperlink(itemLink)
				MMMGdkp_ProcessingItems[itemId] = {}
				MMMGdkp_ProcessingItems[itemId].itemLink = itemLink
				MMMGdkp_ProcessingItems[itemId].maxRoll = 0
				if not self.ignoredLinks[itemLink] then

					local itemId = GetItemInfoFromHyperlink(itemLink)
					LargeBidItems[itemId] = tonumber(maxBid);
					local f = MMMGdkp:FetchFrameFromLink(itemLink)
					if not f then
						f = self:GetUnoccupiedFrame()
						f:SetItem(itemLink)
						f.isActive = true
						f:Show()
					end
					f.rolled = false
					f.isMultiBid = true
					f.bidIncrement = bidIncrement
					f:SetCurBid(minBid, false, false, true)
					f:SetAuctionTimer(auctionTimer, auctionTimerRefresh)
					if f.maxAutoBid then
						local newBid = tonumber(minBid)
						if newBid < f.maxAutoBid then
							SendChatMessage(itemLink .. " " .. newBid)
						end
					end
				else
					self.ignoredLinks[itemLink] = nil
				end
			end
			
			local bidItemLink, bidAmount = msg:match("(|c........|Hitem:.+|r)%s*([0-9]+%.?[0-9]*)[kK]")
            if not bidItemLink then
                bidItemLink, bidAmount = msg:match("(|c........|Hitem:.+|r)%s*(%d+)")
            else
                bidAmount = math.floor(bidAmount * 1000)
            end
			if bidItemLink then
				if self.curAuctions[bidItemLink] then
					local aucdata = self.curAuctions[bidItemLink]

					local itemId = GetItemInfoFromHyperlink(bidItemLink)
					maxBid = MaxBidSmall
					if (LargeBidItems[itemId]) then
						maxBid = LargeBidItems[itemId]
					end
					aucdata.maxBid = maxBid 
					bidAmount = tonumber(bidAmount)
					if (aucdata.curBid + aucdata.increment) <= bidAmount or maxBid <= bidAmount then
						aucdata.curBid = bidAmount
						if aucdata.bidders[sender] then
							aucdata.bidders[aucdata.bidders[sender]].bidAmount = bidAmount
						else
							tinsert(aucdata.bidders, { bidAmount = bidAmount, bidderName = sender })
							aucdata.bidders[sender] = #aucdata.bidders
						end
						SendChatMessage(("New highest bidder on %s: %s (%d gold)"):format(bidItemLink, sender, bidAmount),
							(self.opt.announceBidRaidWarning and (IsRaidOfficer() or IsRaidLeader())) and "RAID_WARNING" or "RAID")
						aucdata.timeRemains = math.max(aucdata.timeRemains, self.opt.auctionTimerRefresh)
					end
				end
			end
			local bidItem, bidderName, newBid = string.match(msg,
				"New highest bidder on (|c........|Hitem:.+|r): (%S+) %((%d+) gold%)")
			if bidderName and self:FetchFrameFromLink(bidItem) then
				local isSelf = pruneCrossRealm(bidderName) == (UnitName("player"))
				local bidFrame = self:FetchFrameFromLink(bidItem)
				bidFrame:SetCurBid(newBid, bidderName, isSelf)
				bidFrame:ResetAuctionTimer()
				if not isSelf then
					if bidFrame.maxAutoBid then
						local myNewBid = newBid + bidFrame.bidIncrement
						if myNewBid <= bidFrame.maxAutoBid then
							SendChatMessage(bidItem .. " " .. myNewBid, "RAID")
						end
					end
				end
			end
			local osItem = msg:match("(|c........|Hitem:.+|r) is OS wanted")
			if osItem then 
				local aucdata = self.curAuctions[osItem]
				if (aucdata) then
					local f = self:FetchFrameFromLink(osItem)
					if (aucdata.bidders[1] == nil and f) then
						f.highestbid:SetText("OS Requested")
						f.highestbid:Show()
					end

					if (aucdata.canOs) then
						aucdata.osWanted = true
					else
						SendChatMessage(("%s is already on OS auction."):format(osItem), "RAID")
					end
				end
			end
			local auctionEndItem = msg:match("Auction finished for (|c........|Hitem:.+|r).")
			if auctionEndItem and MMMGdkp:PlayerIsML(sender, false) and self:FetchFrameFromLink(auctionEndItem) then
				local f = self:FetchFrameFromLink(auctionEndItem)
				local itemId = GetItemInfoFromHyperlink(auctionEndItem)
				MMMGdkp_ProcessingItems[itemId] = nil
				f.isActive = false
				f:Hide()
				local winnerName, paymentString = msg:match("Auction finished for |c........|Hitem:.+|r%. Winner: (%S+)%. (.+)")
				if winnerName then
					if pruneCrossRealm(winnerName) == (UnitName("player")) then
						for targetAmount, targetName in paymentString:gmatch("(%d+) to (%S+)[%.,]") do
							local tarName = pruneCrossRealm(targetName)
							if MMMGdkp:PlayerIsML((UnitName("player")), true) then
								MMMGdkp_PotData.playerBalance[tarName == "pot" and sender or tarName] = MMMGdkp_PotData.playerBalance[
									tarName == "pot" and sender or tarName] + targetAmount
								MMMGdkp.balance:Update()
							else
								MMMGdkp_BalanceData[tarName == "pot" and sender or tarName] = MMMGdkp_BalanceData[
									tarName == "pot" and sender or tarName] + targetAmount
								MMMGdkp.playerBalance:Update()
							end
						end
					else
						for targetAmount, targetName in paymentString:gmatch("(%d+) to (%S+)[%.,]") do
							if pruneCrossRealm(targetName) == (UnitName("player")) then
								if MMMGdkp:PlayerIsML((UnitName("player")), true) then
									MMMGdkp_PotData.playerBalance[winnerName] = MMMGdkp_PotData.playerBalance[winnerName] - targetAmount
									MMMGdkp.balance:Update()
								else
									MMMGdkp_BalanceData[winnerName] = MMMGdkp_BalanceData[winnerName] - targetAmount
									MMMGdkp.playerBalance:Update()
								end
							end
						end
					end
				end
			end
			local auctionCancelItem = msg:match("Auction cancelled for (|c........|Hitem:.+|r)%.")
			if auctionCancelItem and MMMGdkp:PlayerIsML(sender, false) and self:FetchFrameFromLink(auctionCancelItem) then
				local itemId = GetItemInfoFromHyperlink(auctionCancelItem)
				MMMGdkp_ProcessingItems[itemId] = nil
				local f = self:FetchFrameFromLink(auctionCancelItem)
				f.isActive = false
				if MMMGdkp:PlayerIsML((UnitName("player")), true) then
					f.timer:Hide()
					f.timer.update:Hide()
					f.curbid:Hide()
					f.highestbidder:Hide()
					f.highestbid:Hide()
					f.bidbox:Hide()
					f.bid:Disable()
					f.autobid:Disable()
				else
					f:Hide()
				end
			end
		end
		-- generic code for both auction modes
		do
			local potAmount = msg:match("Distributing pot. Pot size: %d+ gold. Amount to distribute: %d+ gold. Players in raid: %d+. Share per player: (%d+) gold.")
			if not potAmount then
				potAmount = msg:match("Distributing pot. Pot size: %d+ gold. Players in raid: %d+. Pot share per player: (%d+) gold.")
			end
			if potAmount and self:PlayerIsML(sender, false) then
				MMMGdkp_BalanceData[sender] = MMMGdkp_BalanceData[sender] - potAmount
				MMMGdkp.playerBalance:Update()
			end
		end
	end
	if (event == "CHAT_MSG_ADDON") then
		local sender = pruneCrossRealm(arg[4])
		if sender then
			if arg[1] == "MMMGdkp VER" then
				print(sender .. ": " .. arg[2])
			end
			if arg[1] == "MMMGdkp CHECK" then
				local message = tonumber(arg[2]) == MMM_Version_Id and MMM_Version_Id or MMM_Version_Id .. " - NEEDS UPDATE to latest: " .. arg[2]
				SendAddonMessage("MMMGdkp VER", message, "RAID")

			end
			if arg[1] == "MMMGdkp START" and self:PlayerIsML(sender, false) then
				if not self:FetchFrameFromLink(arg[2]) then
					local f = self:GetUnoccupiedFrame()
					f.isActive = true
					f:SetItem(arg[2])
					f:Show()
				end
			end
			if arg[1] == "MMMGdkp VREQ" then
				SendAddonMessage("MMMGdkp VDATA", DEBUGFORCEVERSION or "2.0.0", "WHISPER", arg[4])
			end
			if arg[1] == "MMMGdkp VDATA" then
				self.versions[sender] = arg[2]
				self.version:Update()
			end
			if arg[1] == "MMMGdkp MANADJ" and self:PlayerIsML(sender, false) then
				MMMGdkp_BalanceData[sender] = MMMGdkp_BalanceData[sender] + arg[2]
				MMMGdkp.playerBalance:Update()
			end
		end
	end
	if (event == "LOOT_CLOSED") then
		self.status.announcetext:Hide()
		self.status.announce1:Hide()
		self.status.announce2:Hide()
		self.status.noannounce:Hide()
		self.status:UpdateSize()
	end
	if (event == "LOOT_OPENED") and self:PlayerIsML((UnitName("player")), true) then
		self.status.announcetext:Show()
		self.status.announce1:Show()
		self.status.announce2:Show()
		self.status.noannounce:Show()
		self.status:UpdateSize()
	end
	if (event == "GROUP_ROSTER_UPDATE") or (event == "PARTY_LOOT_METHOD_CHANGED") then
		self.status:UpdateVisibility()
		--[[if self:PlayerIsML((UnitName("player")),true) then
			self.status:Show()
		else
			self.status:Hide()
		end--]]
	end
	if (event == "UNIT_NAME_UPDATE") then
		if UnitIsUnit("player", arg[1]) then
			self:UnregisterEvent("UNIT_NAME_UPDATE")
			self.status:UpdateVisibility()
		end
	end
	if (event == "TRADE_CLOSED") then
		self.isTrading = false
	end
	if (event == "TRADE_SHOW") then
		self.isTrading = true
		self.tradePartner = (GetUnitName("npc", true))
		self.tradeMoneySelf = 0
		self.tradeMoneyOther = 0
		self.balance:Update()
	end
	if (event == "TRADE_ACCEPT_UPDATE") and (arg[1] == 1) then
		self.tradeMoneySelf = GetPlayerTradeMoney() / 10000
	end
	if (event == "TRADE_MONEY_CHANGED") then
		self.tradeMoneyOther = GetTargetTradeMoney() / 10000
	end
	if (event == "UI_INFO_MESSAGE") then
		if arg[2] == ERR_TRADE_COMPLETE then
			--if self:PlayerIsML((UnitName("player")),true) and MMMGdkp_PotData.playerBalance[self.tradePartner] ~= 0 then
			if self:PlayerIsML((UnitName("player")), true) then
				if MMMGdkp_PotData.playerBalance[self.tradePartner] ~= 0 then
					local moneyChange = (self.tradeMoneyOther) - (self.tradeMoneySelf)
					local curBalancePot, curBalancePlayer = MMMGdkp_PotData.playerBalance[self.tradePartner],
						MMMGdkp_BalanceData[self.tradePartner]
					if moneyChange > 0 then
						--[[if curBalancePot+moneyChange > 0 then
							moneyChange = moneyChange-(curBalancePot*(-1))
							MMMGdkp_PotData.playerBalance[self.tradePartner] = 0
							if (curBalancePlayer ~= 0 or GetRealNumRaidMembers() > 0) then
								MMMGdkp_BalanceData[self.tradePartner] = curBalancePlayer+moneyChange
							end
						else--]]
						MMMGdkp_PotData.playerBalance[self.tradePartner] = curBalancePot + moneyChange
						--end
					elseif moneyChange < 0 then
						--[[if curBalancePot+moneyChange < 0 then
							moneyChange = moneyChange+(curBalancePot*(-1))
							MMMGdkp_PotData.playerBalance[self.tradePartner] = 0
							if (curBalancePlayer ~= 0 or GetRealNumRaidMembers() > 0) then
								MMMGdkp_BalanceData[self.tradePartner] = curBalancePlayer+moneyChange
							end
						else--]]
						MMMGdkp_PotData.playerBalance[self.tradePartner] = curBalancePot + moneyChange
						--end
					end
				end
			elseif MMMGdkp_BalanceData[self.tradePartner] ~= 0 then
				MMMGdkp_BalanceData[self.tradePartner] = MMMGdkp_BalanceData[self.tradePartner] - (self.tradeMoneySelf) +
					(self.tradeMoneyOther)
			end
			MMMGdkp.balance:Update()
			MMMGdkp.playerBalance:Update()
		end
	end
	if (event == "PLAYER_REGEN_ENABLED") then
		self.status:UpdateVisibility(false)
		self.playerBalance:UpdateVisibility(false)
	end
	if (event == "PLAYER_REGEN_DISABLED") then
		self.status:UpdateVisibility(true)
		self.playerBalance:UpdateVisibility(true)
	end
	if (event == "MAIL_CLOSED") or (event == "MAIL_INBOX_UPDATE") then
		self.balance:Update()
	end
	-- release table back into the pool of usable tables
	arg:Release()
end)
MMMGdkp:RegisterEvent("ADDON_LOADED")
MMMGdkp:RegisterEvent("CHAT_MSG_RAID")
MMMGdkp:RegisterEvent("CHAT_MSG_RAID_LEADER")
MMMGdkp:RegisterEvent("CHAT_MSG_RAID_WARNING")
MMMGdkp:RegisterEvent("LOOT_OPENED")
MMMGdkp:RegisterEvent("LOOT_CLOSED")
MMMGdkp:RegisterEvent("GROUP_ROSTER_UPDATE")
MMMGdkp:RegisterEvent("PARTY_LOOT_METHOD_CHANGED")
MMMGdkp:RegisterEvent("UNIT_NAME_UPDATE")
MMMGdkp:RegisterEvent("CHAT_MSG_ADDON")
MMMGdkp:RegisterEvent("TRADE_MONEY_CHANGED")
MMMGdkp:RegisterEvent("UI_INFO_MESSAGE")
MMMGdkp:RegisterEvent("TRADE_CLOSED")
MMMGdkp:RegisterEvent("TRADE_SHOW")
MMMGdkp:RegisterEvent("TRADE_ACCEPT_UPDATE")
MMMGdkp:RegisterEvent("PLAYER_TRADE_MONEY")
MMMGdkp:RegisterEvent("PLAYER_REGEN_ENABLED")
MMMGdkp:RegisterEvent("PLAYER_REGEN_DISABLED")
MMMGdkp:RegisterEvent("MAIL_INBOX_UPDATE")
MMMGdkp:RegisterEvent("MAIL_CLOSED")
MMMGdkp:RegisterEvent("CHAT_MSG_SYSTEM")


--chat filters
local function filterChat_CHAT_MSG_RAID(chatframe, event, msg)
	--auctionAnnounce newBid bidFinished
	if MMMGdkp.opt.hideChatMessages.auctionAnnounce and msg:match("Bidding starts on (|c........|Hitem:.+|r).") then
		return true
	end
	if MMMGdkp.opt.hideChatMessages.newBid and msg:match("New highest bidder(.*): (%S+) %((%d+) gold%)") then
		return true
	end
	if MMMGdkp.opt.hideChatMessages.bidFinished and msg:match("Auction finished") then
		return true
	end
	if MMMGdkp.opt.hideChatMessages.secondsRemaining and msg:match("[Caution] (%d+) seconds remaining(.*)!") then
		return true
	end
	if MMMGdkp.opt.hideChatMessages.bidChats and
		(
		((msg:match("%d+") and (not msg:match("seconds remaining"))) and (MMMGdkp.InProgressBidFrame or MMMGdkp.curAuction.item))
			or
			(
			msg:match("(|c........|Hitem:.+|r)%s*(%d+)") and
				(
				MMMGdkp:FetchFrameFromLink(msg:match("(|c........|Hitem:.+|r)")) or
					MMMGdkp.curAuctions[msg:match("(|c........|Hitem:.+|r)")]))) then
		return true
	end
	if MMMGdkp.opt.hideChatMessages.potValues and msg:match("Current pot: (%d+) gold") then
		return true
	end
	if MMMGdkp.opt.hideChatMessages.auctionCancel and msg:match("Auction cancelled") then
		return true
	end
	return false
end

--register chat filters
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", filterChat_CHAT_MSG_RAID)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_WARNING", filterChat_CHAT_MSG_RAID)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", filterChat_CHAT_MSG_RAID)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", function(chatframe, event, msg)
	if msg:find(L[
		"Your version of MMMGdkp is slightly outdated compared to the raid leader's. Full compability should be possible, however, you might want to take some time and update MMMGdkp."
		]:gsub("%[", "%%["):gsub("%]", "%%]")) then
		return true
	end
	if msg:find(L[
		"Your version of MMMGdkp is outdated and no longer compatible with the raid leader's in one or more functionalities. In order to ensure smooth performance, please update MMMGdkp."
		]:gsub("%[", "%%["):gsub("%]", "%%]")) then
		return true
	end
	if msg:find(L[
		"This raid uses MMMGdkp to faciliate its GDKP bidding process. While you can bid on items without having MMMGdkp installed, installing it provides you with a GUI bidding panel, auto bidding functions, auction timers, chat filtering and more!"
		]:gsub("%[", "%%["):gsub("%]", "%%]")) then
		return true
	end
end)
--chat filters done
--filter raid warning frame
do
	-- GLOBALS: RaidNotice_AddMessage
	local oldmessage = RaidNotice_AddMessage
	function RaidNotice_AddMessage(frame, text, ...)
		if MMMGdkp.opt.hideChatMessages.auctionAnnounceRW and text:match("Bidding starts on (|c........|Hitem:.+|r).") then
			return
		end
		if MMMGdkp.opt.hideChatMessages.auctionCancelRW and text:match("Auction cancelled") then
			return
		end
		if MMMGdkp.opt.hideChatMessages.newBid and text:match("New highest bidder(.*): (%S+) %((%d+) gold%)") then
			return
		end
		oldmessage(frame, text, ...)
	end
end
--end raid warning frame filter
--register addon msg prefixes
C_ChatInfo.RegisterAddonMessagePrefix("MMMGdkp CHECK")
C_ChatInfo.RegisterAddonMessagePrefix("MMMGdkp VER")
C_ChatInfo.RegisterAddonMessagePrefix("MMMGdkp START")
C_ChatInfo.RegisterAddonMessagePrefix("MMMGdkp VREQ")
C_ChatInfo.RegisterAddonMessagePrefix("MMMGdkp VDATA")
C_ChatInfo.RegisterAddonMessagePrefix("MMMGdkp MANADJ")
--prefixes done