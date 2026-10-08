###
#   ModAnimationConverter - lottie_to_warzone
#
#   Converts a Lottie (Bodymovin) JSON animation into the frame-table format
#   that a Warzone mod's Client_Visual hook expects: a fixed-topology triangle
#   mesh (vertices + triangle indices + a color per vertex) sampled at a
#   handful of keyframes, which the game then linearly tweens between.
#
#   Current scope (v1 - core conversion logic, no UI yet):
#     - Each shape group ("gr") within a layer must contain exactly one path
#       ("sh") item and one solid fill ("fl") item; each such group becomes
#       its own piece of mesh, with its own (and any enclosing groups') "tr"
#       transform composed with the layer's. Strokes, gradients and masks
#       are not yet supported.
#     - The path's vertex COUNT must stay constant across all of its
#       keyframes (pure morphing of existing points is fine; a shape that
#       adds/removes points over time is not yet supported - see
#       tessellate_path for where point correspondence is established).
#     - Frames are emitted at the Lottie file's own keyframe times (not evenly spaced
#       in time), downsampled to --samples if there are more than that. Lottie's bezier
#       easing curves are approximated by one of Warzone's five Ease presets - see
#       _classify_ease - rather than reproduced exactly, since Warzone only tweens
#       between frames with a fixed preset per transition, not an arbitrary curve.
#     - Layer transform (position/scale/rotation/anchor) is applied, but
#       split-dimension position ({"s": true, "x": ..., "y": ...}) is not.
#     - Opacity keyframes are ignored.
#
#   Usage:
#       python lottie_to_warzone.py input.json output.lua --samples 12 --segment-samples 8
###

import argparse
import json
import math
import os
from dataclasses import dataclass
from typing import Any, List, Optional, Sequence, Tuple


# =====================================================
# ===================  KEYFRAME DATA  ================
# =====================================================

@dataclass
class Keyframe:
    frame: float
    value: Any  # number, [numbers], or a path dict {"i", "o", "v", "c"}
    ease: str = "Linear"  # Warzone VisualFrameEase for the segment starting at this keyframe


def _classify_ease(kf: dict) -> str:
    """Approximates a Lottie keyframe's easing as one of Warzone's VisualFrameEase presets
    (Linear/EaseIn/EaseOut/EaseInOut/Step). Warzone only tweens between frames using a fixed
    preset per transition, not an arbitrary bezier curve, so this can't be exact - it collapses
    everything that isn't a hold or dead-on-linear into "EaseInOut" rather than guess at a
    direction (EaseIn vs EaseOut) we have no way to verify without seeing it render.

    kf.get("h") == 1 means a hold keyframe (value jumps at the next keyframe, no tween) -> Step.

    "o" and "i" are the cubic bezier's two control points (P1, P2) for a segment running from
    (0,0) to (1,1) in (time-fraction, value-fraction) space. The curve is a straight line - true
    Linear motion - only when both control points sit exactly on that diagonal (o.x==o.y and
    i.x==i.y); any other position bends the curve into a real ease. Note this is NOT simply
    "o.y near 0 and i.y near 1" - e.g. o={x:0.33,y:0}, i={x:0.67,y:1} (commonly seen in exported
    files) looks like it might be the default, but plugging it through De Casteljau's algorithm
    shows it's actually a standard symmetric ease-in-ease-out curve (at 25% of the time, only
    ~15.6% of the value has changed) - not linear at all.
    """
    if kf.get("h") == 1:
        return "Step"
    o, i = kf.get("o"), kf.get("i")
    if not o or not i:
        return "Linear"  # last keyframe in a property has no outgoing segment to ease
    o_x = o.get("x", [0])[0] if isinstance(o.get("x", [0]), list) else o.get("x", 0)
    o_y = o.get("y", [0])[0] if isinstance(o.get("y", [0]), list) else o.get("y", 0)
    i_x = i.get("x", [1])[0] if isinstance(i.get("x", [1]), list) else i.get("x", 1)
    i_y = i.get("y", [1])[0] if isinstance(i.get("y", [1]), list) else i.get("y", 1)
    if abs(o_x - o_y) < 0.02 and abs(i_x - i_y) < 0.02:
        return "Linear"
    return "EaseInOut"


def _lerp(a, b, f):
    if isinstance(a, dict):
        # Path value: {"i": [[x,y],...], "o": [[x,y],...], "v": [[x,y],...], "c": bool}
        return {
            "i": _lerp(a["i"], b["i"], f),
            "o": _lerp(a["o"], b["o"], f),
            "v": _lerp(a["v"], b["v"], f),
            "c": a["c"],
        }
    if isinstance(a, (list, tuple)):
        return [_lerp(av, bv, f) for av, bv in zip(a, b)]
    return a + (b - a) * f


def parse_keyframed_property(prop: dict) -> Tuple[bool, Any]:
    """Returns (is_animated, value_or_keyframes).

    Lottie represents a static property as {"a": 0, "k": <value>} and an
    animated one as {"a": 1, "k": [<keyframe>, ...]}. Each keyframe dict's
    "s" is the value it holds starting at that keyframe's "t" (frame); we
    ignore its legacy "e" end-value and just linearly interpolate between
    consecutive keyframes' "s" values for sampling, while separately
    recording each keyframe's "i"/"o" easing (see _classify_ease) for
    when that exact keyframe time is chosen as a Warzone frame.
    """
    k = prop["k"]
    if prop.get("a") != 1 or not isinstance(k, list) or not k or not isinstance(k[0], dict):
        return False, k

    keyframes = []
    for kf in k:
        value = kf["s"]
        # Shape ("sh") keyframes wrap their path dict in a one-element list.
        if isinstance(value, list) and len(value) == 1 and isinstance(value[0], dict) and "v" in value[0]:
            value = value[0]
        keyframes.append(Keyframe(frame=kf["t"], value=value, ease=_classify_ease(kf)))
    return True, keyframes


def sample_property(parsed: Tuple[bool, Any], frame: float, default=None):
    is_animated, data = parsed
    if data is None:
        return default
    if not is_animated:
        return data

    keyframes: List[Keyframe] = data
    if frame <= keyframes[0].frame:
        return keyframes[0].value
    if frame >= keyframes[-1].frame:
        return keyframes[-1].value

    for i in range(len(keyframes) - 1):
        a, b = keyframes[i], keyframes[i + 1]
        if a.frame <= frame <= b.frame:
            span = b.frame - a.frame
            f = 0.0 if span <= 0 else (frame - a.frame) / span
            return _lerp(a.value, b.value, f)
    return keyframes[-1].value


# =====================================================
# ===================  LOTTIE PARSING  ================
# =====================================================

@dataclass
class Transform:
    position: Tuple[bool, Any]
    anchor: Tuple[bool, Any]
    scale: Tuple[bool, Any]
    rotation: Tuple[bool, Any]


@dataclass
class ShapeInstance:
    name: str
    path: Tuple[bool, Any]          # parsed "sh" property (path dict or keyframes thereof)
    fill_color: Tuple[bool, Any]    # parsed "fl.c" property ([r,g,b,a] 0..1, or keyframes)
    transforms: List[Transform]     # applied innermost (own group) to outermost (layer), in order


def _parse_transform(ks: dict) -> Transform:
    return Transform(
        position=parse_keyframed_property(ks["p"]) if "p" in ks else (False, [0, 0]),
        anchor=parse_keyframed_property(ks["a"]) if "a" in ks else (False, [0, 0]),
        scale=parse_keyframed_property(ks["s"]) if "s" in ks else (False, [100, 100]),
        rotation=parse_keyframed_property(ks["r"]) if "r" in ks else (False, 0),
    )


def _collect_shape_instances(items: list) -> List[Tuple[dict, dict, List[dict]]]:
    """Depth-first search for every path+fill pair in a layer's shape list.

    A Lottie shape layer can contain several sibling groups ("gr"), each with
    its own path ("sh"), fill ("fl") and transform ("tr") - e.g. the several
    dots of a loading spinner, each pulsing independently. This returns one
    entry per path+fill pair found, with the chain of group transforms (own
    group first, then any enclosing groups) that must be applied to it.
    """
    local_path, local_fill, local_tr = None, None, None
    direct_results: List[Tuple[dict, dict, List[dict]]] = []
    nested_results: List[Tuple[dict, dict, List[dict]]] = []

    for item in items:
        item_type = item.get("ty")
        if item_type == "sh" and local_path is None:
            local_path = item
        elif item_type == "fl" and local_fill is None:
            local_fill = item
        elif item_type == "tr" and local_tr is None:
            local_tr = item
        elif item_type == "gr":
            nested_results.extend(_collect_shape_instances(item.get("it", [])))

    if local_path is not None and local_fill is not None:
        direct_results.append((local_path, local_fill, [local_tr] if local_tr else []))

    if local_tr is not None:
        nested_results = [(p, f, chain + [local_tr]) for p, f, chain in nested_results]

    return direct_results + nested_results


def load_lottie(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def extract_shape_layers(lottie: dict) -> List[ShapeInstance]:
    instances = []
    for layer in lottie.get("layers", []):
        if layer.get("ty") != 4:  # 4 == shape layer
            continue

        layer_transform = _parse_transform(layer.get("ks", {}))
        pairs = _collect_shape_instances(layer.get("shapes", []))
        for index, (path_item, fill_item, tr_chain) in enumerate(pairs):
            transforms = [_parse_transform(tr) for tr in tr_chain] + [layer_transform]
            instances.append(ShapeInstance(
                name=f"{layer.get('nm', 'layer')}/{index}",
                path=parse_keyframed_property(path_item["ks"]),
                fill_color=parse_keyframed_property(fill_item["c"]),
                transforms=transforms,
            ))
    return instances


# =====================================================
# ===================  TESSELLATION  ==================
# =====================================================

def _cubic_bezier_point(p0, p1, p2, p3, t):
    mt = 1 - t
    x = (mt**3) * p0[0] + 3 * (mt**2) * t * p1[0] + 3 * mt * (t**2) * p2[0] + (t**3) * p3[0]
    y = (mt**3) * p0[1] + 3 * (mt**2) * t * p1[1] + 3 * mt * (t**2) * p2[1] + (t**3) * p3[1]
    return x, y


def tessellate_path(path_value: dict, segment_samples: int) -> List[Tuple[float, float]]:
    """Flattens a Lottie path (vertices + in/out bezier handles) into a fixed-size
    polygon: segment_samples points per edge, for every edge between consecutive
    vertices (wrapping around if the path is closed).

    This fixed sample count per edge is what gives every frame of the same shape
    the same vertex count/order, which Warzone's frame tweening requires. It only
    produces matching output across keyframes if the underlying path keeps the
    same number of vertices throughout its animation.
    """
    vertices = path_value["v"]
    out_tangents = path_value["o"]
    in_tangents = path_value["i"]
    closed = path_value.get("c", True)

    n = len(vertices)
    edge_count = n if closed else n - 1
    points = []
    for i in range(edge_count):
        j = (i + 1) % n
        p0 = vertices[i]
        p1 = (vertices[i][0] + out_tangents[i][0], vertices[i][1] + out_tangents[i][1])
        p2 = (vertices[j][0] + in_tangents[j][0], vertices[j][1] + in_tangents[j][1])
        p3 = vertices[j]
        for s in range(segment_samples):
            t = s / segment_samples
            points.append(_cubic_bezier_point(p0, p1, p2, p3, t))
    return points


def triangulate_polygon(points: Sequence[Tuple[float, float]]) -> List[int]:
    """Ear-clipping triangulation of a simple polygon. Returns a flat list of
    0-based vertex indices, three per triangle. Assumes no self-intersections
    and no holes."""

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    def point_in_triangle(p, a, b, c):
        d1 = cross(a, b, p)
        d2 = cross(b, c, p)
        d3 = cross(c, a, p)
        has_neg = d1 < 0 or d2 < 0 or d3 < 0
        has_pos = d1 > 0 or d2 > 0 or d3 > 0
        return not (has_neg and has_pos)

    indices = list(range(len(points)))
    # Ensure counter-clockwise winding (ear clipping below assumes it).
    signed_area = sum(
        points[i][0] * points[(i + 1) % len(points)][1] - points[(i + 1) % len(points)][0] * points[i][1]
        for i in range(len(points))
    )
    if signed_area < 0:
        indices.reverse()

    triangles = []
    guard = 0
    while len(indices) > 3 and guard < len(points) * len(points) + 10:
        guard += 1
        ear_found = False
        for k in range(len(indices)):
            i_prev = indices[(k - 1) % len(indices)]
            i_cur = indices[k]
            i_next = indices[(k + 1) % len(indices)]
            a, b, c = points[i_prev], points[i_cur], points[i_next]

            if cross(a, b, c) <= 0:
                continue  # reflex vertex, can't be an ear

            if any(
                indices[m] not in (i_prev, i_cur, i_next) and point_in_triangle(points[indices[m]], a, b, c)
                for m in range(len(indices))
            ):
                continue  # another vertex sits inside this candidate ear

            triangles.extend([i_prev, i_cur, i_next])
            indices.pop(k)
            ear_found = True
            break

        if not ear_found:
            break  # degenerate polygon; stop rather than loop forever

    if len(indices) == 3:
        triangles.extend(indices)
    return triangles


# =====================================================
# ===================  TRANSFORM  =====================
# =====================================================

def apply_transform(point, position, anchor, scale, rotation_degrees):
    x, y = point[0] - anchor[0], point[1] - anchor[1]
    x, y = x * (scale[0] / 100.0), y * (scale[1] / 100.0)
    rad = math.radians(rotation_degrees)
    cos_r, sin_r = math.cos(rad), math.sin(rad)
    x, y = x * cos_r - y * sin_r, x * sin_r + y * cos_r
    return x + position[0], y + position[1]


def apply_transform_chain(point, transforms: List[Transform], frame: float):
    """Applies each transform in order (own group first, then any enclosing
    groups, then the layer) - each one's position/anchor/scale/rotation is
    sampled at the given frame before being applied."""
    x, y = point
    for transform in transforms:
        position = sample_property(transform.position, frame, [0, 0])
        anchor = sample_property(transform.anchor, frame, [0, 0])
        scale = sample_property(transform.scale, frame, [100, 100])
        rotation = sample_property(transform.rotation, frame, 0)
        x, y = apply_transform((x, y), position, anchor, scale, rotation)
    return x, y


def color_to_hex(c) -> str:
    r, g, b = c[0], c[1], c[2]
    to_byte = lambda v: max(0, min(255, round(v * 255)))
    return "#{:02X}{:02X}{:02X}".format(to_byte(r), to_byte(g), to_byte(b))


# =====================================================
# ===================  CONVERSION  ====================
# =====================================================

@dataclass
class Frame:
    t: float
    vertices: List[Tuple[float, float]]
    colors: List[str]
    ease: Optional[str] = None  # None on the first frame: there's no incoming tween to ease


def _iter_properties(shape: ShapeInstance):
    yield shape.path
    yield shape.fill_color
    for transform in shape.transforms:
        yield transform.position
        yield transform.anchor
        yield transform.scale
        yield transform.rotation


def collect_sample_times(shape_instances: List[ShapeInstance], start_frame: float, end_frame: float, max_frames: int) -> List[Tuple[float, Optional[str]]]:
    """Picks the Lottie frame numbers to sample, instead of spacing them evenly across
    [start_frame, end_frame]: the union of every animated property's own keyframe times,
    across every shape, so each frame emitted actually corresponds to something changing
    in the source file. Downsamples evenly (always keeping the first and last) if that
    union has more than max_frames entries, since Warzone caps SetFrames at 32 anyway.

    Returns (frame_number, ease) pairs; ease is the preset for the tween arriving at that
    frame, from whichever property's keyframe landed there (ties broken by preferring Step,
    then EaseInOut, then Linear, so a hold or a genuine ease is never masked by an unrelated
    property that happens to be linear at the same instant).
    """
    priority = {"Linear": 0, "EaseInOut": 1, "Step": 2}
    by_time: dict = {}

    for shape in shape_instances:
        for parsed in _iter_properties(shape):
            is_animated, data = parsed
            if not is_animated:
                continue
            for kf in data:
                key = round(kf.frame, 3)
                if key not in by_time or priority[kf.ease] > priority[by_time[key]]:
                    by_time[key] = kf.ease

    by_time.setdefault(round(start_frame, 3), "Linear")
    by_time.setdefault(round(end_frame, 3), "Linear")

    times = sorted(t for t in by_time if start_frame - 1e-6 <= t <= end_frame + 1e-6)

    if len(times) > max_frames:
        if max_frames <= 1:
            times = [times[0]]
        else:
            indices = sorted({round(i * (len(times) - 1) / (max_frames - 1)) for i in range(max_frames)})
            times = [times[i] for i in indices]

    return [(t, by_time[t]) for t in times]


def convert(lottie: dict, samples: int, segment_samples: int, max_shapes: int = None) -> Tuple[List[int], List[Frame], float]:
    fps = lottie.get("fr", 30)
    start_frame, end_frame = lottie.get("ip", 0), lottie.get("op", fps)
    duration_ms = (end_frame - start_frame) / fps * 1000

    shape_instances = extract_shape_layers(lottie)
    if not shape_instances:
        raise ValueError("No supported shape layers (path + fill) found in this Lottie file.")
    if max_shapes is not None:
        shape_instances = shape_instances[:max_shapes]

    sample_points = collect_sample_times(shape_instances, start_frame, end_frame, samples)

    triangles: List[int] = []
    vertex_offset = 0
    reference_layer_point_counts: List[int] = []
    frames: List[Frame] = []

    for sample_index, (frame_number, ease) in enumerate(sample_points):
        t = (frame_number - start_frame) / (end_frame - start_frame) if end_frame > start_frame else 0.0

        all_vertices: List[Tuple[float, float]] = []
        all_colors: List[str] = []

        for layer_index, layer in enumerate(shape_instances):
            path_value = sample_property(layer.path, frame_number)
            local_points = tessellate_path(path_value, segment_samples)
            points = [apply_transform_chain(p, layer.transforms, frame_number) for p in local_points]

            if sample_index == 0:
                # Triangulate the path's own (pre-transform) geometry, not the
                # transformed points: a group's animated scale/position (e.g. a
                # dot that pops in from zero scale) would otherwise collapse the
                # reference frame into a degenerate polygon with no valid ears.
                reference_layer_point_counts.append(len(points))
                layer_triangles = triangulate_polygon(local_points)
                triangles.extend(idx + vertex_offset for idx in layer_triangles)
                vertex_offset += len(points)
            elif len(points) != reference_layer_point_counts[layer_index]:
                raise ValueError(
                    f"Layer '{layer.name}' has a varying vertex count across keyframes "
                    f"({reference_layer_point_counts[layer_index]} vs {len(points)}); "
                    "shapes that add/remove path points over time are not yet supported."
                )

            color = color_to_hex(sample_property(layer.fill_color, frame_number, [0, 0, 0, 1]))
            all_vertices.extend(points)
            all_colors.extend([color] * len(points))

        frames.append(Frame(t=t, vertices=all_vertices, colors=all_colors, ease=ease if sample_index > 0 else None))

    return triangles, frames, duration_ms


# =====================================================
# ===================  LUA OUTPUT  ====================
# =====================================================

def _lua_number(value: float, precision: int) -> str:
    formatted = f"{value:.{precision}f}"
    return formatted.rstrip("0").rstrip(".") if "." in formatted else formatted


def _frame_colors(frame: Frame):
    """Collapses a frame's per-vertex color list down to a single color when every
    vertex shares the same one (the common case for a solid-fill shape) - Warzone's
    VisualFrame.Colors explicitly accepts one color for the whole frame, and this is
    by far the biggest lever on payload size, since the per-vertex list repeats the
    same ~9-character hex string once per vertex."""
    if frame.colors and all(c == frame.colors[0] for c in frame.colors):
        return frame.colors[0]
    return frame.colors


def write_lua_table(path: str, triangles: List[int], frames: List[Frame], duration_ms: float, precision: int = 1):
    lines = ["return {"]
    lines.append("    AnchorPoint = {0, 0},")

    tri_values = ", ".join(str(i + 1) for i in triangles)  # Lua is 1-based
    lines.append(f"    Triangles = {{{tri_values}}},")

    lines.append("    Frames = {")
    for frame in frames:
        vertex_values = ", ".join(
            "{" + f"{_lua_number(x, precision)}, {_lua_number(y, precision)}" + "}" for x, y in frame.vertices
        )
        colors = _frame_colors(frame)
        color_values = f'"{colors}"' if isinstance(colors, str) else "{" + ", ".join(f'"{c}"' for c in colors) + "}"
        ease_field = f', Ease = "{frame.ease}"' if frame.ease else ""
        lines.append(f'        {{ t = {_lua_number(frame.t, 3)}, Vertices = {{{vertex_values}}}, Colors = {color_values}{ease_field} }},')
    lines.append("    },")

    lines.append(f"    Duration = {round(duration_ms)},")
    lines.append("}")
    lines.append("")

    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def _frame_to_json(frame: Frame, precision: int) -> dict:
    data = {
        "t": round(frame.t, 3),
        "Vertices": [[round(x, precision), round(y, precision)] for x, y in frame.vertices],
        "Colors": _frame_colors(frame),
    }
    if frame.ease:
        data["Ease"] = frame.ease
    return data


def build_json_data(triangles: List[int], frames: List[Frame], duration_ms: float, precision: int = 1) -> dict:
    return {
        "AnchorPoint": [0, 0],
        "Triangles": [i + 1 for i in triangles],
        "Frames": [_frame_to_json(frame, precision) for frame in frames],
        "Duration": round(duration_ms),
    }


def write_json(path: str, triangles: List[int], frames: List[Frame], duration_ms: float, precision: int = 1):
    """Writes the same data as write_lua_table, but as JSON. This is what the
    LottieAnimationTester mod's paste box expects: mods can't safely eval an
    arbitrary pasted Lua table (load/loadstring are sandboxed out), so the
    mod hand-decodes JSON instead. Triangle indices are emitted 1-based to
    match Lua/Warzone's Visual.SetTriangles indexing."""
    data = build_json_data(triangles, frames, duration_ms, precision)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, separators=(",", ":"))


# =====================================================
# ==================  WARZONE LIMITS  =================
# =====================================================

# Warzone's Visual API caps: at most 1024 vertices, 2048 triangles (SetTriangles),
# and 32 frames (SetFrames). Exceeding these will fail or be rejected in-game.
MAX_VERTICES = 1024
MAX_TRIANGLES = 2048
MAX_FRAMES = 32


def check_warzone_limits(triangles: List[int], frames: List[Frame]):
    vertex_count = len(frames[0].vertices) if frames else 0
    triangle_count = len(triangles) // 3
    if vertex_count > MAX_VERTICES:
        print(f"WARNING: {vertex_count} vertices per frame exceeds Warzone's limit of {MAX_VERTICES}. Lower --segment-samples or remove shape layers.")
    if triangle_count > MAX_TRIANGLES:
        print(f"WARNING: {triangle_count} triangles exceeds Warzone's limit of {MAX_TRIANGLES}. Lower --segment-samples or remove shape layers.")
    if len(frames) > MAX_FRAMES:
        print(f"WARNING: {len(frames)} frames exceeds Warzone's limit of {MAX_FRAMES}. Lower --samples.")


# =====================================================
# =======================  CLI  =======================
# =====================================================

def main():
    parser = argparse.ArgumentParser(description="Convert a Lottie animation into a Warzone mod frame table.")
    parser.add_argument("input", help="Path to the source .json Lottie file")
    parser.add_argument("output", help="Path to write the generated output to")
    parser.add_argument("--format", choices=["json", "lua"], default="json", help="Output format: json (for pasting into the LottieAnimationTester mod) or lua (a 'return {...}' table, for bundling directly into a mod's own files)")
    parser.add_argument("--samples", type=int, default=12, help="Maximum number of Warzone keyframes to emit. Frames are taken from the Lottie file's own keyframe times (not evenly spaced), downsampled evenly to this count if there are more")
    parser.add_argument("--segment-samples", type=int, default=6, dest="segment_samples", help="Number of tessellated points per path edge (controls mesh density)")
    parser.add_argument("--precision", type=int, default=1, help="Decimal places to round vertex coordinates to (fewer = smaller output)")
    parser.add_argument("--max-chars", type=int, default=None, dest="max_chars", help="If the output would exceed this many characters, automatically lower --samples/--segment-samples (and, as a last resort, drop shape layers) until it fits. Warzone's GameOrderCustom.Payload has an undocumented server-side length cap ('StringTooLong') - use this to stay under whatever that turns out to be.")
    args = parser.parse_args()

    lottie = load_lottie(args.input)
    samples, segment_samples = args.samples, args.segment_samples
    max_shapes = len(extract_shape_layers(lottie))
    triangles, frames, duration_ms = convert(lottie, samples, segment_samples, max_shapes)

    if args.max_chars is not None:
        def payload_length():
            return len(json.dumps(build_json_data(triangles, frames, duration_ms, args.precision), separators=(",", ":")))

        payload_len = payload_length()
        # First squeeze geometric detail (cheap: still animates every shape, just coarser).
        while payload_len > args.max_chars and (segment_samples > 2 or samples > 2):
            if segment_samples > 2:
                segment_samples -= 1
            elif samples > 2:
                samples -= 1
            triangles, frames, duration_ms = convert(lottie, samples, segment_samples, max_shapes)
            payload_len = payload_length()

        # Still too big at the floor: this mod's test orders can only carry so many shape
        # layers at all, regardless of detail, so start dropping layers entirely (lossy -
        # whole dots/parts of the source animation disappear from the test render).
        while payload_len > args.max_chars and max_shapes > 1:
            max_shapes -= 1
            triangles, frames, duration_ms = convert(lottie, samples, segment_samples, max_shapes)
            payload_len = payload_length()

        if payload_len > args.max_chars:
            print(f"WARNING: could not get under {args.max_chars} characters even with a single shape layer at minimum detail (ended at {payload_len} characters).")
        else:
            print(f"Auto-shrunk to samples={samples}, segment-samples={segment_samples}, shapes={max_shapes}/{len(extract_shape_layers(lottie))} ({payload_len} characters)")

    check_warzone_limits(triangles, frames)

    if args.format == "json":
        write_json(args.output, triangles, frames, duration_ms, args.precision)
    else:
        write_lua_table(args.output, triangles, frames, duration_ms, args.precision)

    output_len = os.path.getsize(args.output)
    print(f"Wrote {len(frames)} frames, {len(triangles) // 3} triangles to {args.output} ({output_len} bytes - paste this into the LottieAnimationTester mod's Submit Animation box; it's chunk-uploaded separately from the order itself, so this size isn't limited by order.Payload's cap)")


if __name__ == "__main__":
    main()
