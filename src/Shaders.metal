/*
 * BeebEm macOS Metal shaders
 * Full-screen textured quad with optional CRT scanline darkening.
 */

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Fullscreen triangle-strip quad: two triangles covering clip space.
vertex VertexOut beeb_vertex(uint vid [[vertex_id]])
{
    // Positions cover NDC [-1,1] x [-1,1].
    const float2 positions[4] = {
        float2(-1.0,  1.0),
        float2( 1.0,  1.0),
        float2(-1.0, -1.0),
        float2( 1.0, -1.0)
    };
    // UV: flip Y so row 0 of the texture is at the top.
    const float2 uvs[4] = {
        float2(0.0, 0.0),
        float2(1.0, 0.0),
        float2(0.0, 1.0),
        float2(1.0, 1.0)
    };

    VertexOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.texCoord = uvs[vid];
    return out;
}

fragment float4 beeb_fragment(VertexOut in           [[stage_in]],
                              texture2d<float> tex   [[texture(0)]],
                              constant bool &scanlines [[buffer(0)]])
{
    constexpr sampler s(filter::nearest);
    float4 colour = tex.sample(s, in.texCoord);

    // Simple scanline effect: darken even rows.
    if (scanlines) {
        uint row = uint(in.position.y);
        if ((row & 1u) == 0u) {
            colour.rgb *= 0.6;
        }
    }

    return colour;
}
