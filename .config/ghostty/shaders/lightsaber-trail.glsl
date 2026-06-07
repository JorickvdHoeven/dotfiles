// Blue Lightsaber Cursor Trail for Ghostty
// Creates a glowing blue plasma trail behind the cursor as it moves.
// When TUI apps hide the cursor (Claude Code, vim, etc.), the trail is
// suppressed and only a subtle idle glow remains at the last known position.

// --- CONFIGURATION ---
const float DURATION = 0.25;              // trail animation duration (seconds)
const float TRAIL_SIZE = 0.85;            // 0.0 = all corners together, 1.0 = max smear
const float THRESHOLD_MIN_DISTANCE = 1.0; // min distance to show trail (cursor widths)
const float TRAIL_THICKNESS = 1.0;
const float TRAIL_THICKNESS_X = 1.0;
const float GLOW_IDLE_TIMEOUT = 3.0;    // seconds idle before glow fades (prevents ghost cursors)
const float GLOW_FADE_DURATION = 1.0;   // fade-out duration
const float FOCUS_LINE_DURATION = 0.25; // focus line animation duration (matches cursor trail speed)
const float FOCUS_LINE_LENGTH = 0.6;    // max line length in normalized coords

// Lightsaber glow radii (in normalized coords)
const float CORE_RADIUS = 0.003;          // tight white-hot center
const float INNER_GLOW_RADIUS = 0.012;    // bright blue
const float OUTER_GLOW_RADIUS = 0.035;    // diffuse blue
const float AMBIENT_RADIUS = 0.08;        // very subtle illumination

// Lightsaber colors
const vec3 CORE_COLOR = vec3(0.95, 0.97, 1.0);
const vec3 INNER_COLOR = vec3(0.3, 0.5, 1.0);
const vec3 OUTER_COLOR = vec3(0.08, 0.15, 0.7);
const vec3 AMBIENT_COLOR = vec3(0.03, 0.06, 0.25);

// --- CONSTANTS ---
const float PI = 3.14159265359;
const float C1_BACK = 1.70158;
const float C3_BACK = C1_BACK + 1.0;

// EaseOutCirc
float ease(float x) {
    float y = x - 1.0;
    return sqrt(1.0 - y * y);
}

float getSdfRectangle(in vec2 p, in vec2 xy, in vec2 b) {
    vec2 d = abs(p - xy) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float seg(in vec2 p, in vec2 a, in vec2 b, inout float s, float d) {
    vec2 e = b - a;
    vec2 w = p - a;
    vec2 proj = a + e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
    float segd = dot(p - proj, p - proj);
    d = min(d, segd);
    float c0 = step(0.0, p.y - a.y);
    float c1 = 1.0 - step(0.0, p.y - b.y);
    float c2 = 1.0 - step(0.0, e.x * w.y - e.y * w.x);
    float allCond = c0 * c1 * c2;
    float noneCond = (1.0 - c0) * (1.0 - c1) * (1.0 - c2);
    float flip = mix(1.0, -1.0, step(0.5, allCond + noneCond));
    s *= flip;
    return d;
}

float getSdfConvexQuad(in vec2 p, in vec2 v1, in vec2 v2, in vec2 v3, in vec2 v4) {
    float s = 1.0;
    float d = dot(p - v1, p - v1);
    d = seg(p, v1, v2, s, d);
    d = seg(p, v2, v3, s, d);
    d = seg(p, v3, v4, s, d);
    d = seg(p, v4, v1, s, d);
    return s * sqrt(d);
}

vec2 normalizeCoord(vec2 value, float isPosition) {
    return (value * 2.0 - (iResolution.xy * isPosition)) / iResolution.y;
}

// Determines animation duration based on corner alignment with move direction
float getDurationFromDot(float dot_val, float DURATION_LEAD, float DURATION_SIDE, float DURATION_TRAIL) {
    float isLead = step(0.5, dot_val);
    float isSide = step(-0.5, dot_val) * (1.0 - isLead);
    float duration = mix(DURATION_TRAIL, DURATION_SIDE, isSide);
    duration = mix(duration, DURATION_LEAD, isLead);
    return duration;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord.xy / iResolution.xy);

    // Detect whether the cursor is visible (normal shell) or hidden (TUI app).
    // When hidden, Ghostty reports cursor size as 0. The position data is
    // unreliable in that case — TUI apps whip the hidden cursor around during
    // redraws, producing garbage trails. So we only show a gentle idle glow.
    bool cursorVisible = iCurrentCursor.z > 0.0 && iCurrentCursor.w > 0.0;

    // No cursor data at all — nothing to render
    if (!cursorVisible && iCurrentCursor.x <= 0.0 && iCurrentCursor.y <= 0.0) return;

    // Normalized coordinates
    vec2 vu = normalizeCoord(fragCoord, 1.0);
    vec2 offsetFactor = vec2(-0.5, 0.5);

    vec4 currentCursor = vec4(normalizeCoord(iCurrentCursor.xy, 1.0), normalizeCoord(iCurrentCursor.zw, 0.0));
    vec4 previousCursor = vec4(normalizeCoord(iPreviousCursor.xy, 1.0), normalizeCoord(iPreviousCursor.zw, 0.0));

    // When cursor is hidden, use previous size for glow calculations
    if (!cursorVisible) {
        vec2 fallbackSize = normalizeCoord(vec2(max(iPreviousCursor.z, 8.0), max(iPreviousCursor.w, 16.0)), 0.0);
        currentCursor.zw = fallbackSize;
        previousCursor.zw = fallbackSize;
    }

    vec2 centerCC = currentCursor.xy - (currentCursor.zw * offsetFactor);
    vec2 halfSizeCC = currentCursor.zw * 0.5;
    vec2 centerCP = previousCursor.xy - (previousCursor.zw * offsetFactor);

    float sdfCurrentCursor = getSdfRectangle(vu, centerCC, halfSizeCC);

    float lineLength = distance(centerCC, centerCP);
    float minDist = currentCursor.w * THRESHOLD_MIN_DISTANCE;

    vec4 newColor = fragColor;
    float baseProgress = iTime - iTimeCursorChange;
    float timeSinceFocus = iTime - iTimeFocus;
    bool trailActive = cursorVisible && lineLength > minDist && baseProgress < DURATION - 0.001;
    bool focusActive = cursorVisible && iFocus > 0 && timeSinceFocus < FOCUS_LINE_DURATION;

    // --- CURSOR GLOW (fades when idle to prevent ghosts in unfocused panes) ---
    float cursorDist = abs(sdfCurrentCursor);

    // Fade glow after cursor has been idle (saber powers down)
    float timeSinceChange = iTime - iTimeCursorChange;
    float glowFade = 1.0 - smoothstep(GLOW_IDLE_TIMEOUT, GLOW_IDLE_TIMEOUT + GLOW_FADE_DURATION, timeSinceChange);

    // When cursor is hidden (TUI mode), dim the glow and fade faster
    // to avoid a bright blob chasing garbage positions
    float tuiDim = cursorVisible ? 1.0 : 0.35;
    float tuiFade = cursorVisible ? glowFade : glowFade * (1.0 - smoothstep(0.5, 1.5, timeSinceChange));

    // Most fragments are nowhere near the cursor or active trail. Bail before
    // the expensive pulse, glow, and quad SDF work.
    float cursorInfluence = AMBIENT_RADIUS * 1.5;
    if (!focusActive) {
        float trailPadding = AMBIENT_RADIUS + max(currentCursor.z, currentCursor.w);
        vec2 trailMin = min(centerCC, centerCP) - vec2(trailPadding);
        vec2 trailMax = max(centerCC, centerCP) + vec2(trailPadding);
        bool outsideTrailBounds = any(lessThan(vu, trailMin)) || any(greaterThan(vu, trailMax));

        if (cursorDist > cursorInfluence && (!trailActive || outsideTrailBounds)) {
            return;
        }
    }

    // Plasma pulse for that unstable lightsaber hum
    float pulse = 1.0 + 0.06 * sin(iTime * 20.0) + 0.03 * sin(iTime * 47.0);
    float flicker = 1.0 + 0.02 * sin(iTime * 97.0);

    // Glow layers around cursor
    float coreMask = smoothstep(CORE_RADIUS, 0.0, cursorDist) * pulse;
    float innerMask = smoothstep(INNER_GLOW_RADIUS, 0.0, cursorDist) * pulse * flicker;
    float outerMask = smoothstep(OUTER_GLOW_RADIUS, 0.0, cursorDist);
    float ambientMask = smoothstep(AMBIENT_RADIUS, 0.0, cursorDist);

    vec3 cursorGlow = CORE_COLOR * coreMask * 0.9
                    + INNER_COLOR * innerMask * 0.6
                    + OUTER_COLOR * outerMask * 0.3
                    + AMBIENT_COLOR * ambientMask * 0.15;

    newColor.rgb += cursorGlow * tuiFade * tuiDim;

    // --- FOCUS TRAIL (cursor "arrives" from farthest corner on window activation) ---
    // Reuses the same warp-style quad animation as the normal cursor trail,
    // with a synthetic previous position offset toward the farthest screen corner.
    if (focusActive) {
        // Virtual origin: offset cursor toward farthest screen corner
        float aspect = iResolution.x / iResolution.y;
        vec2 farCorner = vec2(
            centerCC.x < 0.0 ? aspect : -aspect,
            centerCC.y < 0.0 ? 1.0 : -1.0
        );
        vec2 arrivalDir = normalize(farCorner - centerCC);
        vec2 virtualPrev = centerCC + arrivalDir * FOCUS_LINE_LENGTH;

        // Current cursor corners (same geometry as trail)
        float fcc_half_h = currentCursor.w * 0.5 * TRAIL_THICKNESS;
        float fcc_cy = currentCursor.y - currentCursor.w * 0.5;
        float fcc_half_w = currentCursor.z * 0.5 * TRAIL_THICKNESS_X;
        float fcc_cx = currentCursor.x + currentCursor.z * 0.5;

        vec2 fcc_tl = vec2(fcc_cx - fcc_half_w, fcc_cy + fcc_half_h);
        vec2 fcc_tr = vec2(fcc_cx + fcc_half_w, fcc_cy + fcc_half_h);
        vec2 fcc_bl = vec2(fcc_cx - fcc_half_w, fcc_cy - fcc_half_h);
        vec2 fcc_br = vec2(fcc_cx + fcc_half_w, fcc_cy - fcc_half_h);

        // Virtual previous corners (same shape, offset to origin)
        vec2 offset = arrivalDir * FOCUS_LINE_LENGTH;
        vec2 fcp_tl = fcc_tl + offset;
        vec2 fcp_tr = fcc_tr + offset;
        vec2 fcp_bl = fcc_bl + offset;
        vec2 fcp_br = fcc_br + offset;

        // Per-corner warp animation (same logic as trail)
        float F_DUR_TRAIL = FOCUS_LINE_DURATION;
        float F_DUR_LEAD = FOCUS_LINE_DURATION * (1.0 - TRAIL_SIZE);
        float F_DUR_SIDE = (F_DUR_LEAD + F_DUR_TRAIL) / 2.0;

        vec2 fMoveVec = centerCC - virtualPrev;
        vec2 fs = sign(fMoveVec);

        float fdur_tl = getDurationFromDot(dot(vec2(-1.0, 1.0), fs), F_DUR_LEAD, F_DUR_SIDE, F_DUR_TRAIL);
        float fdur_tr = getDurationFromDot(dot(vec2(1.0, 1.0), fs), F_DUR_LEAD, F_DUR_SIDE, F_DUR_TRAIL);
        float fdur_bl = getDurationFromDot(dot(vec2(-1.0, -1.0), fs), F_DUR_LEAD, F_DUR_SIDE, F_DUR_TRAIL);
        float fdur_br = getDurationFromDot(dot(vec2(1.0, -1.0), fs), F_DUR_LEAD, F_DUR_SIDE, F_DUR_TRAIL);

        float fisRight = step(0.5, fs.x);
        float fisLeft = step(0.5, -fs.x);
        float fdur_right = getDurationFromDot((dot(vec2(1.0, 1.0), fs) + dot(vec2(1.0, -1.0), fs)) * 0.5, F_DUR_LEAD, F_DUR_SIDE, F_DUR_TRAIL);
        float fdur_left = getDurationFromDot((dot(vec2(-1.0, 1.0), fs) + dot(vec2(-1.0, -1.0), fs)) * 0.5, F_DUR_LEAD, F_DUR_SIDE, F_DUR_TRAIL);

        float fprog_tl = ease(clamp(timeSinceFocus / mix(fdur_tl, fdur_left, fisLeft), 0.0, 1.0));
        float fprog_tr = ease(clamp(timeSinceFocus / mix(fdur_tr, fdur_right, fisRight), 0.0, 1.0));
        float fprog_bl = ease(clamp(timeSinceFocus / mix(fdur_bl, fdur_left, fisLeft), 0.0, 1.0));
        float fprog_br = ease(clamp(timeSinceFocus / mix(fdur_br, fdur_right, fisRight), 0.0, 1.0));

        vec2 fv_tl = mix(fcp_tl, fcc_tl, fprog_tl);
        vec2 fv_tr = mix(fcp_tr, fcc_tr, fprog_tr);
        vec2 fv_br = mix(fcp_br, fcc_br, fprog_br);
        vec2 fv_bl = mix(fcp_bl, fcc_bl, fprog_bl);

        // Trail shape SDF + lightsaber glow (same rendering as normal trail)
        float fSdf = getSdfConvexQuad(vu, fv_tl, fv_tr, fv_br, fv_bl);

        float fFadeProg = clamp(dot(vu - virtualPrev, fMoveVec) / (dot(fMoveVec, fMoveVec) + 1e-6), 0.0, 1.0);
        float fFadeMask = fFadeProg * fFadeProg;

        float fTrailDist = max(fSdf, 0.0);
        float fInside = step(fSdf, 0.0);

        vec3 fGlow = vec3(0.0);
        fGlow += mix(INNER_COLOR, CORE_COLOR, 0.7) * pulse * fInside * 0.85;
        fGlow += CORE_COLOR * smoothstep(CORE_RADIUS * 1.5, 0.0, fTrailDist) * pulse * (1.0 - fInside) * 0.7;
        fGlow += INNER_COLOR * smoothstep(INNER_GLOW_RADIUS * 1.2, 0.0, fTrailDist) * pulse * flicker * (1.0 - fInside) * 0.5;
        fGlow += OUTER_COLOR * smoothstep(OUTER_GLOW_RADIUS, 0.0, fTrailDist) * 0.3;
        fGlow += AMBIENT_COLOR * smoothstep(AMBIENT_RADIUS * 0.7, 0.0, fTrailDist) * 0.15;
        fGlow *= mix(0.3, 1.0, fFadeMask);

        float fShimmer = sin(fFadeProg * 40.0 + iTime * 25.0) * 0.5 + 0.5;
        fShimmer *= sin(fFadeProg * 23.0 - iTime * 18.0) * 0.5 + 0.5;
        fGlow += INNER_COLOR * fShimmer * fInside * 0.1;

        newColor.rgb += fGlow;
        newColor = mix(newColor, fragColor, step(sdfCurrentCursor, 0.0));
    }

    // --- TRAIL (only when cursor is visible — skip in TUI mode) ---
    if (trailActive) {
        // Define corners of current cursor
        float cc_half_height = currentCursor.w * 0.5;
        float cc_center_y = currentCursor.y - cc_half_height;
        float cc_new_half_height = cc_half_height * TRAIL_THICKNESS;
        float cc_new_top_y = cc_center_y + cc_new_half_height;
        float cc_new_bottom_y = cc_center_y - cc_new_half_height;

        float cc_half_width = currentCursor.z * 0.5;
        float cc_center_x = currentCursor.x + cc_half_width;
        float cc_new_half_width = cc_half_width * TRAIL_THICKNESS_X;
        float cc_new_left_x = cc_center_x - cc_new_half_width;
        float cc_new_right_x = cc_center_x + cc_new_half_width;

        vec2 cc_tl = vec2(cc_new_left_x, cc_new_top_y);
        vec2 cc_tr = vec2(cc_new_right_x, cc_new_top_y);
        vec2 cc_bl = vec2(cc_new_left_x, cc_new_bottom_y);
        vec2 cc_br = vec2(cc_new_right_x, cc_new_bottom_y);

        // Define corners of previous cursor
        float cp_half_height = previousCursor.w * 0.5;
        float cp_center_y = previousCursor.y - cp_half_height;
        float cp_new_half_height = cp_half_height * TRAIL_THICKNESS;
        float cp_new_top_y = cp_center_y + cp_new_half_height;
        float cp_new_bottom_y = cp_center_y - cp_new_half_height;

        float cp_half_width = previousCursor.z * 0.5;
        float cp_center_x = previousCursor.x + cp_half_width;
        float cp_new_half_width = cp_half_width * TRAIL_THICKNESS_X;
        float cp_new_left_x = cp_center_x - cp_new_half_width;
        float cp_new_right_x = cp_center_x + cp_new_half_width;

        vec2 cp_tl = vec2(cp_new_left_x, cp_new_top_y);
        vec2 cp_tr = vec2(cp_new_right_x, cp_new_top_y);
        vec2 cp_bl = vec2(cp_new_left_x, cp_new_bottom_y);
        vec2 cp_br = vec2(cp_new_right_x, cp_new_bottom_y);

        // Per-corner animation durations (warp-style)
        const float DURATION_TRAIL = DURATION;
        const float DURATION_LEAD = DURATION * (1.0 - TRAIL_SIZE);
        const float DURATION_SIDE = (DURATION_LEAD + DURATION_TRAIL) / 2.0;

        vec2 moveVec = centerCC - centerCP;
        vec2 s = sign(moveVec);

        float dot_tl = dot(vec2(-1.0, 1.0), s);
        float dot_tr = dot(vec2(1.0, 1.0), s);
        float dot_bl = dot(vec2(-1.0, -1.0), s);
        float dot_br = dot(vec2(1.0, -1.0), s);

        float dur_tl = getDurationFromDot(dot_tl, DURATION_LEAD, DURATION_SIDE, DURATION_TRAIL);
        float dur_tr = getDurationFromDot(dot_tr, DURATION_LEAD, DURATION_SIDE, DURATION_TRAIL);
        float dur_bl = getDurationFromDot(dot_bl, DURATION_LEAD, DURATION_SIDE, DURATION_TRAIL);
        float dur_br = getDurationFromDot(dot_br, DURATION_LEAD, DURATION_SIDE, DURATION_TRAIL);

        float isMovingRight = step(0.5, s.x);
        float isMovingLeft = step(0.5, -s.x);

        float dot_right_edge = (dot_tr + dot_br) * 0.5;
        float dur_right_rail = getDurationFromDot(dot_right_edge, DURATION_LEAD, DURATION_SIDE, DURATION_TRAIL);
        float dot_left_edge = (dot_tl + dot_bl) * 0.5;
        float dur_left_rail = getDurationFromDot(dot_left_edge, DURATION_LEAD, DURATION_SIDE, DURATION_TRAIL);

        float final_dur_tl = mix(dur_tl, dur_left_rail, isMovingLeft);
        float final_dur_bl = mix(dur_bl, dur_left_rail, isMovingLeft);
        float final_dur_tr = mix(dur_tr, dur_right_rail, isMovingRight);
        float final_dur_br = mix(dur_br, dur_right_rail, isMovingRight);

        float prog_tl = ease(clamp(baseProgress / final_dur_tl, 0.0, 1.0));
        float prog_tr = ease(clamp(baseProgress / final_dur_tr, 0.0, 1.0));
        float prog_bl = ease(clamp(baseProgress / final_dur_bl, 0.0, 1.0));
        float prog_br = ease(clamp(baseProgress / final_dur_br, 0.0, 1.0));

        vec2 v_tl = mix(cp_tl, cc_tl, prog_tl);
        vec2 v_tr = mix(cp_tr, cc_tr, prog_tr);
        vec2 v_br = mix(cp_br, cc_br, prog_br);
        vec2 v_bl = mix(cp_bl, cc_bl, prog_bl);

        // Trail shape SDF
        float sdfTrail = getSdfConvexQuad(vu, v_tl, v_tr, v_br, v_bl);

        // --- LIGHTSABER GLOW ON THE TRAIL ---
        // Fade gradient: 0 at tail, 1 at head
        float fadeProgress = clamp(dot(vu - centerCP, moveVec) / (dot(moveVec, moveVec) + 1e-6), 0.0, 1.0);
        float fadeMask = fadeProgress * fadeProgress;

        // Trail glow layers based on distance from trail shape
        float trailDist = max(sdfTrail, 0.0);

        float trailCore = smoothstep(CORE_RADIUS * 1.5, 0.0, trailDist) * pulse;
        float trailInner = smoothstep(INNER_GLOW_RADIUS * 1.2, 0.0, trailDist) * pulse * flicker;
        float trailOuter = smoothstep(OUTER_GLOW_RADIUS, 0.0, trailDist);
        float trailAmbient = smoothstep(AMBIENT_RADIUS * 0.7, 0.0, trailDist);

        // Inside the trail shape (sdfTrail < 0), full brightness
        float insideTrail = step(sdfTrail, 0.0);

        // Combine: inside = solid saber color, outside = glow falloff
        vec3 trailGlow = vec3(0.0);

        // Solid core inside the trail shape
        vec3 saberCore = mix(INNER_COLOR, CORE_COLOR, 0.7) * pulse;
        trailGlow += saberCore * insideTrail * 0.85;

        // Glow halo around the trail
        trailGlow += CORE_COLOR * trailCore * (1.0 - insideTrail) * 0.7;
        trailGlow += INNER_COLOR * trailInner * (1.0 - insideTrail) * 0.5;
        trailGlow += OUTER_COLOR * trailOuter * 0.3;
        trailGlow += AMBIENT_COLOR * trailAmbient * 0.15;

        // Apply fade (brighter at head, dimmer at tail)
        trailGlow *= mix(0.3, 1.0, fadeMask);

        // Edge shimmer for unstable plasma
        float shimmer = sin(fadeProgress * 40.0 + iTime * 25.0) * 0.5 + 0.5;
        shimmer *= sin(fadeProgress * 23.0 - iTime * 18.0) * 0.5 + 0.5;
        trailGlow += INNER_COLOR * shimmer * insideTrail * 0.1;

        newColor.rgb += trailGlow;

        // Punch hole so the actual cursor renders on top
        newColor = mix(newColor, fragColor, step(sdfCurrentCursor, 0.0));
    }

    // Subtle blue tint on nearby terminal text (ambient light from saber)
    float textProximity = smoothstep(AMBIENT_RADIUS * 1.5, 0.0, cursorDist);
    newColor.rgb = mix(newColor.rgb, newColor.rgb * vec3(0.92, 0.95, 1.1), textProximity * 0.1 * tuiFade);

    fragColor = newColor;
}
