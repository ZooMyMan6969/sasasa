local Settings = require("src.settings")
local Utils = require("utils.utils")
local CustomItems = require("data.custom_items")

local ItemManager = {}

-- Table to store item type patterns
local item_type_patterns = {
   sigil = { "Nightmare_Sigil", "BSK_Sigil" },
   equipment = { "Base", "Amulet", "Ring" },
   quest = { "Global", "Glyph", "QST", "DGN", "pvp_currency" },
   crafting = { "CraftingMaterial" },
   cinders = { "Test_BloodMoon_Currency" }
}

-- Generic function to check item type
function ItemManager.check_item_type(item, type_name)
   local item_info = item:get_item_info()
   local name = item_info:get_skin_name()

   -- Special case for sigils and equipment
   if (type_name == "sigil" or type_name == "equipment") and item_info:get_rarity() ~= 0 then
      return false
   end

   for _, pattern in ipairs(item_type_patterns[type_name] or {}) do
      if name:find(pattern) then
         return true
      end
   end
   return false
end

function ItemManager.check_is_cinders(item)
   return ItemManager.check_item_type(item, "cinders")
end

function ItemManager.is_legendary_amulet(item)
   local item_info = item:get_item_info()
   return item_info:get_rarity() == 5 and item_info:get_skin_name():find("Amulet")
end

function ItemManager.is_unique_amulet(item)
   local item_info = item:get_item_info()
   return item_info:get_rarity() == 6 and item_info:get_skin_name():find("Amulet")
end

-- Specific functions using the generic check
function ItemManager.check_is_sigil(item)
   return ItemManager.check_item_type(item, "sigil")
end

function ItemManager.check_is_equipment(item)
   return ItemManager.check_item_type(item, "equipment")
end

function ItemManager.check_is_quest_item(item)
   return ItemManager.check_item_type(item, "quest")
end

function ItemManager.check_is_crafting(item)
   return ItemManager.check_item_type(item, "crafting")
end

---@param item game.object Item to check
---@param ignore_distance boolean If we want to ignore the distance check
function ItemManager.check_want_item(item, ignore_distance)
   local item_info = item:get_item_info()
   if not item_info then return false end

   local settings = Settings.get()
   local id = item_info:get_sno_id()
   local rarity = item_info:get_rarity()
   local affixes = item_info:get_affixes()

   -- Early return checks
   if not ignore_distance and Utils.distance_to(item) >= settings.distance then return false end
   if settings.skip_dropped and #affixes > 0 then return false end
   if loot_manager.is_gold(item) or loot_manager.is_potion(item) then return false end

   -- Check if the item is a special item
   local is_special_item =
       (settings.quest_items and ItemManager.check_is_quest_item(item)) or
       (settings.boss_items and CustomItems.boss_items[id]) or
       (settings.crafting_items and ItemManager.check_is_crafting(item)) or
       (settings.rare_elixirs and CustomItems.rare_elixirs[id]) or
       (settings.advanced_elixirs and CustomItems.advanced_elixirs[id]) or
       (settings.cinders and ItemManager.check_is_cinders(item)) or
       (settings.event_items and CustomItems.event_items[id]) or
       (settings.sigils and ItemManager.check_is_sigil(item))

   local is_event_item = settings.event_items and CustomItems.event_items[id]
   local is_cinders = settings.cinders and ItemManager.check_is_cinders(item)

   -- New condition to check if the item is crafting material or cinders
   local is_crafting_item = settings.crafting_items and ItemManager.check_is_crafting(item)

   if is_event_item then
      if Utils.is_inventory_full() then
         return false 
      elseif Utils.is_consumable_inventory_full() then
         return true 
      end
   end

   -- If the item is crafting material or cinders, skip inventory and consumable checks
   if is_crafting_item or is_cinders then
      return true
   end

   if is_special_item then
      if is_cinders and crafting then
         return true
      end

      if (is_event_item and Utils.is_inventory_full()) or 
         (not is_event_item and Utils.is_consumable_inventory_full()) then
         return false
      end
      return true -- If it's a special item and inventory isn't full, we want it
   end

   local inventory_full = is_special_item and Utils.is_consumable_inventory_full() or Utils.is_inventory_full()
   if inventory_full then return false end

   -- If it's a special item, we want it
   if is_special_item then return true end

   -- Check rarity
   if rarity < settings.rarity then return false end

   -- Check greater affixes for high rarity items
   if rarity >= 5 then
      local greater_affix_count = Utils.get_greater_affix_count(item_info:get_display_name())
      local required_ga_count

      if ItemManager.is_legendary_amulet(item) then
         required_ga_count = settings.legendary_amulet_ga_count
      elseif ItemManager.is_unique_amulet(item) then
         required_ga_count = settings.unique_amulet_ga_count
      elseif rarity == 5 then
         required_ga_count = settings.ga_count
      else
         required_ga_count = CustomItems.ubers[id] and settings.uber_unique_ga_count or settings.unique_ga_count
      end

      if greater_affix_count < required_ga_count then return false end
   end

   return true
end


function ItemManager.get_nearby_item()
   local items = actors_manager:get_all_items()
   local fetched_items = {}

   for _, item in pairs(items) do
      if ItemManager.check_want_item(item, false) then
         table.insert(fetched_items, item)
      end
   end

   table.sort(fetched_items, function(x, y)
      return Utils.distance_to(x) < Utils.distance_to(y)
   end)

   return fetched_items[1]
end
function ItemManager.calculate_item_score(item)
   local score = 0
   local item_info = item:get_item_info()
   local item_id = item_info:get_sno_id()
   local display_name = item_info:get_display_name()
   local item_rarity = item_info:get_rarity()

   if CustomItems.ubers[item_id] then
      score = score + 1000
   elseif item_rarity >= 5 then
      score = score + 500
   elseif item_rarity >= 3 then
      score = score + 300
   elseif item_rarity >= 1 then
      score = score + 100
   else
      score = score + 10
   end

   local greater_affix_count = Utils.get_greater_affix_count(display_name)

   if greater_affix_count == 3 then
      score = score + 100
   elseif greater_affix_count == 2 then
      score = score + 75
   elseif greater_affix_count == 1 then
      score = score + 50
   end

   return score
end

function ItemManager.get_best_item()
   local items = actors_manager:get_all_items()
   local scored_items = {}

   for _, item in ipairs(items) do
      if ItemManager.check_want_item(item, false) then
         local item_object = { Item = item, Score = ItemManager.calculate_item_score(item) }
         table.insert(scored_items, item_object)
      end
   end

   table.sort(scored_items, function(x, y)
      return x.Score > y.Score
   end)

   return scored_items[1]
end

return ItemManager
