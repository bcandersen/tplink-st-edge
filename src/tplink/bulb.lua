local TPLINK = require "tplink.types"

local utilities = require "tplink.utilities"
local protocol = require "tplink.protocol"
local json = require "dkjson"
local log = require "log"

--- @module bulb
local bulb_module = {}

-- Bulb definition
--- @class Bulb
--- TODO
local Bulb = {}
Bulb.__index = Bulb

Bulb._init = function(cls, id, alias, model, type, ipv4, port, is_dimmable, is_color, is_color_temp)
  local state = {on_off = 0, bri = 0, hue = 0, sat = 0, kel = 0}
  local bulb = {
    id = id,
    alias = alias,
    model = model,
    type = type,
    ipv4 = ipv4,
    port = port,
    state = state,
    is_dimmable = is_dimmable,
    is_color = is_color,
    is_color_temp = is_color_temp
  }

  setmetatable(bulb, cls)
  return bulb
end

-- TODO standarize error return values
function Bulb:set_state(on_off, bri, hue, sat, kel, transition_time)
  local transition_light_state = {}

  if on_off ~= nil and type(on_off) == "boolean" then
    transition_light_state["on_off"] = on_off and 1 or 0
  end

  if hue ~= nil then
    transition_light_state["hue"] = math.min(hue, TPLINK.MAX_HUE)
    -- color_temp must be set to 0 for hue values to take effect
    transition_light_state["color_temp"] = 0
  end

  if sat ~= nil then
    transition_light_state["saturation"] = math.min(sat, TPLINK.MAX_SAT)
    -- color_temp must be set to 0 for sat values to take effect
    transition_light_state["color_temp"] = 0
  end

  if bri ~= nil and bri >= 0 and bri <= 100 then
    transition_light_state["brightness"] = bri
  end

  if kel ~= nil then
    if kel ~= 0 then
      kel = math.min(math.max(kel, TPLINK.MIN_KELVIN), TPLINK.MAX_KELVIN)
    end
    transition_light_state["color_temp"] = kel
  end

  -- TODO bounds check
  if transition_time ~= nil then
    transition_light_state["transition_time"] = transition_time
  end

  transition_light_state["ignore_default"] = 1

  local json_cmd =
    json.encode({["smartlife.iot.smartbulb.lightingservice"] = {transition_light_state = transition_light_state}})

  local resp, err = protocol.send_cmd(json_cmd, self.ipv4, self.port, "tcp", 5)
  if resp == nil then
    local err = "error sending command: " .. err
    return false, err
  else
    local parsed_resp, pos, err = json.decode(resp)
    if not parsed_resp then
      log.warn("error decoding JSON string - err: " .. err)
      log.warn("response: " .. resp)
      return false, err
    else
      local smartlife_obj = parsed_resp["smartlife.iot.smartbulb.lightingservice"]
      if smartlife_obj == nil then
        return false, "No smartlife.iot.smartbulb.lightingservice object, has API changed?"
      end

      local transition_light_state = smartlife_obj.transition_light_state
      if transition_light_state == nil then
        return false, "No smartlife.iot.smartbulb.lightingservice object, has API changed?"
      end

      if transition_light_state.err_code ~= nil then
        if transition_light_state.err_code ~= 0 then
          log.warn("Received response error code: " .. transition_light_state.err_code)
          return false, transition_light_state.err_code
        end
      else
        return false, "No err_code object, has API changed?"
      end

      return true
    end
  end
end

function Bulb:get_state(timeout)
  local resp, err = protocol.send_cmd('{"system":{"get_sysinfo":{}}}', self.ipv4, self.port, "udp", timeout)
  if not resp then
    return false, err
  end

  local obj, pos, decode_err = json.decode(resp)
  if obj then
    local light_state = utilities.get_light_state(obj)
    if light_state then
      if light_state.on_off then
        self.state.on_off = light_state.on_off
      end

      if light_state.hue then
        self.state.hue = light_state.hue
      end

      if light_state.saturation then
        self.state.sat = light_state.saturation
      end

      if light_state.color_temp then
        self.state.kel = light_state.color_temp
      end

      if light_state.brightness then
        self.state.bri = light_state.brightness
      end
    else
      return false, "Failed to parse light_state"
    end
  else
    return false, "Failed to parse response: " .. decode_err
  end

  return true
end

function Bulb:update_ipv4_port(ipv4, port)
  if ipv4 then
    self.ipv4 = ipv4
  end

  if port then
    self.port = port
  end
end

function Bulb:is_bulb()
  return true
end

-- TODO: This isn't great. Create a generic TP-Link device object structure and have bulbs and smartswitches as sub-types
function Bulb:is_switch()
  return false
end

function Bulb:get_alias()
  return self.get_alias()
end

function Bulb:get_model()
  return self.get_model()
end

setmetatable(
  Bulb,
  {
    __call = Bulb._init
  }
)

bulb_module.Bulb = Bulb

return bulb_module
