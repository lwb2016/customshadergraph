#ifndef SG_SHADOW_PASS_INCLUDED
#define SG_SHADOW_PASS_INCLUDED

PackedVaryings vert(Attributes input)
{
    Varyings output = (Varyings)0;
    output = BuildVaryings(input);
    VertexDescription vertexDescription = BuildVertexDescription(input);
    PackedVaryings packedOutput = (PackedVaryings)0;
    packedOutput = PackVaryings(output);
    return packedOutput;
}

const float DITHER_THRESHOLDS[16] =
{
    1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
    13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
    4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
    16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
};

float Dither32(float2 Pos) {
    float Ret = dot( float3(Pos.xy, 0.5f), float3(0.40625f, 0.15625f, 0.46875f ) );
    return frac(Ret);
}

float4 Unity_Dither_float4(float2 ScreenPosition)
{
    float2 uv = ScreenPosition.xy * _ScreenParams.xy;
    uint index = (uint(uv.x) % 4) * 4 + uint(uv.y) % 4;
    return 1 - DITHER_THRESHOLDS[index];
}

float Dither8x8Bayer(float2 screenPos)
{
    const float dither[64] = {
        1.0, 49.0, 13.0, 61.0, 4.0, 52.0, 16.0, 64.0,
        33.0, 17.0, 45.0, 29.0, 36.0, 20.0, 48.0, 32.0,
        9.0, 57.0, 5.0, 53.0, 12.0, 60.0, 8.0, 56.0,
        41.0, 25.0, 37.0, 21.0, 44.0, 28.0, 40.0, 24.0,
        3.0, 51.0, 15.0, 63.0, 2.0, 50.0, 14.0, 62.0,
        35.0, 19.0, 47.0, 31.0, 34.0, 18.0, 46.0, 30.0,
        11.0, 59.0, 7.0, 55.0, 10.0, 58.0, 6.0, 54.0,
        43.0, 27.0, 39.0, 23.0, 42.0, 26.0, 38.0, 22.0
    };
    int r = fmod(screenPos.x, 8) * 8 + fmod(screenPos.y, 8);
    return 1.0 / dither[r];
}

inline float InterleavedGradientNoise(float2 screenPos) {
    // http://www.iryoku.com/downloads/Next-Generation-Post-Processing-in-Call-of-Duty-Advanced-Warfare-v18.pptx (slide 123)
    float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
    return frac(magic.z * frac(dot(screenPos, magic.xy)));
}

float transparencyClip(float2 screenPos)
{
    float4x4 thresholdMatrix16 =
    { 1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
        13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
        4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
        16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
    };
    
    return thresholdMatrix16[fmod(screenPos.x, 4)][fmod(screenPos.y, 4)];
}

half4 frag(PackedVaryings packedInput) : SV_TARGET
{
    Varyings unpacked = UnpackVaryings(packedInput);
    UNITY_SETUP_INSTANCE_ID(unpacked);
    SurfaceDescription surfaceDescription = BuildSurfaceDescription(unpacked);

    #if _ALPHATEST_ON
        #if _TRANSPARENTSHADOW
            surfaceDescription.AlphaClipThreshold = transparencyClip(unpacked.positionCS.xy / (unpacked.positionCS.w));
        #endif
        clip(surfaceDescription.Alpha - surfaceDescription.AlphaClipThreshold);
    #endif

    #if defined(LOD_FADE_CROSSFADE) && USE_UNITY_CROSSFADE
        LODFadeCrossFade(unpacked.positionCS);
    #endif

    return 0;
}


#endif
