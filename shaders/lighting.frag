#version 460 core

precision mediump float;

#include <flutter/runtime_effect.glsl>

// Uniforms
uniform vec2 uSize;            // Canvas size (float index 0,1)
uniform vec2 uLight1Pos;       // Light 1 position 0.0~1.0 (float index 2,3)
uniform float uLightRadius;    // Light reach radius (float index 4)
uniform float uAmbient;        // Ambient light strength (float index 5)
uniform float uLight1Intensity;// Light 1 intensity (float index 6)
uniform vec3 uLightColor;      // Light color RGB (float index 7,8,9)
uniform vec2 uLight2Pos;       // Light 2 position (float index 10,11)
uniform float uLight2Intensity;// Light 2 intensity (float index 12)
uniform vec2 uLight3Pos;       // Light 3 position (float index 13,14)
uniform float uLight3Intensity;// Light 3 intensity (float index 15)
uniform float uFlicker;        // Flicker multiplier (float index 16)
uniform float uFrameShadow;    // Frame shadow enable (float index 17)
uniform float uNumLights;      // Number of active lights (float index 18)
uniform sampler2D uTexture;    // Painting texture (sampler index 0)

out vec4 fragColor;

// Calculate light attenuation at a point
float calcLight(vec2 uv, vec2 lightPos, float radius) {
    vec2 dir = uv - lightPos;
    dir.x *= uSize.x / uSize.y; // Aspect ratio correction
    float dist = length(dir);
    return 1.0 - smoothstep(0.0, radius, dist);
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uSize;

    // Sample texture color
    vec4 texColor = texture(uTexture, uv);

    // Light 1 (always active)
    float att1 = calcLight(uv, uLight1Pos, uLightRadius);
    float light1 = uLight1Intensity * att1 * uFlicker;
    float specular = pow(att1, 4.0) * 0.15 * uFlicker;

    // Light 2
    float light2 = 0.0;
    if (uNumLights > 1.5) {
        float att2 = calcLight(uv, uLight2Pos, uLightRadius);
        light2 = uLight2Intensity * att2 * uFlicker;
        specular += pow(att2, 4.0) * 0.10 * uFlicker;
    }

    // Light 3
    float light3 = 0.0;
    if (uNumLights > 2.5) {
        float att3 = calcLight(uv, uLight3Pos, uLightRadius);
        light3 = uLight3Intensity * att3 * uFlicker;
        specular += pow(att3, 4.0) * 0.10 * uFlicker;
    }

    // Final brightness = ambient + all lights
    float brightness = uAmbient + light1 + light2 + light3;

    // Apply light color
    vec3 litColor = texColor.rgb * brightness * uLightColor;

    // Add specular highlights
    litColor += specular * uLightColor;

    // Frame inner shadow: deep shadows cast by the frame onto the painting
    if (uFrameShadow > 0.5) {
        float shadowDepth = 0.15;
        float maxDarken = 0.85;

        vec2 lightOffset = uLight1Pos - vec2(0.5, 0.5);

        // Directional shadows from frame edges
        float leftShadow   = pow(smoothstep(shadowDepth, 0.0, uv.x), 1.5)         * max(0.0, -lightOffset.x) * 2.5;
        float rightShadow  = pow(smoothstep(1.0 - shadowDepth, 1.0, uv.x), 1.5)   * max(0.0,  lightOffset.x) * 2.5;
        float topShadow    = pow(smoothstep(shadowDepth, 0.0, uv.y), 1.5)         * max(0.0, -lightOffset.y) * 2.5;
        float bottomShadow = pow(smoothstep(1.0 - shadowDepth, 1.0, uv.y), 1.5)   * max(0.0,  lightOffset.y) * 2.5;

        // Always-present subtle ambient shadow at all edges (frame depth)
        float ambientEdge = 0.0;
        ambientEdge += pow(smoothstep(0.04, 0.0, uv.x), 2.0) * 0.4;
        ambientEdge += pow(smoothstep(0.96, 1.0, uv.x), 2.0) * 0.4;
        ambientEdge += pow(smoothstep(0.04, 0.0, uv.y), 2.0) * 0.4;
        ambientEdge += pow(smoothstep(0.96, 1.0, uv.y), 2.0) * 0.4;

        // Corner shadows (deeper in corners)
        float cornerTL = pow(smoothstep(shadowDepth * 1.6, 0.0, length(uv)), 2.0)
                        * max(0.0, -lightOffset.x) * max(0.0, -lightOffset.y) * 4.0;
        float cornerTR = pow(smoothstep(shadowDepth * 1.6, 0.0, length(uv - vec2(1.0, 0.0))), 2.0)
                        * max(0.0,  lightOffset.x) * max(0.0, -lightOffset.y) * 4.0;
        float cornerBL = pow(smoothstep(shadowDepth * 1.6, 0.0, length(uv - vec2(0.0, 1.0))), 2.0)
                        * max(0.0, -lightOffset.x) * max(0.0,  lightOffset.y) * 4.0;
        float cornerBR = pow(smoothstep(shadowDepth * 1.6, 0.0, length(uv - vec2(1.0))), 2.0)
                        * max(0.0,  lightOffset.x) * max(0.0,  lightOffset.y) * 4.0;

        float totalShadow = leftShadow + rightShadow + topShadow + bottomShadow
                           + cornerTL + cornerTR + cornerBL + cornerBR + ambientEdge;
        totalShadow = min(totalShadow, 1.0);

        litColor *= (1.0 - totalShadow * maxDarken);
    }

    fragColor = vec4(litColor, texColor.a);
}
