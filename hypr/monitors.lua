-- Saved display settings, applied by Hyprland.
--
-- ~/.config/deck/monitors.lua is written by the Display plugin and holds only
-- data. It loads this file and calls it with that data. Source it from the end of
-- ~/.config/hypr/monitors.lua:
--
--   local deck = (os.getenv("HOME") or "") .. "/.config/deck/monitors.lua"
--   if io.open(deck) then dofile(deck) end
--
-- Two kinds of saved setting, kept apart on purpose:
--
--   monitors  per monitor IDENTITY: mode (resolution and rate) and scale. A
--             monitor's identity is its EDID description (make, model, serial),
--             which follows it from port to port and dock to dock, so the ASUS
--             gets the same mode and scale on DP-3 today and DP-1 tomorrow. Only
--             when two connected monitors report the same description does a
--             monitor fall back to its connector name.
--
--   layouts   a list of positions, per SET of monitors in use. A position only means
--             something next to the other screens it was arranged against: the
--             laptop panel alone at 0x0 and the ASUS docked at 0x0 are both
--             correct, but together they overlap. So a position is applied only
--             when exactly the same set of monitors is enabled again; any other
--             combination gets Hyprland's "auto" placement.
--
-- The mode is written explicitly rather than "preferred" because Hyprland reads a
-- monitor's mode list once, when the connector connects. A dock that hands over a
-- partial EDID first (the XG27UCG through an OWC Thunderbolt 3 dock offered
-- 1440p first and the full 4K list only later) leaves Hyprland with the short
-- list for good. A config reload does not re-read it. An explicit
-- "3840x2160@60" is still accepted: Hyprland builds a custom mode when the
-- requested one is absent from its list. If the link really cannot carry the
-- mode, Hyprland falls back to the preferred mode on its own.

return function(data)
  local monitors = (data and data.monitors) or {}
  local layouts = (data and data.layouts) or {}

  -- Same identity rule as the plugin (State.qml identityOf) and as Omarchy's
  -- monitor-workspaces.lua: the description, unless another enabled monitor
  -- reports the same one.
  local function enabled_identities(gone)
    local list = {}
    local count = {}
    for _, m in ipairs(hl.get_monitors()) do
      if m.name ~= gone and not m.is_mirror then
        list[#list + 1] = m
        local d = m.description or ""
        if d ~= "" then count[d] = (count[d] or 0) + 1 end
      end
    end
    local present = {}
    local n = 0
    for _, m in ipairs(list) do
      local d = m.description or ""
      local id = (d ~= "" and count[d] == 1) and d or m.name
      present[id] = m
      n = n + 1
    end
    return present, n
  end

  -- A layout is a map identity -> "XxY". It applies when it names exactly the
  -- monitors that are enabled: no more, no fewer.
  local function matching(present, n)
    for _, layout in ipairs(layouts) do
      local size = 0
      local all = true
      for id in pairs(layout) do
        size = size + 1
        if not present[id] then all = false end
      end
      if all and size == n then return layout end
    end
    return nil
  end

  local function rule(saved, position)
    hl.monitor({
      output = saved.output,
      mode = saved.mode or "preferred",
      position = position or "auto",
      scale = saved.scale or "auto",
    })
  end

  -- Mode and scale for every monitor ever saved, connected or not. Hyprland
  -- keeps these as rules and applies the matching one when the monitor appears.
  for _, saved in pairs(monitors) do
    if saved.output then rule(saved) end
  end

  -- Positions for the current set of monitors, if that set was ever arranged.
  local function arrange(gone)
    local present, n = enabled_identities(gone)
    local layout = matching(present, n)
    if not layout then return end
    for id, position in pairs(layout) do
      local saved = monitors[id]
      if saved and saved.output and present[id] then rule(saved, position) end
    end
  end

  -- At load and on every reload. During startup no monitor is connected yet,
  -- so this finds nothing and monitor.added does the work instead.
  arrange()

  -- A hotplug does not re-run the config, so the set of monitors that just
  -- changed is arranged here. Deferred like Omarchy's own handlers: a removal is
  -- reported from inside the monitor's teardown.
  hl.on("monitor.added", function()
    hl.timer(function() arrange() end, { type = "oneshot", timeout = 1 })
  end)
  hl.on("monitor.removed", function(monitor)
    local name = monitor and monitor.name
    hl.timer(function() arrange(name) end, { type = "oneshot", timeout = 1 })
  end)
end
