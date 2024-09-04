#ifndef UNIVERSAL_NPR_BSDF_INCLUDED
#define UNIVERSAL_NPR_BSDF_INCLUDED

#define Pow2(x) x*x
#define Pow5(x) x*x*x*x*x

struct LitProBRDFData
{
    half3 albedo;
    half3 diffuse;
    half3 specular;
    half3 transmittance;
    #if _ANISO
        float3 tangentWS;
        float3 bitangentWS;
    #endif
    half reflectivity;
    half perceptualRoughness;
    half roughness;
    half roughness2;
    half grazingTerm;

    // We save some light invariant BRDF terms so we don't have to recompute
    // them in the light loop. Take a look at DirectBRDF function for detailed explaination.
    half normalizationTerm;     // roughness * 4.0 + 2.0
    half roughness2MinusOne;    // roughness^2 - 1.0
    #if _ANISO
        float roughnessT;
        float roughnessB;
        float anisotropy;
    #endif
};

#if _ANISO
void LitProFillMaterialAnisotropy(float anisotropy, float3 tangentWS, float3 bitangentWS, inout LitProBRDFData brdfData)
{
    brdfData.anisotropy = anisotropy;
    brdfData.tangentWS = tangentWS;
    brdfData.bitangentWS = bitangentWS;
}
#endif

// Convert a roughness and an anisotropy factor into GGX alpha values respectively for the major and minor axis of the tangent frame
void GetAnisotropicRoughness(float Alpha, float Anisotropy, out float ax, out float ay)
{
    // Anisotropic parameters: ax and ay are the roughness along the tangent and bitangent	
    // Kulla 2017, "Revisiting Physically Based Shading at Imageworks"
    ax = max(Alpha * (1.0 + Anisotropy), 0.001f);
    ay = max(Alpha * (1.0 - Anisotropy), 0.001f);
}

// [Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"]
float Vis_SmithJointAniso(float ax, float ay, float NoV, float NoL, float XoV, float XoL, float YoV, float YoL)
{
    float Vis_SmithV = NoL * length(float3(ax * XoV, ay * YoV, NoV));
    float Vis_SmithL = NoV * length(float3(ax * XoL, ay * YoL, NoL));
    return 0.5 * rcp(Vis_SmithV + Vis_SmithL);
}

// Anisotropic GGX
// [Burley 2012, "Physically-Based Shading at Disney"]
float D_GGXaniso( float ax, float ay, float NoH, float XoH, float YoH )
{
    // The two formulations are mathematically equivalent
    float a2 = ax * ay;
    float3 V = float3(ay * XoH, ax * YoH, a2 * NoH);
    float S = dot(V, V);
    return (1.0f / PI) * a2 * Pow2(a2 / S);
}

// [Schlick 1994, "An Inexpensive BRDF Model for Physically-Based Rendering"]
float3 F_SchlickAniso( float3 SpecularColor, float VoH )
{
    float Fc = Pow5( 1 - VoH );					// 1 sub, 3 mul
    //return Fc + (1 - Fc) * SpecularColor;		// 1 add, 3 mad
	
    // Anything less than 2% is physically impossible and is instead considered to be shadowing
    return saturate( 50.0 * SpecularColor.g ) * Fc + (1 - Fc) * SpecularColor;
}

// Initialize BRDFData for material, managing both specular and metallic setup using shader keyword _SPECULAR_SETUP.
inline void InitializeLitProBRDFData(FernSurfaceData surfaceData, inout half alpha, float3 normalWS, float3 tangentWS, float anisotropy, out LitProBRDFData outBRDFData)
{
    ZERO_INITIALIZE(LitProBRDFData, outBRDFData);

    #ifdef _SPECULAR_SETUP
        half reflectivity = ReflectivitySpecular(surfaceData.specular);
        half oneMinusReflectivity = half(1.0) - reflectivity;
        half3 brdfDiffuse = surfaceData.albedo * oneMinusReflectivity;
        half3 brdfSpecular = surfaceData.specular;
    #else
        half oneMinusReflectivity = OneMinusReflectivityMetallic(surfaceData.metallic);
        half reflectivity = half(1.0) - oneMinusReflectivity;
        half3 brdfDiffuse = surfaceData.albedo * oneMinusReflectivity;
        half3 brdfSpecular = lerp(kDieletricSpec.rgb, surfaceData.albedo, surfaceData.metallic);
    #endif

    outBRDFData = (LitProBRDFData)0;
    outBRDFData.albedo = surfaceData.albedo;
    outBRDFData.diffuse = brdfDiffuse;
    outBRDFData.specular = brdfSpecular;
    outBRDFData.reflectivity = reflectivity;

    outBRDFData.perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(surfaceData.smoothness);
    outBRDFData.roughness           = max(PerceptualRoughnessToRoughness(outBRDFData.perceptualRoughness), HALF_MIN_SQRT);
    outBRDFData.roughness2          = max(outBRDFData.roughness * outBRDFData.roughness, HALF_MIN);
    outBRDFData.grazingTerm         = saturate(surfaceData.smoothness + reflectivity);
    outBRDFData.normalizationTerm   = outBRDFData.roughness * half(4.0) + half(2.0);
    outBRDFData.roughness2MinusOne  = outBRDFData.roughness2 - half(1.0);

    // Input is expected to be non-alpha-premultiplied while ROP is set to pre-multiplied blend.
    // We use input color for specular, but (pre-)multiply the diffuse with alpha to complete the standard alpha blend equation.
    // In shader: Cs' = Cs * As, in ROP: Cs' + Cd(1-As);
    // i.e. we only alpha blend the diffuse part to background (transmittance).
    #if defined(_ALPHAPREMULTIPLY_ON)
        // TODO: would be clearer to multiply this once to accumulated diffuse lighting at end instead of the surface property.
        outBRDFData.diffuse *= alpha;
    #endif
    #if _ANISO
        GetAnisotropicRoughness(outBRDFData.roughness2, anisotropy, outBRDFData.roughnessT, outBRDFData.roughnessB);
        //ConvertAnisotropyToClampRoughness(outBRDFData.perceptualRoughness, anisotropy, outBRDFData.roughnessT, outBRDFData.roughnessB);
        half iblPerceptualRoughness = outBRDFData.perceptualRoughness * saturate(1.2 - abs(anisotropy));
        //  Override perceptual roughness for ambient specular reflections
        outBRDFData.perceptualRoughness = iblPerceptualRoughness;
        LitProFillMaterialAnisotropy(anisotropy, tangentWS, normalize(cross(normalWS, tangentWS)), outBRDFData);
    #endif

}

inline void InitializeBRDFDataClearCoat_Custom(half3 coatTint, half clearCoatMask, half clearCoatSmoothness, inout LitProBRDFData baseBRDFData, out LitProBRDFData outBRDFData)
{
    outBRDFData = (LitProBRDFData)0;
    outBRDFData.albedo = half(1.0);

    // Calculate Roughness of Clear Coat layer
    outBRDFData.diffuse             = kDielectricSpec.aaa * coatTint; // 1 - kDielectricSpec
    outBRDFData.specular            = lerp(kDielectricSpec.rgb, kDielectricSpec.rgb * coatTint, clearCoatMask);
    //outBRDFData.specular            = lerp(kDielectricSpec.rgb, kDielectricSpec.rgb, clearCoatMask);
    outBRDFData.reflectivity        = kDielectricSpec.r;

    outBRDFData.perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(clearCoatSmoothness);
    outBRDFData.roughness           = max(PerceptualRoughnessToRoughness(outBRDFData.perceptualRoughness), HALF_MIN_SQRT);
    outBRDFData.roughness2          = max(outBRDFData.roughness * outBRDFData.roughness, HALF_MIN);
    outBRDFData.normalizationTerm   = outBRDFData.roughness * half(4.0) + half(2.0);
    outBRDFData.roughness2MinusOne  = outBRDFData.roughness2 - half(1.0);
    outBRDFData.grazingTerm         = saturate(clearCoatSmoothness + kDielectricSpec.x);

    // Modify Roughness of base layer using coat IOR
    half ieta                        = lerp(1.0h, CLEAR_COAT_IETA, clearCoatMask);
    half coatRoughnessScale          = Sq(ieta);
    half sigma                       = RoughnessToVariance(PerceptualRoughnessToRoughness(baseBRDFData.perceptualRoughness));

    baseBRDFData.perceptualRoughness = RoughnessToPerceptualRoughness(VarianceToRoughness(sigma * coatRoughnessScale));

    // Recompute base material for new roughness, previous computation should be eliminated by the compiler (as it's unused)
    baseBRDFData.roughness          = max(PerceptualRoughnessToRoughness(baseBRDFData.perceptualRoughness), HALF_MIN_SQRT);
    baseBRDFData.roughness2         = max(baseBRDFData.roughness * baseBRDFData.roughness, HALF_MIN);
    baseBRDFData.normalizationTerm  = baseBRDFData.roughness * 4.0h + 2.0h;
    baseBRDFData.roughness2MinusOne = baseBRDFData.roughness2 - 1.0h;

    // Darken/saturate base layer using coat to surface reflectance (vs. air to surface)
    baseBRDFData.specular = lerp(baseBRDFData.specular, ConvertF0ForClearCoat15(baseBRDFData.specular), clearCoatMask);
    // TODO: what about diffuse? at least in specular workflow diffuse should be recalculated as it directly depends on it.
}

LitProBRDFData CreateNPRClearCoatBRDFData(FernSurfaceData surfaceData, inout LitProBRDFData brdfData)
{
    LitProBRDFData brdfDataClearCoat = (LitProBRDFData)0;

    #if _CLEARCOAT
        // base brdfData is modified here, rely on the compiler to eliminate dead computation by InitializeBRDFData()
        InitializeBRDFDataClearCoat_Custom(surfaceData.coatTint, surfaceData.clearCoatMask, surfaceData.clearCoatSmoothness, brdfData, brdfDataClearCoat);
    #endif

    return brdfDataClearCoat;
}

void FernInitializeBRDFData(FernSurfaceData surfaceData, float3 normalWS, float3 tangentWS, float anisotropy, out LitProBRDFData outBRDFData, out LitProBRDFData outClearBRDFData)
{
    InitializeLitProBRDFData(surfaceData, surfaceData.alpha, normalWS, tangentWS, anisotropy, outBRDFData);
    outClearBRDFData = outBRDFData;
    #if _CLEARCOAT
        outClearBRDFData = CreateNPRClearCoatBRDFData(surfaceData, outBRDFData);
    #endif
}

///////////////////////////////////////////////////////////////////////////////
//                            Fabric BRDF                                    //
///////////////////////////////////////////////////////////////////////////////

// TODO: should be use BSDF
struct FabricBSDFData
{
    uint materialFeatures;
    float3 diffuseColor;
    float3 fresnel0;
    float ambientOcclusion;
    float specularOcclusion;
    float3 normalWS;
    float3 geomNormalWS;
    float perceptualRoughness;
    uint diffusionProfileIndex;
    float subsurfaceMask;
    float thickness;
    bool useThickObjectMode;
    float3 transmittance;
    float3 tangentWS;
    float3 bitangentWS;
    float roughnessT;
    float roughnessB;
    float anisotropy;
};

struct FabricBRDFData
{
    half3 albedo;
    half3 diffuse;
    half3 specular;
    half3 tangentWS;
    half3 bitangentWS;
    half reflectivity;
    half perceptualRoughness;
    half roughness;
    half roughness2;
    half roughnessT;
    half roughnessB;
    #if _FABRIC_SILK
        float anisotropy;
    #endif
    
    half grazingTerm;
    // We save some light invariant BRDF terms so we don't have to recompute
    // them in the light loop. Take a look at DirectBRDF function for detailed explaination.
    half normalizationTerm;     // roughness * 4.0 + 2.0
    half roughness2MinusOne;    // roughness^2 - 1.0
};

// Assume bsdfData.normalWS is init
#if _FABRIC_SILK
void FillMaterialAnisotropy(float anisotropy, float3 tangentWS, float3 bitangentWS, inout FabricBRDFData brdfData)
{
    brdfData.anisotropy = anisotropy;
    brdfData.tangentWS = tangentWS;
    brdfData.bitangentWS = bitangentWS;
}
#endif

void InitializeFabricBRDFData(FernSurfaceData surfaceData, float anisotropy, float3 normalWS, float3 tangentWS, out FabricBRDFData outBRDFData)
{
    ZERO_INITIALIZE(FabricBRDFData, outBRDFData);
    
    half reflectivity = ReflectivitySpecular(surfaceData.specular);
    half oneMinusReflectivity = half(1.0) - reflectivity;
    half3 brdfDiffuse = surfaceData.albedo * oneMinusReflectivity;
    half3 brdfSpecular = surfaceData.specular;
    half alpha = surfaceData.alpha;

    outBRDFData.albedo = surfaceData.albedo;
    outBRDFData.diffuse = brdfDiffuse;
    outBRDFData.specular = brdfSpecular;
    outBRDFData.reflectivity = reflectivity;

    outBRDFData.perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(surfaceData.smoothness);
    outBRDFData.roughness           = max(PerceptualRoughnessToRoughness(outBRDFData.perceptualRoughness), HALF_MIN_SQRT);
    outBRDFData.roughness2          = max(outBRDFData.roughness * outBRDFData.roughness, HALF_MIN);
    outBRDFData.grazingTerm         = saturate(surfaceData.smoothness + reflectivity);
    outBRDFData.normalizationTerm   = outBRDFData.roughness * half(4.0) + half(2.0);
    outBRDFData.roughness2MinusOne  = outBRDFData.roughness2 - half(1.0);

    // Input is expected to be non-alpha-premultiplied while ROP is set to pre-multiplied blend.
    // We use input color for specular, but (pre-)multiply the diffuse with alpha to complete the standard alpha blend equation.
    // In shader: Cs' = Cs * As, in ROP: Cs' + Cd(1-As);
    // i.e. we only alpha blend the diffuse part to background (transmittance).
    #if defined(_ALPHAPREMULTIPLY_ON)
        // TODO: would be clearer to multiply this once to accumulated diffuse lighting at end instead of the surface property.
        outBRDFData.diffuse *= alpha;
    #endif
   
    // if (HasFlag(surfaceData.materialFeatures, MATERIALFEATUREFLAGS_FABRIC_TRANSMISSION))
    // {
    //     // Assign profile id and overwrite fresnel0
    //     FillMaterialTransmission(bsdfData.diffusionProfileIndex, surfaceData.thickness, surfaceData.transmissionMask, bsdfData);
    // }

    // After the fill material SSS data has operated, in the case of the fabric we force the value of the fresnel0 term
    //bsdfData.fresnel0 = surfaceData.specularColor;

    // roughnessT and roughnessB are clamped, and are meant to be used with punctual and directional lights.
    // perceptualRoughness is not clamped, and is meant to be used for IBL.
    // perceptualRoughness can be modify by FillMaterialClearCoatData, so ConvertAnisotropyToClampRoughness must be call after
    ConvertAnisotropyToClampRoughness(outBRDFData.perceptualRoughness, anisotropy, outBRDFData.roughnessT, outBRDFData.roughnessB);
   
    #if _FABRIC_SILK
        half iblPerceptualRoughness = outBRDFData.perceptualRoughness * saturate(1.2 - abs(anisotropy));
        //  Override perceptual roughness for ambient specular reflections
        outBRDFData.perceptualRoughness = iblPerceptualRoughness;
        FillMaterialAnisotropy(anisotropy, tangentWS, normalize(cross(normalWS, tangentWS)), outBRDFData);
    #endif
}

///////////////////////////////////////////////////////////////////////////////
//                            Fabric BRDF                                    //
///////////////////////////////////////////////////////////////////////////////
BRDFData InitializeFabricDebugBRDFData(FabricBRDFData brdfData)
{
    BRDFData brdfData_Debug;
    brdfData_Debug.albedo = brdfData.albedo;
    brdfData_Debug.diffuse = brdfData.diffuse;
    brdfData_Debug.reflectivity = brdfData.reflectivity;
    brdfData_Debug.roughness = brdfData.roughness;
    brdfData_Debug.roughness2 = brdfData.roughness2;
    brdfData_Debug.specular = brdfData.specular;
    brdfData_Debug.grazingTerm = brdfData.grazingTerm;
    brdfData_Debug.normalizationTerm = brdfData.normalizationTerm;
    brdfData_Debug.perceptualRoughness = brdfData.perceptualRoughness;
    brdfData_Debug.roughness2MinusOne = brdfData.roughness2MinusOne;

    return brdfData_Debug;
}

#endif
