--[[ lib.raycast / lib.raycastFromCamera — line traces over HELIX physics, returning the first hit.
     ⭐ Uses HELIX's OWN global trace API `Trace:LineSingle(Start, End, channel, mode, IgnoredActors)` (shipped in
     Engine/Content/LuaScript/API/Trace.lua) — the blessed path; returns an FHitResult or nil. We pass mode=0 (no debug draw)
     and IgnoredActors as a PLAIN Lua table.

     WHY (2026-06-30, Matt caught the log spam): the old hand-rolled `UKismetSystemLibrary.LineTraceSingle` call was WRONG and
     logged 'Invalid parameter' errors on every trace (it still returned a hit, so it looked fine). The correct signature —
     read straight from HELIX's Trace.lua — is `LineTraceSingle(World, Start, End, Channel, bComplex, IgnoreTABLE, DrawDebug,
     OutHit, bIgnoreSelf, TraceColor, TraceHitColor, DrawTime)`: World IS the 1st arg, ActorsToIgnore is a PLAIN TABLE (not a
     `UE.TArray`), OutHit is passed at pos 8 AND read back, and the trailing colors/DrawTime are REQUIRED. So we just call the
     `Trace` global; the direct call is a fallback (now with the correct signature) for builds lacking it.

     ✅ VERIFIED CLEAN in-engine 2026-07-01: a downward trace returned ok/hit=true, location Z=0 (ground), normal (0,0,1),
     distance 392.15 (self-consistent), and — the point — ZERO `LineTraceSingle` param errors in the whole log. placeOnGround
     (rides on this) dropped an object 892→0. ]]

local function toVec(c)   -- args-constructor form (Vector()+`.X=` does NOT persist on a table input — value-struct gotcha)
    if type(c) == "userdata" then return c end
    if c == nil then return Vector(0, 0, 0) end
    return Vector(c.x or c.X or c[1] or 0, c.y or c.Y or c[2] or 0, c.z or c.Z or c[3] or 0)
end

local function channel()
    return (UE and UE.ETraceTypeQuery and UE.ETraceTypeQuery.Visibility) or 0
end

local function readHit(hit)
    if not hit then return nil end
    local out = { raw = hit }
    pcall(function()
        -- BreakHitResult fills many fields; we surface the common ones defensively.
        local r = { UE.UGameplayStatics.BreakHitResult(hit) }
        -- Different builds return the break tuple in different orders; also try direct fields.
    end)
    pcall(function() out.location = hit.Location or hit.ImpactPoint end)
    pcall(function() out.normal = hit.Normal or hit.ImpactNormal end)
    pcall(function() out.actor = hit.HitActor or (hit.GetActor and hit:GetActor()) end)
    pcall(function() out.distance = hit.Distance end)
    return out
end

-- Trace a ray from `startCoords` to `endCoords`. opts: { ignore = {actors}, complex = bool, channel = <collision channel> }.
-- Returns { ok, hit = bool, result = { location, normal, actor, distance } | nil }.
function lib.raycast(startCoords, endCoords, opts)
    opts = opts or {}
    local S, E = toVec(startCoords), toVec(endCoords)
    local ignore = {}   -- PLAIN Lua table (HELIX Trace API wants a table, not a UE.TArray)
    if opts.ignore then for _, a in ipairs(opts.ignore) do ignore[#ignore + 1] = a end end

    -- ⭐ preferred: HELIX's own global Trace API. mode=0 => no debug draw. Returns an FHitResult or nil.
    if type(Trace) == "table" and Trace.LineSingle then
        local hit
        local ok = pcall(function() hit = Trace:LineSingle(S, E, opts.channel, 0, ignore) end)
        if not ok then return { ok = false, error = "Trace:LineSingle failed" } end
        if not hit then return { ok = true, hit = false, result = nil } end
        return { ok = true, hit = true, result = readHit(hit) }
    end

    -- fallback (no Trace global): the CORRECT direct signature (from HELIX API/Trace.lua) — OutHit passed AND read back.
    if type(UE) ~= "table" or not (UE.UKismetSystemLibrary and UE.UKismetSystemLibrary.LineTraceSingle) then
        return { ok = false, error = "no Trace global and LineTraceSingle unavailable" }
    end
    local hr = UE.FHitResult()
    local didHit
    local ok = pcall(function()
        didHit = UE.UKismetSystemLibrary.LineTraceSingle(
            HWorld, S, E, opts.channel or channel(), opts.complex and true or false,
            ignore, 0, hr, true, UE.FLinearColor.Red, UE.FLinearColor.Green, 0)
    end)
    if not ok then return { ok = false, error = "LineTraceSingle failed" } end
    return { ok = true, hit = didHit and true or false, result = didHit and readHit(hr) or nil }
end

-- Trace from the camera through a screen point (default screen centre). opts: { x, y (0-1 screen frac), distance (default 100000), ignore }.
-- Returns the same shape as lib.raycast.
function lib.raycastFromCamera(opts)
    if not HPlayer then return { ok = false, error = "HPlayer unavailable (client only)" } end
    if not (UE.UGameplayStatics and UE.UGameplayStatics.DeprojectScreenToWorld) then
        return { ok = false, error = "DeprojectScreenToWorld unavailable" }
    end
    opts = opts or {}
    local w, h = 1920, 1080
    pcall(function() w, h = HPlayer:GetViewportSize() end)
    local sx = (opts.x or 0.5) * w
    local sy = (opts.y or 0.5) * h
    local worldPos, worldDir
    local ok = pcall(function()
        worldPos, worldDir = UE.UGameplayStatics.DeprojectScreenToWorld(HPlayer, Vector2D(sx, sy))
    end)
    if not ok or not worldPos or not worldDir then return { ok = false, error = "deproject failed (probe return shape)" } end
    local dist = opts.distance or 100000
    local endPos = Vector(worldPos.X + worldDir.X * dist, worldPos.Y + worldDir.Y * dist, worldPos.Z + worldDir.Z * dist)
    return lib.raycast(worldPos, endPos, opts)
end

return lib.raycast
