local log = require "log"
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local command_handlers = require "command_handlers"
local tplink = require "tplink"
local event_handlers = require "event_handlers"

local FIELDS = require "fields"

local function discover(driver, discovery_active)
  tplink.discovery.discover(
    5,
    function(tplink_obj)
      log.debug("found TP-Link device (" .. tplink_obj.alias .. ") with IP: " .. tplink_obj.ipv4)
      local device = driver.device_dni_map[tplink_obj.id]
      if device then
        -- TODO update vendorName from label
        device:set_field(FIELDS.TPLINK_OBJECT, tplink_obj)
      elseif discovery_active then
        log.info(
          "Discovered new TP-Link device - Name: " ..
            tplink_obj.alias ..
              " test DNI: " ..
                tplink_obj.id ..
                  " IP: " ..
                    tplink_obj.ipv4 ..
                      ":" .. tplink_obj.port .. " Type: " .. tplink_obj.type .. " Model: " .. tplink_obj.model
        )

        local profile_ref = "tplink.plug.v1"
        if tplink_obj.is_bulb() then
          profile_ref = "tplink.dimmer.v1"
          if tplink_obj.is_color_temp then
            profile_ref = "tplink.ct.blub.v1"
          end
          if tplink_obj.is_color then
            profile_ref = "tplink.rgbw.blub.v1"
          end
        elseif tplink_obj.is_switch() then
          if tplink_obj.is_energy_meter then
            profile_ref = "tplink.energy.plug.v1"
          elseif tplink_obj.is_dimmable then
            profile_ref = "tplink.dimmer.switch.v1"
          end
        end

        local metadata = {
          type = "LAN",
          device_network_id = tplink_obj.id,
          label = tplink_obj.alias,
          profile = profile_ref,
          manufacturer = "TP-Link Kasa Home",
          model = tplink_obj.model,
          vendor_provided_label = tplink_obj.alias
        }

        driver:try_create_device(metadata)
      end
    end
  )
end

local function update_state(driver, device, force)
  local tplink_obj = device:get_field(FIELDS.TPLINK_OBJECT)
  if tplink_obj then
    event_handlers.handle_switch_event(driver, device, tplink_obj.state.on_off == 1 and true or false, force)
    if tplink_obj.is_bulb() then
      if tplink_obj.is_dimmable then
        event_handlers.handle_level_event(driver, device, tplink_obj.state.bri, force)
      end
      if tplink_obj.is_color_temp then
        event_handlers.handle_colortemp_event(driver, device, tplink_obj.state.kel, force)
      end
      if tplink_obj.is_color then
        event_handlers.handle_hue_event(driver, device, tplink_obj.state.hue, force)
        event_handlers.handle_saturation_event(driver, device, tplink_obj.state.sat, force)
      end
    elseif tplink_obj.is_switch() then
      if tplink_obj.is_dimmable then
        event_handlers.handle_level_event(driver, device, tplink_obj.state.bri, force)
      end
      if tplink_obj.is_energy_meter then -- TODO: do bulbs have energy meters?
        event_handlers.handle_energy_event(driver, device, tplink_obj.state.energy, force)
        event_handlers.handle_power_event(driver, device, tplink_obj.state.power, force)
      end
    end
  else
    log.debug("No tplink_obj found for device")
  end
end

local function start_poll(device)
  local poll_timer = device:get_field(FIELDS.POLL_TIMER)
  if poll_timer ~= nil then
    log.warn("Poll timer for " .. device.label .. " already started. Skipping...")
    return
  end

  device:set_field(FIELDS.POLL_TIMEOUTS, 0)
  device:set_field(FIELDS.NEEDS_SYNC, true)

  local poll_devices = function()
    local online = device:get_field(FIELDS.ONLINE)

    log.trace("Polling device: " .. device.label)
    local tplink_obj = device:get_field(FIELDS.TPLINK_OBJECT)
    if tplink_obj then
      local response, err = tplink_obj:get_state(.5)
      if response then
        device:set_field(FIELDS.POLL_TIMEOUTS, 0)
        if not online then
          log.info("[" .. device.id .. "] Marking TP-Link device online: " .. device.label)
          device:set_field(FIELDS.ONLINE, true)
          device:online()
        end
        if device:get_field(FIELDS.NEEDS_SYNC) then
          log.info("[" .. device.id .. "] Syncing state for device: " .. device.label)
          update_state(driver, device, true)
          device:set_field(FIELDS.NEEDS_SYNC, false)
        else
          update_state(driver, device, false)
        end
      else
        log.debug(
          'Error polling device "' ..
            device.label .. " at " .. tplink_obj.ipv4 .. ":" .. tplink_obj.port .. '": ' .. err
        )
        local poll_timeouts = device:get_field(FIELDS.POLL_TIMEOUTS)
        if poll_timeouts >= 5 then
          if online then
            log.info("[" .. device.id .. "] Marking TP-Link device offline: " .. device.label)
            device:set_field(FIELDS.ONLINE, false)
            device:offline()
          end
        else
          device:set_field(FIELDS.POLL_TIMEOUTS, poll_timeouts + 1)
        end
      end
    else
      log.debug("No tplink_obj found for device")
      device:set_field(FIELDS.ONLINE, false)
    end
  end

  poll_timer = device.thread:call_on_schedule(2, poll_devices)
  device:set_field(FIELDS.POLL_TIMER, poll_timer)
end

local function discovery(driver, opts, should_continue)
  log.info("Starting TP-Link Discovery")
  while should_continue() do
    discover(driver, true)
  end
  log.info("Stopping TP-Link Discovery")
end

local function device_init(driver, device)
  log.info("[" .. device.id .. "] Initializing TP-Link device: " .. device.label)
  driver.device_dni_map[device.device_network_id] = device

  local tplink_obj = device:get_field(FIELDS.TPLINK_OBJECT)
  if tplink_obj == nil then
    log.warn("No TP-Link device object found for " .. device.label .. ". Starting discovery...")
    discover(driver, false)
  end

  start_poll(device)
end

local function device_added(driver, device)
  log.info("[" .. device.id .. "] Adding new TP-Link device: " .. device.label)
  device_init(driver, device)
end

local function device_removed(driver, device)
  --NOTE: Polling timer is on device thread. Timer will be automatically cleaned up.
  log.info("[" .. device.id .. "] Removing TP-Link device: " .. device.label)
  driver.device_dni_map[device.device_network_id] = nil
end

---------------------------------------------------------------------------------------------------
log.info("Initializing TP-Link Edge Driver")

local tplink_driver =
  Driver(
  "tplink",
  {
    discovery = discovery,
    capability_handlers = {
      [capabilities.switch.ID] = {
        [capabilities.switch.commands.on.NAME] = command_handlers.handle_switch_on,
        [capabilities.switch.commands.off.NAME] = command_handlers.handle_switch_off
      },
      [capabilities.switchLevel.ID] = {
        [capabilities.switchLevel.commands.setLevel.NAME] = command_handlers.handle_set_level
      },
      [capabilities.colorControl.ID] = {
        [capabilities.colorControl.commands.setColor.NAME] = command_handlers.handle_set_color,
        [capabilities.colorControl.commands.setHue.NAME] = command_handlers.handle_set_hue,
        [capabilities.colorControl.commands.setSaturation.NAME] = command_handlers.handle_set_saturation
      },
      [capabilities.colorTemperature.ID] = {
        [capabilities.colorTemperature.commands.setColorTemperature.NAME] = command_handlers.handle_set_color_temp
      }
    },
    lifecycle_handlers = {init = device_init, added = device_added, removed = device_removed},
    device_dni_map = {}
  }
)

function tplink_driver:device_health_check()
  log.debug("Performing periodic device health check")
  for id, device in pairs(self.device_cache) do
    if device:get_field(FIELDS.ONLINE) == false then
      log.info("[" .. device.id .. "] Found offline TP-Link device, sending discovery message")
      discover(self, false)
      break
    end
  end
end

-- Start 60s periodic health check
tplink_driver.device_health_timer = tplink_driver.call_on_schedule(tplink_driver, 60, tplink_driver.device_health_check)

tplink_driver:run()
