local log = require "log"
local tplink = require "tplink"
local event_handlers = require "event_handlers"
local capabilities = require "st.capabilities"

local FIELDS = require "fields"

local command_handlers = {}

function command_handlers.handle_switch_on(driver, device)
  local tplink_obj = device:get_field(FIELDS.TPLINK_OBJECT)
  if tplink_obj then
    if tplink_obj.is_bulb() then
      local success, err = tplink_obj:set_state(true, nil, nil, nil, nil, true, 400)
      if success then
        event_handlers.handle_switch_event(driver, device, true, true)
      else
        log.warn("Error handling switch ON cmd: ", err)
      end
    else -- assuming switch type
      local success, err = tplink_obj:set_state(true, nil)
      if success then
        event_handlers.handle_switch_event(driver, device, true, true)
      else
        log.warn("Error handling switch OFF cmd: " .. err)
      end
    end
  else
    log.warn("No tplink_obj for device")
    device:set_field(FIELDS.ONLINE, false)
  end
end

function command_handlers.handle_switch_off(driver, device)
  local tplink_obj = device:get_field(FIELDS.TPLINK_OBJECT)
  if tplink_obj then
    if tplink_obj.is_bulb() then
      local success, err = tplink_obj:set_state(false, nil, nil, nil, nil, true, 400)
      if success then
        event_handlers.handle_switch_event(driver, device, false, true)
      else
        log.warn("Error handling switch OFF cmd: " .. err)
      end
    else -- assuming switch type
      local success, err = tplink_obj:set_state(false, nil)
      if success then
        event_handlers.handle_switch_event(driver, device, false, true)
      else
        log.warn("Error handling switch OFF cmd: " .. err)
      end
    end
  else
    log.warn("No tplink_obj for device")
    device:set_field(FIELDS.ONLINE, false)
  end
end

function command_handlers.handle_set_level(driver, device, command)
  local tplink_obj = device:get_field(FIELDS.TPLINK_OBJECT)
  if tplink_obj then
    local max_bri = tplink.get_max_brightness()
    local bri = math.min(math.floor(command.args.level * max_bri / 100), max_bri)

    if tplink_obj.is_bulb() then
      -- Turn on the device if it's off.
      local power = nil
      if bri > 0 and device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" then
        power = true
      end

      local success, err = tplink_obj:set_state(power, bri, nil, nil, nil, true, 400)

      if success then
        event_handlers.handle_level_event(driver, device, bri, true)
        if power ~= nil then
          event_handlers.handle_switch_event(driver, device, power, true)
        end
      else
        log.warn("Error setting level: " .. err)
      end
    else -- assuming switch type
      -- if the device not on and brightness > 0, turn on the device.
      local power = nil
      if bri > 0 and cached_switch == "off" then
        power = true
      end

      -- Turn on the device if it's off.
      local power = nil
      if bri > 0 and device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" then
        power = true
      end

      local success, err_code, err_msg = tplink_obj:set_state(power, bri)
      if success then
        event_handlers.handle_level_event(driver, device, bri, true)
        if power ~= nil then
          event_handlers.handle_switch_event(driver, device, power, true)
        end
      else
        log.warn("Error setting switch level: " .. err_code)
      end
    end
  else
    log.warn("No tplink_obj for device")
    device:set_field(FIELDS.ONLINE, false)
  end
end

function command_handlers.handle_set_hue(driver, device, command)
  local tplink_obj = device:get_field(FIELDS.TPLINK_OBJECT)
  if tplink_obj then
    local hue = math.floor((command.args.hue * tplink.get_max_hue()) / 100.0 + 0.5)

    -- Turn on the device if it's off.
    local power = nil
    if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" then
      power = true
    end

    local success, err = tplink_obj:set_state(power, nil, hue, nil, nil, true, 400)

    if success then
      event_handlers.handle_hue_event(driver, device, hue, true)
      if power ~= nil then
        event_handlers.handle_switch_event(driver, device, power, true)
      end
    else
      log.warn("Error setting hue: " .. err)
    end
  else
    log.warn("No tplink_obj found for device")
    device:set_field(FIELDS.ONLINE, false)
  end
end

function command_handlers.handle_set_saturation(driver, device, command)
  local tplink_obj = device:get_field(FIELDS.TPLINK_OBJECT)
  if tplink_obj then
    local sat = math.floor((command.args.saturation * tplink.get_max_sat()) / 100.0 + 0.5)

    -- Turn on the device if it's off.
    local power = nil
    if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" then
      power = true
    end

    local success, err = tplink_obj:set_state(power, nil, nil, sat, nil, true, 400)

    if success then
      event_handlers.handle_saturation_event(driver, device, sat, true)
      if power ~= nil then
        event_handlers.handle_switch_event(driver, device, power, true)
      end
    else
      log.warn("Error setting saturation: " .. err)
    end
  else
    log.warn("No tplink_obj found for device")
    device:set_field(FIELDS.ONLINE, false)
  end
end

function command_handlers.handle_set_color(driver, device, command)
  local tplink_obj = device:get_field(FIELDS.TPLINK_OBJECT)
  if tplink_obj then
    local hue = math.floor((command.args.color.hue * tplink.get_max_hue()) / 100.0 + 0.5)
    local sat = math.floor((command.args.color.saturation * tplink.get_max_sat()) / 100.0 + 0.5)

    -- Turn on the device if it's off.
    local power = nil
    if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" then
      power = true
    end

    local success, err = tplink_obj:set_state(power, nil, hue, sat, nil, true, 400)

    if success then
      event_handlers.handle_hue_event(driver, device, hue, true)
      event_handlers.handle_saturation_event(driver, device, sat, true)
      if power ~= nil then
        event_handlers.handle_switch_event(driver, device, power, true)
      end
    else
      log.warn("Error setting color: " .. err)
    end
  else
    log.warn("No tplink_obj found for device")
    device:set_field(FIELDS.ONLINE, false)
  end
end

function command_handlers.handle_set_color_temp(driver, device, command)
  local tplink_obj = device:get_field(FIELDS.TPLINK_OBJECT)
  if tplink_obj then
    local kel = math.min(math.max(command.args.temperature, tplink.get_min_kelvin()), tplink.get_max_kelvin())

    -- Turn on the device if it's off.
    local power = nil
    if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" then
      power = true
    end

    local success, err = tplink_obj:set_state(power, nil, nil, nil, kel, true, 400)

    if success then
      event_handlers.handle_colortemp_event(driver, device, kel, true)
      if power ~= nil then
        event_handlers.handle_switch_event(driver, device, power, true)
      end
    else
      log.warn("Error setting color temp: " .. err)
    end
  else
    log.warn("No tplink_obj found for device")
    device:set_field(FIELDS.ONLINE, false)
  end
end

return command_handlers
