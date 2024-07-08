local SDC = SimpleDailyCraft
--Dault setting
SDC.Default = {
  CV = false,
  
  Window_Show = true,
  Window_Point = 128,
  Window_rPoint = 128,
  Window_OffsetX = 0,
  Window_OffsetY = 0,
  
  DailyCraft = true,
  MasterCraft = true,
  
  SmithCraft = true,
  CookCraft = true,
  EnchantCraft = true,
  AlchemyCraft = true,
  
  DD_SmithMaterialLeft = 200,
  DD_AlchemyCost = true,
  DD_Research = true,
  DD_Bank = false,
  DD_Announce = false,
  
  QuestAuto = true,
  QuestDelay = 200,
  BQ = true,
  CQ = true,
  WQ = true,
  JQ = true,
  PQ = true,
  EQ = true,
  AQ = true,
  
  OpenBox = true,
  OpenAnniversary = false,
  
  Bank = true,
  OpenBank = false,
  OpenBankAssistant = true,
  CloseBank = true,
  
  DailyRestrict = {},
  DailyRawRestrict = {},
  MasterRestrict = {},
  
  StyleList = {},
}
--Tool function
local function ToLink(Id)
  return "|H0:item:"..Id..":30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
end

-------------------
----Start point----
-------------------

--when addon loaded
local function OnAddOnLoaded(eventCode, addonName)
  if addonName ~= SDC.name then return end
  EVENT_MANAGER:UnregisterForEvent(SDC.name, EVENT_ADD_ON_LOADED)
  
  --Restore from saved setting
  SDC.SV1 = ZO_SavedVars:NewAccountWide("SDC_SaveVars", 1, nil, SDC.Default, GetWorldName())
  SDC.SV2 = ZO_SavedVars:NewCharacterIdSettings("SDC_SaveVars", 1, nil, SDC.Default, GetWorldName())
  SDC.SwitchSV()

  --Reset keybind if error last
  SDC.CV = ZO_SavedVars:NewCharacterIdSettings("SDC_SaveVars2", 1, nil, {["Key"]={}}, GetWorldName())
  SDC.Key()
  
  --Reset bar window
  SDCTopLevel:ClearAnchors()
  SDCTopLevel:SetAnchor(
    SDC.SV.Window_Point,
    GuiRoot,
    SDC.SV.Window_rPoint,
    SDC.SV.Window_OffsetX,
    SDC.SV.Window_OffsetY
  )
  --Initialization for box name
  SDC.IsHaveName = SDC.ToStringTable(SDC.BoxId)
  --Disable anniversary unbox when set
  if not SDC.SV.OpenAnniversary then SDC.IsHaveName[GetItemLinkName(SDC.BoxId[1]):gsub("%^.+", ""):lower()] = false end 
  
  --Register Event
    --Assistant bar info Update
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_PLAYER_ACTIVATED, SDC.QuestUpdate)
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_QUEST_ADDED, SDC.QuestUpdate)
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_QUEST_REMOVED, SDC.QuestUpdate)
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_QUEST_LIST_UPDATED, SDC.QuestUpdate)
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_QUEST_CONDITION_COUNTER_CHANGED, SDC.QuestUpdate)
  
    --Start unboxing after get target containers
  EVENT_MANAGER:RegisterForEvent("SDCOpenDect", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, SDC.OpenBox)
  EVENT_MANAGER:RegisterForEvent("SDCResearch", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, SDC.ResearchHelper)
  
  --Event Used in other position, for avioid repeat 
  --[[
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, Craft Consumable)
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_CRAFT_COMPLETED, Craft Smith)
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_CRAFT_FAILED, Craft fail)
  EVENT_MANAGER:RegisterForEvent("SDCBank", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, SDC.BankProcess)
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_QUEST_OFFERED, SDC.InteractEvent)
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_QUEST_COMPLETE_DIALOG, SDC.InteractEvent)
  --]]
  
  --Register Callback
  SCENE_MANAGER:RegisterCallback("SceneStateChanged", SDC.CraftCore)    --Start craft work
  SCENE_MANAGER:RegisterCallback("SceneStateChanged", SDC.InteractCore) --Start writ/unbox work
  SCENE_MANAGER:RegisterCallback("SceneStateChanged", SDC.LootAll)      --Loot all in box
  SCENE_MANAGER:RegisterCallback("SceneStateChanged", SDC.BankCore)     --Get target from bank
  
  --Callback Used in other position
  --SCENE_MANAGER:RegisterCallback("SceneStateChanged", SDC.WWCore)

  --LAM
  SDC.BuildMenu()
  --Gamepad
  SDC.GamepadMode()
end

--Setting
function SDC.SwitchSV()
  --Account/Character
  if SDC.SV2.CV then
    SDC.SV = SDC.SV2
  else
    SDC.SV = SDC.SV1
  end
  --The first time dauf setting
  if SDC.SV.DailyRestrict[1] == nil then SDC.SV.DailyRestrict = {30152, 30164, 139019, 150731, 150671} end
  if SDC.SV.DailyRawRestrict[1] == nil then SDC.SV.DailyRawRestrict = {"%/"} end
  if SDC.SV.MasterRestrict[1] == nil then SDC.SV.MasterRestrict = {150731, 150671} end
  for key, value in pairs(SDC.SV.StyleList) do
    if value ~= nil then return end
  end
  SDC.SV.StyleList = {unpack(SDC.BasicSytle)}
  SDC.SV.StyleList[34] = 33254
end

-------------------------
----Craft Info Handle----
-------------------------

--Find which style to use
function SDC.MostBasicStyle(Need)
  Need = Need or 0
  local count = -1
  local style = 0
  for StyleIndex, ItemId in pairs(SDC.SV.StyleList) do
    if ItemId ~= nil and IsSmithingStyleKnown(StyleIndex, 1) then --IsKnown
      local stack = GetCurrentSmithingStyleItemCount(StyleIndex)
      if stack > count then --the largest number
        style = StyleIndex
        count = stack
      end
    end
  end
  if count < Need then
    return 0, 0
  end
  return style, count
end

--Smith
function SDC.HandleSmith(IsMaster, a, b)
  local _
  local Tep = {--[[
    1 = patternIndex, 
    2 = materialIndex,
    3 = materialQuantity,
    4 = itemStyleId,
    5 = traitIndex,
    6 = useUniversalStyleItem,
    7 = num to craft,
  ]]}
  local CraftType = 0
  local SetIndex = 0
  local SetId = 0
  local Quality = 1
  local ItemId = 0
  local ItemTep = 0
  local MaterialId = 0
  local TraitType = 0
  local TargetItem = 0
  
  local current, need = GetJournalQuestConditionValues(a, 1, b) 
  Tep[7] = need - current
  if Tep[7] == 0 then return end --Finished
  
  if IsMaster then --Is master writ？
    if ZO_Smithing_IsConsolidatedStationCraftingMode() == false then return end
    _, MaterialId, CraftType, Quality, ItemTep, SetId, TraitType, Tep[4] = GetQuestConditionMasterWritInfo(a, 1, b)
    SetIndex = CONSOLIDATED_SMITHING_SET_DATA_MANAGER.setDataBySetId[SetId].setIndex
    --Set Is Locked
    if not IsConsolidatedSmithingSetIndexUnlocked(SetIndex) then
      SDC.DD(10.5, {GetItemSetName(SetId)})
      return
    end
    SetActiveConsolidatedSmithingSetByIndex(SetIndex)
    Tep[1], Tep[2], TargetItem = GetSmithingPatternInfoForItemSet(ItemTep, SetId, MaterialId, TraitType)
    Tep[5] = TraitType + 1
  else
    ItemId, MaterialId, CraftType = GetQuestConditionItemInfo(a, 1, b)
    Tep[1], Tep[2] = GetSmithingPatternInfoForItemId(ItemId, MaterialId, CraftType)
    Tep[4] = SDC.MostBasicStyle(Tep[7])
    Tep[5] = 1
  end
  if Tep[4] == 0 and CraftType ~= 7 then --No style can use when not jewerly
    SDC.DD(10, {})
    return 
  end 
  Tep[3] = select(3, GetSmithingPatternMaterialItemInfo(Tep[1], Tep[2]))
  Tep[6] = false
  
  table.insert(SDC.CraftList, 
    {
    ["Type"] = CraftType,
    ["IsMaster"] = IsMaster,
    ["Master"] = {
      ["SetIndex"] = SetIndex,
      ["Target"] = TargetItem,
      ["Material"] = MaterialId,
      ["Trait"] = TraitType,
      ["Style"] = Tep[4],
      ["Quality"] = Quality,
    },
    ["Craft"] = Tep,
    }
    )
end

--Alchemy
function SDC.HandleAlchemy(IsMaster, a, b)
  local _
  local Tep = {}
  local CraftType = 0
  local Material = 0
  
  local current, need = GetJournalQuestConditionValues(a, 1, b)
  Tep[3] = need - current
  if Tep[3] == 0 then return end
  
  if IsMaster then
    _, Material, CraftType, _,_,_,_,_, Tep[2] = GetQuestConditionMasterWritInfo(a, 1, b)
    if CraftType == 0 then return end
  else
    Tep[2], Material, CraftType = GetQuestConditionItemInfo(a, 1, b)
    if CraftType == 0 then return end
  end
  Tep[1] = SDC.Alchemy["Level"][Material]

  table.insert(SDC.CraftList,
    {
    ["Type"] = CraftType,
    ["IsMaster"] = IsMaster,
    ["Craft"] = Tep,
    }
  )
end

--Enchat
function SDC.HandleEnchant(IsMaster, a, b)
  local Tep = {}
  local CraftType = 0
  local Target = 0
  local Meterial = 0
  local Quality = 1
  
  local current, need = GetJournalQuestConditionValues(a, 1, b)
  Tep[4] = need - current
  if Tep[4] == 0 then return end
  
  if IsMaster then
    Target, Meterial, CraftType, Quality = GetQuestConditionMasterWritInfo(a, 1, b)
    if CraftType == 0 then return end
  else
    Target, Meterial, CraftType, Quality = GetQuestConditionItemInfo(a, 1, b)
    if CraftType == 0 then return end
  end
  Tep[2] = SDC.Enchant["Id"][Target][2]
  Tep[1] = SDC.Enchant["Level"][Meterial][SDC.Enchant["Id"][Target][1]]
  Tep[3] = SDC.Enchant["Quilty"][Quality]
  table.insert(SDC.CraftList,
    {
    ["Type"] = CraftType,
    ["IsMaster"] = IsMaster,
    ["Craft"] = Tep,
    }
  )
end

--Cook
local Recipes = {} --All Recipes info

function SDC.HandleCook(IsMaster, a, b)
  local Tep = {}
  local CraftType = 0
  if Recipes[33526] == nil then --The first time run
    for x = 1, 40 do
      for y = 1, 1000 do
        local TargetId = select(8, GetRecipeInfo(x, y)) --Get recipe info (index, index)
        if TargetId == 0 then
          break
        else
          Recipes[TargetId] = {x, y}
        end
      end
    end
  end
  
  local current, need = GetJournalQuestConditionValues(a, 1, b)
  Tep[3] = need - current
  if Tep[3] == 0 then return end
  
  if IsMaster then
    local Target, _, CraftType = GetQuestConditionMasterWritInfo(a, 1, b)
    if CraftType == 0 then return end
    Tep[1], Tep[2] = unpack(Recipes[Target])
  else
    local Target, _, CraftType = GetQuestConditionItemInfo(a, 1, b)
    if CraftType == 0 then return end
    Tep[1], Tep[2] = unpack(Recipes[Target])
  end
  table.insert(SDC.CraftList,
    {
    ["Type"] = CraftType,
    ["IsMaster"] = IsMaster,
    ["Craft"] = Tep,
    }
  )
end

--Which function to handle craft info
local function HandleFunction(CraftType, IsMaster, a, b)
  if not SDC.SV.DailyCraft and not IsMaster then return end     --Ban daily craft
  if not SDC.SV.MasterCraft and IsMaster then return end        --Ban master craft
  if CraftType == 3 and not SDC.SV.EnchantCraft then return end --Ban Enchant craft
  if CraftType == 4 and not SDC.SV.AlchemyCraft then return end --Ban Alchemy craft
  if CraftType == 5 and not SDC.SV.CookCraft then return end    --Ban Cook craft
  
  if CraftType == 3 then SDC.HandleEnchant(IsMaster, a, b) return end
  if CraftType == 4 then SDC.HandleAlchemy(IsMaster, a, b) return end
  if CraftType == 5 then SDC.HandleCook(IsMaster, a, b) return end
  
  if not SDC.SV.SmithCraft then return end                      --Ban Smith craft
  SDC.HandleSmith(IsMaster, a, b)
end

--To find the craft writ for current station
function SDC.QuestCheck(CurrentType)
  SDC.CraftList = {}
  for a = 1, 25 do  --Look up all journal quests
    local Type = select(10, GetJournalQuestInfo(a))  
    if Type == 4 then -- Craft quests
      if GetQuestConditionMasterWritInfo(a, 1, 1) then --Master Writ
        local _,_, CraftType = GetQuestConditionMasterWritInfo(a, 1, 1)
        if CraftType == CurrentType then HandleFunction(CraftType, true, a, 1) end
      else
        for b = 1, 6 do --Normal daily craft
          local ItemId, MaterialId, CraftType = GetQuestConditionItemInfo(a, 1, b)
          if CraftType == CurrentType then HandleFunction(CraftType, false, a, b) end
        end
      end
    end
  end
end

-----------------------------------------------
----Bar Display & Bank target & Writ status----
-----------------------------------------------

local Icon = {
  [1] = "|t40:40:esoui/art/inventory/inventory_tabicon_craftbag_blacksmithing_up.dds:inheritColor|t",  --BlackSmith
  [2] = "|t40:40:esoui/art/inventory/inventory_tabicon_craftbag_clothing_up.dds:inheritColor|t", --Cloth
  [3] = "|t40:40:esoui/art/inventory/inventory_tabicon_craftbag_enchanting_up.dds:inheritColor|t", --Enchat
  [4] = "|t40:40:esoui/art/inventory/inventory_tabicon_craftbag_alchemy_up.dds:inheritColor|t", --Alchmy
  [5] = "|t40:40:esoui/art/inventory/inventory_tabicon_craftbag_provisioning_up.dds:inheritColor|t", --Cook
  [6] = "|t40:40:esoui/art/inventory/inventory_tabicon_craftbag_woodworking_up.dds:inheritColor|t", --Wood
  [7] = "|t40:40:esoui/art/tutorial/tutorial_idexicon_jewelry_up.dds:inheritColor|t", --Jewelry
}

function SDC.QuestUpdate()
  --Reset
  SDC.AbandonList = {} --Reset the quest should be abondoned
  SDC.BankTarget = {} --Reset the item list should be taken from bank
  SDC.BankTargetType = {} --Reset the item type should be taken from bank
  SDC.HaveDaily = false
  SDC.UndoneMaster = false
  local List = {}
  --EachCraftType: HaveCraftQuest? DoneDaily? DoneMaster?
  for i = 1, 7 do List[i] = {false, true, true} end 
  --Start analyze
  for a = 1, 25 do
    local Type = select(10, GetJournalQuestInfo(a))
    if Type == 4 then --Craft quests
      if GetQuestConditionMasterWritInfo(a, 1, 1) then 
        --Master Writs
        local _,_, CraftType = GetQuestConditionMasterWritInfo(a, 1, 1)
        local current, need = GetJournalQuestConditionValues(a, 1, 1)
        List[CraftType][1] = true
        if current < need then --Undone master
          List[CraftType][3] = false
          SDC.UndoneMaster = true
        end 
      else
        --Daily Writs
        local NowType = 0
        for b = 1, 6 do 
          local ItemId, MaterialId, CraftType = GetQuestConditionItemInfo(a, 1, b)
          local current, need = GetJournalQuestConditionValues(a, 1, b)
          --Craft item
          if ItemId ~= 0 and CraftType ~= 0 then
            --Ban quest check
            if not SDC.SV.BQ and CraftType == 1 then table.insert(SDC.AbandonList, a) end
            if not SDC.SV.CQ and CraftType == 2 then table.insert(SDC.AbandonList, a) end
            if not SDC.SV.WQ and CraftType == 6 then table.insert(SDC.AbandonList, a) end
            if not SDC.SV.JQ and CraftType == 7 then table.insert(SDC.AbandonList, a) end
            if not SDC.SV.PQ and CraftType == 5 then table.insert(SDC.AbandonList, a) end
            if not SDC.SV.EQ and CraftType == 3 then table.insert(SDC.AbandonList, a) end
            if not SDC.SV.AQ and CraftType == 4 then table.insert(SDC.AbandonList, a) end
            NowType = CraftType --Record this quest type for material check
            List[CraftType][1] = true
            SDC.HaveDaily = true
            --Undone
            if current < need then 
              List[CraftType][2] = false 
              --For comsuable type bank work
              if CraftType > 2 and CraftType < 6 then 
                table.insert(SDC.BankTarget, {ItemId, need - current, a, b}) --Try get from bank later
                SDC.BankTargetType[CraftType] = true
              end
            end 
          end
          --Raw material
          if ItemId ~= 0 and CraftType == 0 and NowType ~= 0 then
            --Banlist check
            for i = 1, #SDC.SV.DailyRawRestrict do
              if ItemId == SDC.SV.DailyRawRestrict[i] then
                SDC.DD(11, {ToLink(ItemId)})
                table.insert(SDC.AbandonList, a)
              end
            end
            --Undone
            if current < need then 
              List[NowType][2] = false
              table.insert(SDC.BankTarget, {ItemId, need - current, a, b}) --Try get from bank later
              SDC.BankTargetType[NowType] = true
            end
          end
        end
      end
    end
  end
  --Bar info
  local Display = " "
  local Order = {1,6,2,7,5,3,4} --Resort the display order
  local ShouldH = true
  for i = 1, 7 do --Check each craft type
    if List[Order[i]][1] == false then --No quest
      Display = Display.."|c778899"..Icon[Order[i]].."|r"
    else
      ShouldH = false
      --Finish
      if List[Order[i]][2] == true and List[Order[i]][3] == true then Display = Display.."|c32CD32"..Icon[Order[i]].."|r" end
      --Only master left undone
      if List[Order[i]][2] == true and List[Order[i]][3] == false then Display = Display.."|c8A2BE2"..Icon[Order[i]].."|r" end
      --Only daily left undone
      if List[Order[i]][2] == false and List[Order[i]][3] == true then Display = Display.."|cF0E68C"..Icon[Order[i]].."|r" end
      --Both undone
      if List[Order[i]][2] == false and List[Order[i]][3] == false then Display = Display.."|cDC143C"..Icon[Order[i]].."|r" end
    end
  end
  SDCTopLevel_Label:SetText(Display)
  --Bar display
  if not SDC.SV.Window_Show then
    SDCTopLevel:SetHidden(true)
    return
  end
  SDCTopLevel:SetHidden(ShouldH) --No craft quests
end

--When window move, record its new position in SV
function SDC.WindowPosition()
  local _
  _, SDC.SV.Window_Point, _, SDC.SV.Window_rPoint, SDC.SV.Window_OffsetX, SDC.SV.Window_OffsetY = SDCTopLevel:GetAnchor()
end

-------------------
----Start Point----
-------------------
EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)