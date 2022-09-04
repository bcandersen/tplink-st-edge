local capabilities = require "st.capabilities"
local tplink = require "tplink"

local event_handlers = {}
function event_handlers.handle_switch_event(driver, device, power, force)
  local cached_switch = device:get_latest_state("main", "switch", "switch") == "on"

  if force or cached_switch ~= power then
    if power then
      device:emit_event(capabilities.switch.switch.on())
    else
      device:emit_event(capabilities.switch.switch.off())
    end
  end
end

function event_handlers.handle_level_event(driver, device, level, force)
  if device:supports_capability_by_id("switchLevel") == false then
    return
  end

  level = math.floor((level / tplink.get_max_brightness()) * 100 + 0.5)

  if force or device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME) ~= level then
    device:emit_event(capabilities.switchLevel.level(level))
  end
end

function event_handlers.handle_colortemp_event(driver, device, kel, force)
  -- ignore 0 ct values as they are not valid in ST
  if (force or device:get_latest_state("main", capabilities.colorTemperature.ID, capabilities.colorTemperature.colorTemperature.NAME) ~= kel) and kel ~= 0 then
    device:emit_event(capabilities.colorTemperature.colorTemperature(kel))
  end
end

function event_handlers.handle_hue_event(driver, device, hue, force)
  hue = math.max(1, math.floor((hue / tplink.get_max_hue()) * 100.0 + 0.5))
  if force or device:get_latest_state("main", capabilities.colorControl.ID, capabilities.colorControl.hue.NAME) ~= hue then
    device:emit_event(capabilities.colorControl.hue(hue))
  end
end

function event_handlers.handle_saturation_event(driver, device, sat, force)
  sat = math.max(1, math.floor((sat / tplink.get_max_sat()) * 100.0 + 0.5))
  if force or device:get_latest_state("main", capabilities.colorControl.ID, capabilities.colorControl.saturation.NAME) ~= sat then
    device:emit_event(capabilities.colorControl.saturation(sat))
  end
end

function event_handlers.handle_energy_event(driver, device, energy_wh, force)
  local energy_kwh = energy_wh/1000
  local cached_energy_kwh = device:get_latest_state("main", capabilities.energyMeter.ID, capabilities.energyMeter.energy.NAME)

  if cached_energy_kwh == nil then
    -- if cached_energy_kwh is nil and energy is 0, set force to true to init energy cap attrib
    if energy_wh == 0 then
      force = true
    end
    cached_energy_kwh = 0
  end

  -- only emit event if energy delta is greater or equal to .001kWh (1Wh)
  if force or math.abs(energy_kwh - cached_energy_kwh) >= .001 then
    device:emit_event(capabilities.energyMeter.energy(energy_kwh))
  end
end

function event_handlers.handle_power_event(driver, device, power_mw, force)
  local power_w = power_mw/1000
  local cached_power_w = device:get_latest_state("main", capabilities.powerMeter.ID, capabilities.powerMeter.power.NAME)

  if cached_power_w == nil then
    -- if cached_power_w is nil and power is 0, set force to true to init power cap attrib
    if power_mw == 0 then
      force = true
    end
    cached_power_w = 0
  end

  -- only emit event if power delta is greater or equal to 1W
  if force or math.abs(power_w - cached_power_w) >= 1 then
    device:emit_event(capabilities.powerMeter.power(power_w))
  end
end

return event_handlers
