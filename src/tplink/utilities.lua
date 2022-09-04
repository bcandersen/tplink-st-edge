--------------------------------------------------------------------------------------------
-- TP-Link Helper Utilities
--------------------------------------------------------------------------------------------
local function get_get_sysinfo(dec_data)
  if dec_data and dec_data.system then
    return dec_data.system.get_sysinfo
  end

  return nil
end

local function get_get_realtime(dec_data)
  if dec_data and dec_data.system then
    return dec_data.emeter.get_realtime
  end

  return nil
end

-- {system: {get_sysinfo: {light_state: {...}, ...}, ...}, ...}}
local function get_light_state(dec_data)
  local get_sysinfo = get_get_sysinfo(dec_data)
  if not get_sysinfo then
    return nil
  end

  return get_sysinfo.light_state
end

local function get_device_id(dec_data)
  local get_sysinfo = get_get_sysinfo(dec_data)
  if not get_sysinfo then
    return nil
  end

  return get_sysinfo.deviceId
end

local function get_type(dec_data)
  local get_sysinfo = get_get_sysinfo(dec_data)
  if not get_sysinfo then
    return nil
  end

  -- Different type names have been observed depending on firmware.
  local type = get_sysinfo.mic_type
  if not type then
    type = get_sysinfo.type
  end

  return type
end

local function get_model(dec_data)
  local get_sysinfo = get_get_sysinfo(dec_data)
  if not get_sysinfo then
    return nil
  end

  return get_sysinfo.model
end

local function get_alias(dec_data)
  local get_sysinfo = get_get_sysinfo(dec_data)
  if not get_sysinfo then
    return nil
  end

  return get_sysinfo.alias
end

local function is_dimmable(dec_data)
  local get_sysinfo = get_get_sysinfo(dec_data)
  if get_sysinfo then
    if get_sysinfo.is_dimmable == 1 then
      return true
    elseif get_sysinfo.brightness then -- for dimmer switches
      return true
    end
  end

  return false
end

local function is_color(dec_data)
  local get_sysinfo = get_get_sysinfo(dec_data)
  if get_sysinfo and get_sysinfo.is_color == 1 then
    return true
  end

  return false
end

local function is_variable_color_temp(dec_data)
  local get_sysinfo = get_get_sysinfo(dec_data)
  if get_sysinfo and get_sysinfo.is_variable_color_temp == 1 then
    return true
  end

  return false
end

local function is_energy_meter(dec_data)
  local get_sysinfo = get_get_sysinfo(dec_data)
  if get_sysinfo and string.match(get_sysinfo.feature, "ENE") then
    return true
  end

  return false
end

local function get_children(dec_data)
  local get_sysinfo = get_get_sysinfo(dec_data)
  if get_sysinfo then
    return get_sysinfo.children
  end

  return nil
end

return {
  get_device_id = get_device_id,
  get_type = get_type,
  get_model = get_model,
  get_alias = get_alias,
  get_get_sysinfo = get_get_sysinfo,
  get_get_realtime = get_get_realtime,
  get_light_state = get_light_state,
  get_children = get_children,
  is_dimmable = is_dimmable,
  is_color = is_color,
  is_variable_color_temp = is_variable_color_temp,
  is_energy_meter = is_energy_meter
}
