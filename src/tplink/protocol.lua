local socket = require "cosock".socket
local log = require "log"

--------------------------------------------------------------------------------------------
-- TP-Link Core Protocol
--------------------------------------------------------------------------------------------
local function encrypt(data, protocol)
  local key = 171
  local enc_buf = ""

  if protocol == "tcp" then
    enc_buf = string.pack("xxxB", #data)
  end

  for i = 1, #data do
    local c = string.sub(data, i, i) -- is data[i] not legal syntax??
    local a = key ~ string.byte(c)
    key = a
    enc_buf = enc_buf .. string.char(a)
  end

  return enc_buf
end

local function decrypt(data, protocol)
  local key = 171
  local dec_buf = ""

  for i = (protocol == "tcp") and 5 or 1, #data do
    local c = string.sub(data, i, i) -- is data[i] not legal syntax??
    local a = key ~ string.byte(c)
    key = string.byte(c)
    dec_buf = dec_buf .. string.char(a)
  end

  -- TODO: Will this much trace logging cause too much stress on the driver?
  log.trace("Decrypted response: " .. dec_buf)

  return dec_buf
end

local function send_tcp(cmd, ip, port, timeout)
  local enc_cmd = encrypt(cmd, "tcp") -- nil check

  local sock = socket.tcp()
  sock:settimeout(timeout)

  local res, err = sock:connect(ip, port)
  if res == nil then
    local err = "ERR sending command: " .. err
    return nil, err
  end

  sock:send(enc_cmd)

  -- Most TP-Link devices do not send a \n in the response payload.
  -- To prevent always hitting the timeout, pass the sock to select() so
  -- recv'd data is returned right away.
  sock:settimeout(0)
  socket.select({sock}, {}, timeout)
  local buf, ip_or_err, partial = sock:receive("*a")
  sock:close()

  -- There is no guarantee that a full response is received. Responses should
  -- be checked for completeness and additional receive() calls should be performed
  -- if partial response is received.
  if buf == nil then
    if partial == nil then
      return nil, ip_or_err
    else
      return decrypt(partial, "tcp")
    end
  else
    return decrypt(buf, "tcp")
  end
end

local function send_udp(cmd, ip, port, timeout)
  local enc_cmd = encrypt(cmd, "udp") -- nil check

  local sock = socket.udp()
  sock:settimeout(timeout)
  sock:setsockname("0.0.0.0", 0)

  if ip == "255.255.255.255" then
    sock:setoption("broadcast", true)
  end

  local res, err = sock:sendto(enc_cmd, ip, port)
  if res == nil then
    local err = "ERR sending command: " .. err
    return nil, err
  end

  local buf, ip_or_err = sock:receive()
  if buf == nil then
    sock:close()
    return nil, ip_or_err
  else
    sock:close()
    return decrypt(buf, "udp")
  end
end

local function send_broadcast_cmd(cmd, port, timeout, callback)
  local enc_cmd = encrypt(cmd, "udp") -- nil check

  local sock = socket.udp()
  sock:settimeout(timeout)
  sock:setsockname("0.0.0.0", 0)
  sock:setoption("broadcast", true)

  --TODO TIMEOUT DECREASE
  local res, err = sock:sendto(enc_cmd, "255.255.255.255", port)
  if res == nil then
    log.info("UDP sendto err: " .. err)
    return
  else
    while true do
      local data, ip_or_err, port = sock:receivefrom()
      if data == nil then
        callback(nil, ip_or_err)
        break
      else
        local dec_data = decrypt(data, "udp")
        callback(dec_data, ip_or_err, port)
      end
    end
  end
  sock:close()
end

local function send_cmd(cmd, ip, port, protocol, timeout)
  log.debug("Sending command to " .. ip .. " via " .. protocol .. ": " .. cmd)

  if protocol == "tcp" then
    return send_tcp(cmd, ip, port, timeout)
  else
    return send_udp(cmd, ip, port, timeout)
  end
end

return {
  send_cmd = send_cmd,
  send_broadcast_cmd = send_broadcast_cmd
}
