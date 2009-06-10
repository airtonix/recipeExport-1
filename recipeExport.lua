recipeExport = CreateFrame("Frame", 'recipeExport', UIParent)
recipeExport:SetScript('OnEvent', function(self, event, name) if(self[event]) then return self[event](self, event, name) end end)
recipeExport:RegisterEvent("TRADE_SKILL_SHOW")
recipeExport:RegisterEvent("ADDON_LOADED");

function recipeExport:ADDON_LOADED(event, name)
--	if(name ~= 'recipeExport') then return end
--	self:UnregisterEvent(event)
	
	recipeExportDB = recipeExportDB or {}
	for k,v in pairs(self.defaults) do
		if(type(recipeExportDB[k]) == 'nil') then
			recipeExportDB[k] = v
		end
	end
	recipeExport.db = recipeExportDB
	self.db.createTOC = true
	self:CreateOutputWindow()
end

local addon = recipeExport
--		tostring(self.db.template=='html' and "q"..(itemRarity and itemRarity or 1) or "")
addon.rarityColorList={
		"#9d9d9d",
		"#ffffff",
		"#1eff00",
		"#0070dd",
		"#a335ee",
		"#ff8000",
		"#e6cc80",
		"#e6cc80",
	}
addon.template = {
 bbcode = {
   hasToc			= false,
   book				= "[b][size=12pt]%s[/size][/b][i]%s/%s[/i]\n",
   header			= "%s\n[b]%s[/b]\n",
   groupstart	= "[list]",
   groupend		= "[/list]",
   item				= "[*][%s]%s[/url]\n%s",
   linkData 		= "url=%s",
   stats				= "[i]%s[/i]",
   color				= "[color=%s][%s][/color]",  
 },
 html = {
   hasToc			= true,
   book				= "<h3>%s</h3><i>%s/%s</i>\n",
   header			= "<h4 id='%s'>%s</h4>\n",
   groupstart	= "<ul>\n",
   groupend		= "</ul>\n",
   item				= "<li><a %s>[%s]</a>%s</li>\n",
   tocItem		= "<li><a href=\"%s\">%s</a></li>\n",
   linkData		= "href='%s' class='%s'",
   stats				= "<br/><i>%s</i>",
   color				= "<span style='font-color:%s;'>%s</span>",
 },
 markdown = {
   hasToc			= false,
   book				= "### %s\n\n*%s/%s*\n",
   header			= "#### %s %s\n\n",
   groupstart	= "",
   groupend		= "",
   item				= "[%s](%s%s)\n",
   stats				= "*%s*",
   color				= "%s %s",
 },
}
addon.processors = {
	['bbcode'] = function(name,spellid,rarity,urlPrefix,info) 
		local template =addon.template.bbcode		
		local linkdata = format(template.linkData,urlPrefix .. spellid)
		local color = format(template.color,rarity and addon.rarityColorList[rarity] or rarity,name)
		return format(template.item, linkdata , color ,info)
   end,
   ['html'] = function(name, spellid, rarity,urlPrefix,info)
		local template =addon.template.html
		local linkdata = format(template.linkData,urlPrefix .. spellid, (rarity and "q"..rarity or "") )
		return format(template.item, linkdata , name,info)
   end,
   ['markdown']=function(name,spellid,rarity,color,urlPrefix)
   	
   end,
}

addon.db = {}
addon.defaults = {
	['template'] = 'bbcode',
	['siteUrl'] = 'http://www.wowhead.com',
	['spellQueryString'] = '?spell=',	
	['createTOC'] = true,
}
function exportTradeList()
 local txt = addon:renderTradeList(0)
 if not txt then print("No text provided, exiting."); return end
 local window = addon.window
		   window.editor:SetText(txt)
		   window:Show();
		   window.editor:HighlightText()
end




function addon.TRADE_SKILL_SHOW()
	--Export Button
	local button = _G['recipeExportViewRunButton']
	if(not button)then button = CreateFrame("Button", "recipeExportViewRunButton", TradeSkillFrame, "OptionsButtonTemplate"); 	end
	button:SetPoint("LEFT", TradeSkillLinkButton, "RIGHT", 2, 1);
	button:SetScript("OnClick", exportTradeList);
	button:SetNormalTexture("Interface\\ICONS\\INV_Scroll_15")
	button:SetPushedTexture("Interface\\ICONS\\INV_Scroll_16")
	button:SetHighlightTexture("Interface\\ICONS\\INV_Scroll_16")
	button:SetWidth(16)
	button:SetHeight(16)
end

function addon:renderTradeList(iLevelThreshold)
	local tradeSkillsNum, name, type

	local template = self.template[self.db.template]
	local processor = self.processors[self.db.template]
	local urlPrefix = addon.db.siteUrl..addon.db.spellQueryString
	
	local tradeSkillName, currentLevel, maxLevel = GetTradeSkillLine();
	if(tradeSkillName =="UNKNOWN")then print("Tradeskill Window Not Open.");return end
	local output,lastitemtype,toc,id = "","","",""
	local link

	for i=1,GetNumTradeSkills() do
		link = ""
		local name, type, _, _, _ = GetTradeSkillInfo(i);

		if (name and type == "header") then

			if(lastitemtype=="item") then 
				output = output .. template.groupend
			end

			if(self.db.createTOC and template.hasToc)then
				id = string.gsub(tradeSkillName.."_"..name, " ", "_")
				toc = toc .. format(template.tocItem,id,name)
			end

			output = output .. format(template.header, id ,name)   
			output = output .. template.groupstart
			lastitemtype = "header"

		else

			local link = GetTradeSkillRecipeLink(i)
			local item = GetTradeSkillItemLink(i)

			if(item)then
				local _,_,itemString = string.find(item,"^|c%x+|H(.+)|h%[.*%]")
				local itemId = ({strsplit(":", itemString)})[2]
				local itemName, itemLink, itemRarity, iLevel, itemMinLevel, itemType, itemSubType, itemStackCount,itemEquipLoc, itemTexture = GetItemInfo(itemId) 
				if not temRarity or itemRarity == 0 then itemRarity =1 end
				local spellId = link:gmatch("enchant:(.*)[[]")();
				local info = self.verbose and format( template.stats, table.concat(GetTradeSkillItemStats(i), " \n")) or ""
			 	output = output .. processor(name,spellId,itemRarity,urlPrefix,info)
			end

	lastitemtype = "item"
	end

	end
	output = output .. template.groupend
	if(self.db.createTOC)then
	output = format(template.book,tradeSkillName,currentLevel,maxLevel) .. format("<ul>\n%s</ul>\n",toc) .. output
	end
	return output
end

function addon:CreateOutputWindow()
  local window = CreateFrame("Frame", "recipeExportView", UIParent);
  window:SetPoint("TOP", "UIParent", "TOP");
  window:SetFrameStrata("DIALOG");
  window:SetHeight(600);
  window:SetWidth(800);
  window:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 9, right = 9, top = 9, bottom = 9 }
  });
  window:SetBackdropColor(0, 0, 0, 0.8);
  
  --Close Button
  window.closeButton = CreateFrame("Button", "recipeExportViewCloseButton", window, "OptionsButtonTemplate");
  window.closeButton:SetText('close');
  window.closeButton:SetPoint("TOPRIGHT", window, "TOPRIGHT", -10, -6);
  window.closeButton:SetScript("OnClick", function(this) window:Hide(); end);
  
  --ScrollBar
  window.scrollbar = CreateFrame("ScrollFrame", "recipeExportViewScrollBar", window, "UIPanelScrollFrameTemplate");
  window.scrollbar:SetPoint("TOPLEFT", window, "TOPLEFT", 20, -20);
  window.scrollbar:SetPoint("RIGHT", window, "RIGHT", -30, 0);
  window.scrollbar:SetPoint("BOTTOM", window, "BOTTOM", 0, 20);
  
  --TextArea
  window.editor = CreateFrame("EditBox", "recipeExportViewEditBox",window.scrollbar);
  window.editor:SetFontObject("ChatFontNormal");
  window.editor:SetWidth(750);
  window.editor:SetHeight(85);
  window.editor:SetMultiLine(true);
  window.scrollbar:SetScrollChild(window.editor);
  window.editor:SetScript("OnTextChanged", function(this) window.scrollbar:UpdateScrollChildRect(); end);
  window:Hide();
  self.window = window;
  
end

function addon:Help()
end



function addon:ListTemplates()
	self:Print("Currently available templates : ")
	for index,data in pairs(self.template)do
		self:Print( format(tostring(self.db.template==index and "[ %s ]" or "%s"),index) )
	end
end

function addon:Print(msg,error)
	print("|CFF"..(error and "FFFF00" or "00EE00").."recipeExport|r : " ..msg)
end

function addon:Error(msg)
	self:Print(msg,true)
end
addon.commands = {
	["help"] = function(args) 
		addon:Print("/rex /tradex");
		addon:Print(" help : this text")
		addon:Print(" verbose : toggle detailed output ")
		addon:Print(" template set : set template")
		addon:Print(" template list : list templates")
		addon:Print(" template : list templates")
	end,
	["verbose"] = function(args) addon.verbose = not addon.verbose end,
	["template"] = function(args)
		if(not args[2] or args[2]=="list")then
			addon:ListTemplates()
		elseif(args[2]=="set")then
			if(not args[3])then
				addon:Error("Error no template specified")
			else
				addon:Print("template set to "..args[3])
				addon.db.template = args[3]
			end
		else
			
		end
	end,
	["filter"] = function(args) 
		-- /rex filter glyphs minor
		addon.filterType = args[2]
		addon.filterArgs = args[3]
	end,
	["sort"] = function(args) 
		addon.sort = args
	end,
}

SLASH_TRADESKILL1 = "/tradex";
SLASH_TRADESKILL2 = "/rex";
SlashCmdList["TRADESKILL"] = function(cmd)
	if cmd == "" or not cmd then
		addon.commands["help"]()
	else
		local tokens = {}
		for token in cmd:gmatch("%S+") do table.insert(tokens, token) end
		if addon.commands[tokens[1]]then
			addon.commands[tokens[1]](tokens) 
		else
			addon.commands["help"]()
		end
	end		
end

