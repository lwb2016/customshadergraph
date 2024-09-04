#ifndef UNIVERSAL_NPR_SURFACE_DATA_INCLUDED
#define UNIVERSAL_NPR_SURFACE_DATA_INCLUDED

// Must match Universal ShaderGraph master node
struct FernSurfaceData
{
    float3 albedo;
    float3 specular;
    float3 normalTS;
    float3 emission;
    float3 coatTint;
    
    float  metallic;
    float  smoothness;
    float  occlusion;
    float  alpha;
    float  clearCoatMask;
    float  clearCoatSmoothness;
    float  diffuseID;
    float  innerLine;
    
    #if EYE
        float3 corneaNormalData;
        float3 irisNormalData;
        float  parallax;
    #endif
};



struct AnisoSpecularData
{
    float3 specularColor;
    float3 specularSecondaryColor;
    float specularShift;
    float specularSecondaryShift;
    float specularStrength;
    float specularSecondaryStrength;
    float specularExponent;
    float specularSecondaryExponent;
    float spread1;
    float spread2;
};

struct AngleRingSpecularData
{
    float3 shadowColor;
    float3 brightColor;
    float mask;
    float width;
    float softness;
    float threshold;
    float intensity;
};

#endif
