-- State rebuild.
--
-- All script state of this mod (`storage.balancer/parts/belts/lanes/events`) is derived from placed entities, and
-- `storage` is private to one mod name. When this mod is added to a save that was made with Belt Balancer 2 / 3 the
-- entities (same prototype names) are all there but `storage` is empty, so nothing would manage them.
-- This replays the mod's own registration (`belt_functions.built_belt`, `built_splitter`, `part_functions.get_or_create`)
-- for every balancer-part on every surface (planets, space platforms, factory interiors ...) and for every belt-like entity
-- next to one. Belts that are not next to a balancer-part are never tracked by live play either, so they are not scanned.
--
-- Safe to call at any time: parts that are already tracked are skipped and every registration step is idempotent.
-- Big saves are processed a few parts per tick (see PARTS_PER_TICK) so the one-time cost does not freeze the game.
-- Cost when nothing is queued: one nil check per tick.

rebuild_functions = {}

-- every entity type that belt_functions.built_belt / built_splitter handle (see BELT_TYPES in control.lua)
local SCAN_TYPES = { "transport-belt", "underground-belt", "linked-belt", "loader", "loader-1x1", "splitter" }

-- up to this many parts are rebuilt per tick; below SYNC_LIMIT parts everything is done immediately
local PARTS_PER_TICK = 150
local SYNC_LIMIT = 150

---rebuild the registration of one part and the belts around it (belts first, then the part itself)
---@param part LuaEntity
local function rebuild_part(part)
    if not part.valid or storage.parts[part.unit_number] then
        return
    end
    local position = part.position
    local near = part.surface.find_entities_filtered {
        area = { { position.x - 3, position.y - 3 }, { position.x + 3, position.y + 3 } },
        type = SCAN_TYPES,
    }
    for _, entity in pairs(near) do
        if entity.valid then
            if entity.type == "splitter" then
                belt_functions.built_splitter(entity)
            else
                belt_functions.built_belt(entity)
            end
        end
    end
    -- parts without any belt (or whose belts could not create it) are registered here
    part_functions.get_or_create(part)
end

---run (a slice of) the queue
---@param max_parts uint|nil nil = everything
local function run_queue(max_parts)
    local state = storage.rebuild
    if not state then
        return
    end
    local queue = state.queue
    local index = state.index
    local last = state.total
    if max_parts then
        last = math.min(last, index + max_parts - 1)
    end
    for i = index, last do
        rebuild_part(queue[i])
    end
    state.index = last + 1
    if state.index > state.total then
        log("[BBFIX] rebuild done: " .. state.total .. " parts queued, balancers=" .. table_size(storage.balancer) ..
            " parts=" .. table_size(storage.parts) .. " belts=" .. table_size(storage.belts) ..
            " lanes=" .. table_size(storage.lanes))
        storage.rebuild = nil
    end
end

---queue every balancer-part that is not tracked yet
---@param sync boolean|nil force a synchronous rebuild now
---@return uint number of parts that were queued
function rebuild_functions.start(sync)
    if storage.rebuild then
        -- a previous rebuild is still running; it will pick up everything that was untracked when it started
        if sync then
            run_queue(nil)
        end
        return storage.rebuild and storage.rebuild.total or 0
    end
    local queue = {}
    local count = 0
    for _, surface in pairs(game.surfaces) do
        for _, part in pairs(surface.find_entities_filtered { name = "balancer-part" }) do
            if not storage.parts[part.unit_number] then
                count = count + 1
                queue[count] = part
            end
        end
    end
    if count == 0 then
        return 0
    end
    storage.rebuild = { queue = queue, index = 1, total = count }
    log("[BBFIX] rebuild queued: " .. count .. " untracked balancer-parts")
    if sync or count <= SYNC_LIMIT then
        local profiler = helpers.create_profiler()
        run_queue(nil)
        profiler.stop()
        log { "", "[BBFIX] rebuild time (sync): ", profiler }
    end
    return count
end

---called from on_tick; does nothing unless a rebuild is pending
function rebuild_functions.on_tick()
    if storage.rebuild then
        local profiler = helpers.create_profiler()
        run_queue(PARTS_PER_TICK)
        profiler.stop()
        log { "", "[BBFIX] rebuild slice @", game.tick, " ", profiler }
    end
end

---@return boolean
function rebuild_functions.pending()
    return storage.rebuild ~= nil
end

return rebuild_functions
