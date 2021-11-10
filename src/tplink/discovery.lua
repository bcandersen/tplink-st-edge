--------------------------------------------------------------------------------------------
-- TP-Link Discovery
--------------------------------------------------------------------------------------------
local TPLINK = require "tplink.types"

local bulb = require "tplink.bulb"
local switch = require "tplink.switch"
local protocol = require "tplink.protocol"
local utilities = require "tplink.utilities"
local json = require "dkjson"
local log = require "log"

local function discover(timeout, callback)
  local broadcast_cb = function(resp, ip_or_err, port)
    if resp == nil then
      if ip_or_err ~= "timeout" then
        log.warn("Discovery: received (non-timeout) error" .. ip_or_err)
      end
    else
      local obj, pos, decode_err = json.decode(resp)
      if obj then
        log.trace("received discovery response from from: " .. ip_or_err .. ":" .. port)
        local alias = utilities.get_alias(obj)
        local model = utilities.get_model(obj)
        local device_id = utilities.get_device_id(obj)
        local type = utilities.get_type(obj)
        if model == nil or alias == nil or device_id == nil then
          log.warn("Discovery: error extracting model, deviceId, and/or alias")
          return
        end

        local device_obj = nil
        if type == TPLINK.SMARTBULB then
          device_obj =
            bulb.Bulb(
            device_id,
            alias,
            model,
            type,
            ip_or_err,
            port,
            utilities.is_dimmable(obj),
            utilities.is_color(obj),
            utilities.is_variable_color_temp(obj)
          )
        elseif type == TPLINK.SMARTPLUGSWITCH then
          device_obj = switch.Switch(device_id, alias, model, type, ip_or_err, port, utilities.is_energy_meter(obj), utilities.is_dimmable(obj))
        else
          log.warn("Unsupported TP-Link device type: " .. type)
        end

        callback(device_obj)
      else
        return false, "Discovery: Failed to parse response: " .. decode_err
      end
    end
  end

  protocol.send_broadcast_cmd('{"system":{"get_sysinfo":{}}}', 9999, timeout, broadcast_cb)
end

return {
  discover = discover
}
