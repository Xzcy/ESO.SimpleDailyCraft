local SDC = SimpleDailyCraft
--Connect to quest
SDC.BankTarget = {--[[
  [1] = {
    [1] = ItemId,
    [2] = NumNeed,
    [3] = a, questindex
    [4] = b, questindex
  },
]]}
--When bank function run, avoid changing by quest update
SDC.RunTarget = {--[[
  [1] = {
    [1] = Item Id,
    [2] = Need Num,
    [3] = a, quest index
    [4] = b, quest index
    ["Slot"] = {Slot1, Slot2, Slot3...} BagSlotId to put item
  }
]]}
--Compatibility with PA
SDC.BankTargetType = {--[[
  [Craft Type] = true
]]}

---------------------
----Tool function----
---------------------

local function ToLink(Id)
  return "|H0:item:"..Id..":30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
end

local function ShouldOpenBank(Report)
  local Should = false
  for i = 1, #SDC.BankTarget do
    local Table = SDC.BankItemScan(SDC.BankTarget[i][1], SDC.BankTarget[i][3], SDC.BankTarget[i][4])
    if Table["TotalNum"] >= SDC.BankTarget[i][2] then 
      Should = true
    else
      if Report then SDC.DD(3.1, {ToLink(SDC.BankTarget[i][1])}) end
    end
  end
  return Should
end

-----------------
----Bank Part----
-----------------

--Core for bank work
function SDC.BankCore(scene, _, newstate)
  if not SDC.SV.Bank then return end
  if newstate ~= SCENE_SHOWN then return end
  --Auto open bank
  if scene.name == "interact" then
    local Type
    if SCENE_MANAGER:IsShowing("interact") then
      local control = WINDOW_MANAGER:GetControlByName("ZO_ChatterOption1")
      Type = control.optionType
    else
      if not SCENE_MANAGER:IsShowing("gamepadInteract") then return end
      Type = GAMEPAD_INTERACTION.itemList.dataList[1].optionType
    end
    --Bank Type
    if Type == 1200 and ShouldOpenBank(true) then
      if IsInteractingWithMyAssistant() then
        if not SDC.SV.OpenBankAssistant then return end
      else
        if not SDC.SV.OpenBank then return end
      end
      SelectChatterOption(1)
    end
    return
  end
  --For bank work
  if scene.name == "bank" and ShouldOpenBank(false) then
    SDC.RunTarget = {unpack(SDC.BankTarget)} --To clone
    if SDC.RunTarget[1] == nil then return end
    EVENT_MANAGER:RegisterForEvent("SDCBank", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, SDC.BankProcess)
    SDC.BankProcess(_, 1)
  end
end

--Take item from bank
local TooLow = {}
function SDC.BankProcess(_, BagId, SlotId, IsNew, _, _, NumChange)
  --Only triggle for backbag change(1 time/transfer)
  if BagId ~= 1 then return end
  
  --Check Done
  if SDC.RunTarget[1] == nil then
    SDC.DD(9, {})
    --Close bank if set
    if SDC.SV.CloseBank then
      SCENE_MANAGER:Hide("bank")
      SCENE_MANAGER:Hide("gamepad_banking")
    end
    EVENT_MANAGER:UnregisterForEvent("SDCBank", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    for k, Link in pairs(TooLow) do --Push item near clear
      local _, count = GetItemLinkStacks(Link) --Item left in bank for each kind of link
      SDC.DD(1.2, {Link, count}) --Check Item num in prompt.lua
    end
    TooLow = {}
    return
  end

  --Check Full
  if GetNumBagFreeSlots(1) == 0 then
    SDC.DD(8, {})
    EVENT_MANAGER:UnregisterForEvent("SDCBank", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    return
  end
  
  --Check item already get
  local Remain = SDC.RunTarget[1][2]
  if not SDC.RunTarget[1]["slot"] then
  --First round for one item
    SDC.RunTarget[1]["slot"] = {}
    table.insert(SDC.RunTarget[1]["slot"] ,FindFirstEmptySlotInBag(1)) 
  else
  
  --Check Num still need to get
    for i = 1, #SDC.RunTarget[1]["slot"] do
      local SlotCount = select(2, GetItemInfo(1, SDC.RunTarget[1]["slot"][i])) --Count Num get
      Remain = Remain - SlotCount
    end
    --Already get enough item, Turn to next target
    if Remain == 0 then 
      table.remove(SDC.RunTarget, 1)
      SDC.BankProcess(_, 1)
      return
    end
  end

--Check total num of item in bank 
  local BankList = SDC.BankItemScan(SDC.RunTarget[1][1], SDC.RunTarget[1][3], SDC.RunTarget[1][4])
--[[
Structure{
    ["TotalNum"] = 0,
    ["Info"] = {
      --{BagId, SlotId, Link, Min},
      ...
      --{BagId, SlotId, Link, Max},
    },
  }
]]
  --Not enough for quest, skip this item
  if BankList["TotalNum"] < Remain then 
    table.remove(SDC.RunTarget, 1)
    SDC.BankProcess(_, 1)
    return
  end
  
  --Record item will take
  TooLow[BankList["Info"][1][3]] = BankList["Info"][1][3] --ToolLow["ItemLink"] = "ItemLink"
  --The slot contain the min number of target item
  local Final = BankList["Info"][1] 
  --{BagId, SlotId, Link, Min}
  if Final[4] < Remain then Remain = Final[4] end --Get how many
  
  --Take Items
  for i = 1, #SDC.RunTarget[1]["slot"] do
  --Check can stack？
    if GetItemTotalCount(1, SDC.RunTarget[1]["slot"][i]) == 0 or GetItemLink(1, SDC.RunTarget[1]["slot"][i]) == Final[3] then 
      CallSecureProtected("RequestMoveItem", Final[1], Final[2], 1, SDC.RunTarget[1]["slot"][i], Remain)
      return
    end
  end
  --Can't stack
  local NewSlot = FindFirstEmptySlotInBag(1)
  table.insert(SDC.RunTarget[1]["slot"], NewSlot)
  CallSecureProtected("RequestMoveItem", Final[1], Final[2], 1, NewSlot, Remain)
  return
end

--ItemId and quest index to check target item info
function SDC.BankItemScan(ItemId, a, b) 
  local Table = {
    ["TotalNum"] = 0,
    ["Info"] = {
      --{BagId, SlotId, Link, Num},
      },
    }
  --Look in Bank
  for i = 0, GetBagSize(2) do
    if GetItemId(2, i) == ItemId and DoesItemLinkFulfillJournalQuestCondition(GetItemLink(2, i), a, 1, b, true) then
      local count = select(2, GetItemInfo(2, i))
      Table["TotalNum"] = Table["TotalNum"] + count
      table.insert(Table["Info"], {2, i, GetItemLink(2, i), count})
    end
  end
  --Look in PlusBank
  if IsESOPlusSubscriber() then 
    for i = 0, GetBagSize(6) do
      if GetItemId(6, i) == ItemId and DoesItemLinkFulfillJournalQuestCondition(GetItemLink(6, i), a, 1, b, true) then
        local count = select(2, GetItemInfo(6, i))
        Table["TotalNum"] = Table["TotalNum"] + count
        table.insert(Table["Info"], {6, i, GetItemLink(6, i), count})
      end
    end
  end
  
  --Nothing find
  if Table["TotalNum"] == 0 then return Table end
  
  --Resort by num
  table.sort(Table["Info"], 
    function(a, b)
      return a[4] < b[4]
    end
  )
  return Table
end