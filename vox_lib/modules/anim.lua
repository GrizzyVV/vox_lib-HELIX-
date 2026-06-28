--[[ lib.playAnim / lib.stopAnim — play a montage animation on a pawn, with optional eased BLEND between animations.

     ✅ SLOT BUG FIXED (2026-06-27, in-engine via MUSE). The earlier non-render was a WRONG SLOT: vox_lib defaulted
     AnimSlotName to "FullBody", which is NOT a real montage slot on the player ABP (`ABP_Unified_Character`) — montages
     played into a non-existent slot, so nothing rendered. Confirmed in PIE: playing on "DefaultSlot" visibly animates the
     player pawn (wave anim, arm raised — captured + human-watched). The HPlayAnimParams struct's OWN default for this field
     is already "DefaultSlot"; vox_lib was overriding the good default. The real slots on this ABP are "DefaultSlot"
     (primary/full-body) and "UpperBody".

     Built on the HELIX `Animation` global: Animation.Play(pawn, animAssetPath, UE.FHPlayAnimParams, onDone) -> success ;
     Animation.Stop(pawn). CLIENT-side (animation is local render). Anim assets live under
     `/HelixAnimation/Unified/Animations/<Category>/<Name>` (Actions/Emote/Club_Dance/Death/...); A_ = sequence, AM_ = montage.

     AUTHORITATIVE HPlayAnimParams CONTRACT (read live off the struct CDO in-engine 2026-06-27 — field = default):
       AnimSlotName="DefaultSlot", LoopCount=0, BlendInTime=0.25, BlendOutTime=0.25, PlayRate=1.0, StartTimeSeconds=0.0,
       CanBeCancelled=true, IgnoreMovementInput=false, IgnoreCorrections=true, RootMotionTranslationScale=1.0,
       UseMotionWarping=false, WarpTargetName, WarpTargetTransform, MovementMode, OwnedGameplayTags.
       (UseMotionWarping + WarpTarget* are the SAME warp fields the native vehicle-enter montage uses — see entity.lua.)

     ANIM INTERPOLATION / BLENDING: UE montages crossfade from the current pose to the new animation over a blend duration,
     and playing a new montage on the SAME slot blends out the previous one — so anim A -> anim B is smooth when
     blendIn/blendOut are set. Parametric blend-spaces (walk<->run by speed) are a separate anim-BP mechanism, not exposed here. ]]

local _playing = {}   -- pawn -> last anim path (best-effort tracking; HELIX has no GetPlayingAnim readback)

-- pawn: the character/pawn to animate. animPath: the animation asset path.
-- opts: { loop = bool, slot = "DefaultSlot"|"UpperBody" (default "DefaultSlot"), blendIn = sec, blendOut = sec,
--         playRate = number, lockMovement = bool (IgnoreMovementInput — freeze the player for emotes),
--         cancellable = bool (CanBeCancelled; default true), onComplete = function }
--   -> returns { ok, value=success } (the result of Animation.Play).
--   blendIn/blendOut crossfade the transition (smooth A->B); playRate scales speed (1 = normal).
function lib.playAnim(pawn, animPath, opts)
    if not pawn then return { ok = false, error = "pawn required" } end
    if type(animPath) ~= "string" or animPath == "" then return { ok = false, error = "animPath (asset path) required" } end
    if type(Animation) ~= "table" or type(Animation.Play) ~= "function" then
        return { ok = false, error = "Animation API unavailable on this side/build" }
    end
    opts = opts or {}
    local params
    local okp = pcall(function() params = UE.FHPlayAnimParams() end)
    if not okp or not params then return { ok = false, error = "FHPlayAnimParams unavailable" } end
    -- LoopCount: -1 = loop indefinitely; 0 = play once (the struct default). (Was "or 1" — corrected to the engine default 0.)
    pcall(function() params.LoopCount = opts.loop and -1 or 0 end)
    -- SLOT: must be a real montage slot on the player ABP ("DefaultSlot" or "UpperBody"). "DefaultSlot" = the struct default
    -- and the slot confirmed to render in-engine (2026-06-27). Passing a non-slot string (e.g. the old "FullBody") = no render.
    pcall(function() params.AnimSlotName = opts.slot or "DefaultSlot" end)
    -- BLEND fields: BlendInTime / BlendOutTime / PlayRate (numbers, seconds). blendIn/blendOut crossfade the transition
    -- FROM the current pose/anim TO this one (smooth A->B).
    if opts.blendIn ~= nil then pcall(function() params.BlendInTime = opts.blendIn end) end
    if opts.blendOut ~= nil then pcall(function() params.BlendOutTime = opts.blendOut end) end
    if opts.playRate ~= nil then pcall(function() params.PlayRate = opts.playRate end) end
    if opts.lockMovement ~= nil then pcall(function() params.IgnoreMovementInput = opts.lockMovement and true or false end) end
    if opts.cancellable ~= nil then pcall(function() params.CanBeCancelled = opts.cancellable and true or false end) end
    local success
    local ok = pcall(function()
        success = Animation.Play(pawn, animPath, params, function()
            _playing[pawn] = nil
            if opts.onComplete then pcall(opts.onComplete) end
        end)
    end)
    if not ok then return { ok = false, error = "Animation.Play failed" } end
    _playing[pawn] = animPath
    return { ok = true, value = success }
end

-- Stop the current animation on a pawn (blends back to the base pose). opts reserved for future blend-out control.
function lib.stopAnim(pawn, _opts)
    if not pawn then return { ok = false, error = "pawn required" } end
    if type(Animation) ~= "table" or type(Animation.Stop) ~= "function" then
        return { ok = false, error = "Animation API unavailable" }
    end
    local ok = pcall(function() Animation.Stop(pawn) end)
    _playing[pawn] = nil
    return ok and { ok = true } or { ok = false, error = "Animation.Stop failed" }
end

-- best-effort: the last anim path we started on this pawn (nil once it completes / is stopped). Not an engine readback.
function lib.getPlayingAnim(pawn) return _playing[pawn] end

return lib.playAnim
