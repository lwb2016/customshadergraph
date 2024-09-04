#ifndef UNIVERSAL_FURPLIGHTINGCOMMON_INCLUDED
#define UNIVERSAL_FURPLIGHTINGCOMMON_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl"

float4x4 _AreaLightVerts[MAX_VISIBLE_LIGHTS];
float4 _AreaLightColor[MAX_VISIBLE_LIGHTS];
half _AreaLightData[MAX_VISIBLE_LIGHTS];
float3 _AreaLightsForward[MAX_VISIBLE_LIGHTS];

struct Light_Area
{
    float4x4 LightVerts; // colume3: Size.x, Size.y, Range， Angle
    float4 LightColor;
    float4 positionWS;
    float3 Forward;
    float AreaLightData; // X: Area Type, Y: Range
};

Light GetFernAdditionalLight(uint i, float3 positionWS, half4 shadowMask)
{
    #if USE_FORWARD_PLUS
        int lightIndex = i;
    #else
        int lightIndex = GetPerObjectLightIndex(i);
    #endif

    Light light = GetAdditionalPerObjectLight(lightIndex, positionWS);

    #if USE_STRUCTURED_BUFFER_FOR_LIGHT_DATA
        half4 occlusionProbeChannels = _AdditionalLightsBuffer[lightIndex].occlusionProbeChannels;
    #else
        half4 occlusionProbeChannels = _AdditionalLightsOcclusionProbes[lightIndex];
    #endif

    light.shadowAttenuation = AdditionalLightShadow(lightIndex, positionWS, light.direction, shadowMask, occlusionProbeChannels);

    #if defined(_LIGHT_COOKIES)
        real3 cookieColor = SampleAdditionalLightCookie(lightIndex, positionWS);
        light.color *= cookieColor;
    #endif

    return light;
}

Light GetFernAdditionalLight(uint i, InputData inputData, half4 shadowMask, AmbientOcclusionFactor aoFactor, out Light_Area light_Area)
{
    Light light = GetFernAdditionalLight(i, inputData.positionWS, shadowMask);
    light_Area.AreaLightData = _AreaLightData[i];
    light_Area.LightVerts = _AreaLightVerts[i];
    light_Area.LightColor = _AreaLightColor[i];
    light_Area.positionWS = _AdditionalLightsPosition[i];
    light_Area.Forward = _AreaLightsForward[i];
    
    #if defined(_SCREEN_SPACE_OCCLUSION) && !defined(_SURFACE_TYPE_TRANSPARENT)
        if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_AMBIENT_OCCLUSION))
        {
            light.color *= aoFactor.directAmbientOcclusion;
            light_Area.LightColor *= aoFactor.directAmbientOcclusion;
        }
    #endif

    return light;
}


real SmoothDistanceWindowing_FRP(real distSquare, real rangeAttenuationScale, real rangeAttenuationBias)
{
    real factor = DistanceWindowing(distSquare, rangeAttenuationScale, rangeAttenuationBias);
    return factor;
    return Sq(factor);
}

real EllipsoidalDistanceAttenuation_FRP(real3 unL, real3 invHalfDim,
                                    real rangeAttenuationScale, real rangeAttenuationBias)
{
    // Transform the light vector so that we can work with
    // with the ellipsoid as if it was a unit sphere.
    unL *= invHalfDim;

    real sqDist = dot(unL, unL);

    return SmoothDistanceWindowing_FRP(sqDist, rangeAttenuationScale, rangeAttenuationBias);
}


#endif