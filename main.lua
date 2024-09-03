local Settings = require("src.settings")
local ItemManager = require("src.item_manager")
local Renderer = require("src.renderer")
local GUI = require("gui")
local utils = require("utils.utils")

local function handle_loot(wanted_item)
   if wanted_item then
      if utils.distance_to(wanted_item) > 2 then
         local item_position = wanted_item:get_position()
         pathfinder.request_move(item_position)
      else
         interact_object(wanted_item)
      end
   end
end

local function main_pulse()
   if not get_local_player() then return end
   if not GUI.elements.main_toggle:get() then return end
   if not Settings.should_execute() then return end

   Settings.update()

   local loot_closest_toggle = GUI.elements.general.loot_closest_toggle:get()
   local loot_best_toggle = GUI.elements.general.loot_best_toggle:get()

   if loot_closest_toggle then
      local wanted_item = ItemManager.get_nearby_item()
      handle_loot(wanted_item)
   elseif loot_best_toggle then
      local best_item_data = ItemManager.get_best_item()
      if best_item_data then
         handle_loot(best_item_data.Item)

      end
   end
end

on_update(main_pulse)
on_render_menu(GUI.render)
on_render(Renderer.draw_stuff)
