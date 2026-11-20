require("Utilities");

require("Visuals.Visuals");
require("Visuals.Group");
require("Visuals.Vertex");
require("Visuals.VertexArray");
require("Visuals.2D.Rectangle");
require("Visuals.2D.Triangle");
require("Visuals.Animation.AnimationBuilder");
require("Visuals.Animation.MoveAnimation");

local PLANE_VISUAL_SIZE = 12;
local PLANE_VISUAL_DURATION_MS = 2000;
local PLANE_VISUAL_COLOR = "#222222";
local PLANE_VISUAL_OUTLINE_COLOR = "#FFFFFF";
local PLANE_VISUAL_OUTLINE_PADDING = 2;
local PLANE_VISUAL_LOOP_SEGMENTS = 16;

---Heading (in degrees) of the vector (dx, dy), for Visuals:RotateZ - same quadrant-corrected
---atan approach Visuals.2D.Arrow's own direction logic uses.
---@param dx number
---@param dy number
---@return number
function GetSpyPlaneHeadingDegrees(dx, dy)
    if (dx == 0) then return (dy >= 0) and 90 or -90; end

    local degrees = math.atan(dy / dx) / math.pi * 180;
    if (dx < 0) then degrees = degrees + 180; end
    return degrees;
end

---Builds the raw pieces of a simple glider-shaped plane silhouette (fuselage + pointed nose + main wing + tail
---wing), facing +X by default so Client_Visual can rotate the assembled group to the flight's heading before
---animating it along that direction. padding grows each piece outward by a fixed amount on every side (around
---its own center, not the shape's origin) - used to build a uniformly larger copy behind the normal-size body
---for an outline effect. A multiplicative scale would instead grow the long dimensions far more than the thin
---ones, leaving the outline visible only at the wingtips/nose/tail and not along the long straight edges.
---@param padding number? # Defaults to 0
---@return VisualObject[]
function CreateSpyPlaneVisualShapeParts(padding)
    padding = padding or 0;

    local fuselageLength = PLANE_VISUAL_SIZE * 5;
    local fuselageChord = PLANE_VISUAL_SIZE * 0.3 * 1.7;
    local noseLength = PLANE_VISUAL_SIZE * 0.5;
    local noseBaseX = fuselageLength / 2 + padding;

    local wingSpan = PLANE_VISUAL_SIZE * 6;
    local wingChord = PLANE_VISUAL_SIZE * 0.6;
    local wingOffsetX = PLANE_VISUAL_SIZE * 0.2;

    local tailSpan = PLANE_VISUAL_SIZE * 2;
    local tailChord = PLANE_VISUAL_SIZE * 0.4;
    local tailOffsetX = -PLANE_VISUAL_SIZE * 2;

    return {
        Rectangle:Create(fuselageLength + 2 * padding, fuselageChord + 2 * padding),
        --base flush with the (padded) fuselage end, tip extended outward by padding too
        Triangle:Create(Vertex(noseBaseX, fuselageChord / 2 + padding), Vertex(noseBaseX, -(fuselageChord / 2 + padding)), Vertex(noseBaseX + noseLength + padding, 0)),
        Rectangle:Create(wingChord + 2 * padding, wingSpan + 2 * padding):MoveX(wingOffsetX),
        Rectangle:Create(tailChord + 2 * padding, tailSpan + 2 * padding):MoveX(tailOffsetX),
    };
end

---Builds the plane visual: a uniformly padded, white copy of the silhouette behind the normal-size, normal-color
---one, so the larger copy's edges peek out from behind as an outline.
---@return Group
function CreateSpyPlaneVisualShape()
    local outlineParts = CreateSpyPlaneVisualShapeParts(PLANE_VISUAL_OUTLINE_PADDING);
    for _, part in ipairs(outlineParts) do part:SetColor(PLANE_VISUAL_OUTLINE_COLOR); end

    local bodyParts = CreateSpyPlaneVisualShapeParts();
    for _, part in ipairs(bodyParts) do part:SetColor(PLANE_VISUAL_COLOR); end

    local plane = Group:Create();
    plane:Add(table.unpack(outlineParts));
    plane:Add(table.unpack(bodyParts));
    return plane;
end

---Finishes building the visual: wires up the plane's (already-transformed/animated) triangles, vertices and
---colors, anchored at (anchorX, anchorY).
---@param visual Visual
---@param plane Group
---@param anchorX number
---@param anchorY number
---@param frames VisualFrame[]
function ApplySpyPlaneVisual(visual, plane, anchorX, anchorY, frames)
    visual.SetTriangles(plane:GetTriangles())
        .SetAnchorPoint(anchorX, anchorY)
        .SetVertices(plane:GetVertices())
        .SetColors(plane:GetColors())
        .SetDuration(PLANE_VISUAL_DURATION_MS)
        .SetFrames(frames);
end

---Animates the plane flying a single straight segment - used both for one step of a Steps flight and for an
---Instant Line/Path flight's whole route. Built facing +X, then rotated in place to the segment's heading before
---being animated across that same relative displacement so it travels the segment nose-first. RevolveZ (not
---RotateZ) is used deliberately - RotateZ pivots around the shape's own bounding-box center, which isn't the
---origin for this asymmetric silhouette, so it would shift the shape away from the anchor point SetAnchorPoint
---pins to the flight's start.
---@param visual Visual
---@param spot RectangleVM
function AnimateSpyPlaneStraightFlight(visual, spot)
    local dx = spot.Right - spot.Left;
    local dy = spot.Bottom - spot.Top;

    local plane = CreateSpyPlaneVisualShape();
    plane:RevolveZ(GetSpyPlaneHeadingDegrees(dx, dy));
    plane:AddAnimation(MoveAnimation:Create(dx, dy));

    ApplySpyPlaneVisual(visual, plane, spot.Left, spot.Top, AnimationBuilder:Create(plane):Build());
end

---Animates the plane flying a full loop - used for an Instant Circle flight, whose single event only carries the
---loop's bounding square (JumpToActionSpotOpt was built as center +/- radius on both axes, from which the
---center and radius can be recovered, but not the direction, which isn't carried by the event at all - always
---animated clockwise starting at the top, matching Application.lua's starting angle).
---Frames are built by hand rather than chaining one MoveAnimation per segment onto a single AnimationBuilder
---pass: AnimationBuilder derives each animation's progress from the time elapsed since the previous keyframe, so
---back-to-back animations sharing an exact boundary time both end up applying their full movement on that same
---boundary frame, corrupting the path. Pre-computing each frame's absolute vertex positions sidesteps that.
---@param visual Visual
---@param spot RectangleVM
function AnimateSpyPlaneLoopFlight(visual, spot)
    local centerX = (spot.Left + spot.Right) / 2;
    local centerY = (spot.Top + spot.Bottom) / 2;
    local radius = (spot.Right - spot.Left) / 2;

    local points = {};
    for i = 0, PLANE_VISUAL_LOOP_SEGMENTS do
        local angle = -math.pi / 2 + (i / PLANE_VISUAL_LOOP_SEGMENTS) * 2 * math.pi;
        table.insert(points, { X = math.cos(angle) * radius, Y = math.sin(angle) * radius });
    end
    local startPoint = points[1];

    local plane = CreateSpyPlaneVisualShape();
    plane:RevolveZ(GetSpyPlaneHeadingDegrees(points[2].X - startPoint.X, points[2].Y - startPoint.Y));
    local baseVertices = plane:GetVertices();
    local baseColors = plane:GetColors();

    local frames = {};
    for i, point in ipairs(points) do
        local offsetX = point.X - startPoint.X;
        local offsetY = point.Y - startPoint.Y;

        local frameVertices = VertexArray();
        for _, v in ipairs(baseVertices) do
            frameVertices:Add(Vertex(v[1] + offsetX, v[2] + offsetY, v[3]));
        end

        table.insert(frames, { t = (i - 1) / PLANE_VISUAL_LOOP_SEGMENTS, Vertices = frameVertices, Colors = baseColors });
    end

    ApplySpyPlaneVisual(visual, plane, centerX + startPoint.X, centerY + startPoint.Y, frames);
end

---Client_Visual hook
---@param game GameClientHook
---@param order GameOrder # Currently only GameOrderEvent's are passed, but that might change
---@param visual Visual
function Client_Visual(game, order, visual)
    if (order.proxyType ~= 'GameOrderEvent') then return; end
    ---@cast order GameOrderEvent

    local spot = order.JumpToActionSpotOpt;
    if (spot == nil) then return; end

    local isInstant = Mod.Settings.SpyPlaneFlightStyleInstant == true;

    --every mode's per-step "continues its flight" event already carries just that step's real segment via
    --JumpToActionSpotOpt - correct as a straight chord even for Circle, since each step's two points are sampled
    --directly off the loop's true path. The main "Flies a Spy Plane..." event only matches what's revealed this
    --turn on an Instant flight (on Steps it's covered by the first step's own "continues its flight" event
    --instead) - and for Circle specifically, that main event's JumpToActionSpotOpt is the loop's bounding square,
    --not a single segment, so it needs the full-loop animation instead of the straight-line one
    local isStepSegment = order.Message == "Spy Plane continues its flight";
    local isInstantCircleFlight = isInstant and startsWith(order.Message, "Flies a Spy Plane in a circle around");
    local isInstantStraightFlight = isInstant and not isInstantCircleFlight and startsWith(order.Message, "Flies a Spy Plane");

    if (isStepSegment or isInstantStraightFlight) then
        AnimateSpyPlaneStraightFlight(visual, spot);
    elseif (isInstantCircleFlight) then
        AnimateSpyPlaneLoopFlight(visual, spot);
    end
end
