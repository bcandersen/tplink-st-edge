--------------------------------------------------------------------------------
-- TP-Link Library
--------------------------------------------------------------------------------
local TPLINK = require "tplink.types"

local discovery = require "tplink.discovery"
local protocol = require "tplink.protocol"
local utilities = require "tplink.utilities"
local bulb = require "tplink.bulb"
local switch = require "tplink.switch"

local json = require "dkjson"

local m = {}

--- Discovery of devices on the local network
m.discovery = discovery
m.protocol = protocol
m.utilities = utilities
m.bulb = bulb
m.switch = switch

function m.get_max_hue()
  return TPLINK.MAX_HUE
end

function m.get_max_sat()
  return TPLINK.MAX_SAT
end

function m.get_max_brightness()
  return TPLINK.MAX_BRIGHTNESS
end

function m.get_min_kelvin()
  return TPLINK.MIN_KELVIN
end

function m.get_max_kelvin()
  return TPLINK.MAX_KELVIN
end

function m.get_default_port()
  return TPLINK.DEFAULT_PORT
end

-- TODO: think of a more descriptive fn name
function m.initialize_device(ip, port)
  local resp, err = protocol.send_cmd('{"system":{"get_sysinfo":{}}}', ip, port, "tcp", 5)
  if not resp then
    return nil, err
  end

  local obj, pos, decode_err = json.decode(resp)
  if obj then
    local id = utilities.get_device_id(obj)
    if id == nil then
      return nil, "Failed to get device id from get_sysinfo"
    end

    local alias = utilities.get_alias(obj)
    if alias == nil then
      return nil, "Failed to get alias from get_sysinfo"
    end

    local model = utilities.get_model(obj)
    if model == nil then
      return nil, "Failed to get model from get_sysinfo"
    end

    local type = utilities.get_type(obj)
    if type then
      if type == TPLINK.SMARTBULB then
        return bulb.Bulb(
          id,
          alias,
          model,
          type,
          ip,
          port,
          utilities.is_dimmable(obj),
          utilities.is_color(obj),
          utilities.is_variable_color_temp(obj)
        )
      elseif type == TPLINK.SMARTPLUGSWITCH then
        return switch.Switch(id, alias, model, type, ip, port, utilities.is_energy_meter(obj), utilities.is_dimmable(obj))
      else
        return nil, "Unsupported TP-Link device type: " .. type
      end
    else
      return nil, "Failed to get type from get_sysinfo"
    end
  else
    return nil, "Failed to parse response: " .. decode_err
  end

  return true
end

return m
