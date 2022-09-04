local utilities = require "tplink.utilities"
local protocol = require "tplink.protocol"
local json = require "dkjson"
local log = require "log"

--- @module switch
local switch_module = {}

-- Switch definition
--- @class Switch
--- TODO
local Switch = {}
Switch.__index = Switch

Switch._init = function(cls, id, alias, model, type, ipv4, port, is_energy_meter, is_dimmable)
  local state = {on_off = 0, bri = 0, power = 0, energy = 0} -- power is in mW, energy is in Wh
  local switch = {
    id = id,
    alias = alias,
    model = model,
    type = type,
    ipv4 = ipv4,
    port = port,
    state = state,
    is_dimmable = is_dimmable,
    is_energy_meter = is_energy_meter,
  }

  setmetatable(switch, cls)
  return switch
end

function Switch:set_state(on_off, bri, duration)
  local json_payload = {}

  if bri and type(bri) == "number" then
    local smartlife_iot_dimmer = {}

    if on_off and type(on_off) == "boolean" then
      smartlife_iot_dimmer["set_switch_state"] = {state = on_off and 1 or 0}
    end

    if bri and type(bri) == "number" then
      smartlife_iot_dimmer["set_brightness"] = {brightness = bri}
    end

    json_payload = {["smartlife.iot.dimmer"] = smartlife_iot_dimmer}
  else
    local system = {}

    if on_off ~= nil and type(on_off) == "boolean" then
      system["set_relay_state"] = {state = on_off and 1 or 0}
    end

    json_payload = {system = system}
  end

  local empty_json_object = {}
  setmetatable(empty_json_object, {__jsontype = "object"})
  local json_cmd = json.encode(json_payload)

  local resp, err = protocol.send_cmd(json_cmd, self.ipv4, self.port, "tcp", 5)
  if not resp then
    local err = "err on recv: " .. err
    return nil, err
  else
    local parsed_resp, pos, err = json.decode(resp)
    if err then
      log.warn("error decoding JSON string - err: " .. err)
      log.warn("response: " .. resp)
      return nil, err
    else
      return true
    end
  end
end

local function get_get_sysinfo(dec_data)
  if not dec_data then
    return nil
  end

  local system = dec_data.system
  if not system then
    return nil
  end

  local get_sysinfo = system.get_sysinfo
  if not get_sysinfo then
    return nil
  end

  return get_sysinfo
end

function Switch:get_state(timeout)
  local cmd = '{"system":{"get_sysinfo":{}}}'
  if self.is_energy_meter then
    cmd = '{"system":{"get_sysinfo":{}}, "emeter":{"get_realtime":{}}}'
  end

  local resp, err = protocol.send_cmd(cmd, self.ipv4, self.port, "udp", timeout)
  if not resp then
    return nil, err
  end

  local obj, pos, decode_err = json.decode(resp)
  if obj then
    local get_sysinfo = utilities.get_get_sysinfo(obj)
    if get_sysinfo then
      if get_sysinfo.relay_state then
        self.state.on_off = get_sysinfo.relay_state
      end

      if get_sysinfo.brightness then
        self.state.bri = get_sysinfo.brightness
      end
    else
      return nil, "Failed to parse get_sysinfo"
    end

    if self.is_energy_meter then
      local get_realtime = utilities.get_get_realtime(obj)
      if get_realtime then
        if get_realtime.power_mw then
          self.state.power = get_realtime.power_mw
        elseif get_realtime.power then
          self.state.power = get_realtime.power*1000 -- old proto version sends in W
        end

        if get_realtime.total_wh then
          self.state.energy = get_realtime.total_wh
        elseif get_realtime.total then
          self.state.energy = get_realtime.total*1000 -- old proto version sends in kWh
        end
      else
        return nil, "Failed to parse get_realtime"
      end
    end
  else
    return nil, "Failed to parse response: " .. decode_err
  end

  return true
end

function Switch:update_ipv4_port(ipv4, port)
  if ipv4 then
    self.ipv4 = ipv4
  end

  if port then
    self.port = port
  end
end

-- TODO: This isn't great. Create a generic TP-Link device object structure and have bulbs and smartswitches as sub-types
function Switch:is_bulb()
  return false
end

function Switch:is_switch()
  return true
end

function Switch:get_alias()
  return self.get_alias()
end

function Switch:get_model()
  return self.get_model()
end

setmetatable(
  Switch,
  {
    __call = Switch._init
  }
)

switch_module.Switch = Switch

return switch_module
