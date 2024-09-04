#include "FernSGNPRLighting.hlsl"

struct FernSGAddSurfaceData
{
    float4 envCustomReflection;
    float3 rampColor;
    float3 specularColor;
    float3 darkColor;
    float3 lightenColor;
    float3 clearCoatNormal;
    float3 coatTint;
    float StylizedSpecularSize;
    float StylizedSpecularSoftness;
    float cellThreshold;
    float cellSoftness;
    float geometryAAVariant;
    float geometryAAStrength;
    float envRotate;
    float envSpecularIntensity;
    float coatSpecularIntensity;
};

void InitializeInputData(Varyings input, SurfaceDescription surfaceDescription,FernSGAddSurfaceData addSurfData, out FernAddInputData addInputData, out InputData inputData)
{
    inputData = (InputData)0;
    addInputData = (FernAddInputData)0;

    inputData.positionWS = input.positionWS;

    #ifdef _NORMALMAP
        // IMPORTANT! If we ever support Flip on double sided materials ensure bitangent and tangent are NOT flipped.
        float crossSign = (input.tangentWS.w > 0.0 ? 1.0 : -1.0) * GetOddNegativeScale();
        float3 bitangent = crossSign * cross(input.normalWS.xyz, input.tangentWS.xyz);

        inputData.tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);
        #if _NORMAL_DROPOFF_TS
            inputData.normalWS = TransformTangentToWorld(surfaceDescription.NormalTS, inputData.tangentToWorld);
        #elif _NORMAL_DROPOFF_OS
            inputData.normalWS = TransformObjectToWorldNormal(surfaceDescription.NormalOS);
        #elif _NORMAL_DROPOFF_WS
            inputData.normalWS = surfaceDescription.NormalWS;
        #endif
        #ifdef _CLEARCOATNORMAL
            addInputData.clearCoatNormalWS = TransformTangentToWorld(addSurfData.clearCoatNormal, inputData.tangentToWorld);
            addInputData.clearCoatNormalWS = NormalizeNormalPerPixel(addInputData.clearCoatNormalWS);
        #else
            addInputData.clearCoatNormalWS = input.normalWS;
            addInputData.clearCoatNormalWS = NormalizeNormalPerPixel(addInputData.clearCoatNormalWS);
        #endif
    #else
        inputData.normalWS = input.normalWS;
        addInputData.clearCoatNormalWS = input.normalWS;
        addInputData.clearCoatNormalWS = NormalizeNormalPerPixel(addInputData.clearCoatNormalWS);
    #endif
    
    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        inputData.shadowCoord = input.shadowCoord;
    #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
        inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
    #else
        inputData.shadowCoord = float4(0, 0, 0, 0);
    #endif

    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactorAndVertexLight.x);
    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
#if defined(DYNAMICLIGHTMAP_ON)
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV.xy, input.sh, inputData.normalWS);
#else
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.sh, inputData.normalWS);
#endif
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);

    #if defined(DEBUG_DISPLAY)
    #if defined(DYNAMICLIGHTMAP_ON)
    inputData.dynamicLightmapUV = input.dynamicLightmapUV.xy;
    #endif
    #if defined(LIGHTMAP_ON)
    inputData.staticLightmapUV = input.staticLightmapUV;
    #else
    inputData.vertexSH = input.sh;
    #endif
    #endif
}

inline float GeometryAA(float3 normalWS, float smoothness, FernSGAddSurfaceData addSurfData)
{
    float dx = dot(ddx(normalWS),ddx(normalWS));
    float dy = dot(ddy(normalWS),ddy(normalWS));
    float roughness = 1 - smoothness;
    float roughnessAA = roughness * roughness + min(LerpWhiteTo(32, addSurfData.geometryAAVariant) * (dx + dy), addSurfData.geometryAAStrength * addSurfData.geometryAAStrength);
    return  1 - saturate(roughnessAA);
    float smoothnessAA = smoothness * (1 - roughnessAA);
    return smoothnessAA;
}

void InitializeLightingDataWithClearCoat(Light mainLight, float3 halfDir, float3 clearCoatNormalWS, float3 viewDirectionWS, inout LightingAngle lightData)
{
    #if _CLEARCOATNORMAL
        lightData.NdotL_ClearCoat = dot(clearCoatNormalWS, mainLight.direction.xyz);
        lightData.HalfLambert_ClearCoat = lightData.HalfLambert_ClearCoat * 0.5 + 0.5;
        lightData.NdotLClamp_ClearCoat = saturate(lightData.NdotL_ClearCoat);
        lightData.NdotHClamp_ClearCoat = saturate(dot(clearCoatNormalWS.xyz, halfDir.xyz));
        lightData.NdotVClamp_ClearCoat = saturate(dot(clearCoatNormalWS.xyz, viewDirectionWS.xyz));
    #endif
}

LightingAngle InitializeLightingData(Light mainLight, Varyings input, float3 clearCoatNormalWS, float3 normalWS, float3 viewDirectionWS)
{
    LightingAngle lightData = (LightingAngle)0;
    lightData.lightColor = mainLight.color;
    #if EYE
        lightData.NdotL = dot(addInputData.irisNormalWS, mainLight.direction.xyz);
    #else
        lightData.NdotL = dot(normalWS, mainLight.direction.xyz);
    #endif
    
    lightData.NdotLClamp = saturate(lightData.NdotL);
    lightData.HalfLambert = lightData.NdotL * 0.5 + 0.5;
    float3 halfDir = SafeNormalize(mainLight.direction + viewDirectionWS);
    lightData.LdotHClamp = saturate(dot(mainLight.direction.xyz, halfDir.xyz));
    lightData.NdotHClamp = saturate(dot(normalWS.xyz, halfDir.xyz));
    lightData.NdotVClamp = saturate(dot(normalWS.xyz, viewDirectionWS.xyz));
    lightData.HalfDir = halfDir;
    lightData.lightDir = mainLight.direction;
    #if defined(_RECEIVE_SHADOWS_OFF)
        lightData.ShadowAttenuation = 1;
    #elif _DEPTHSHADOW
        lightData.ShadowAttenuation = DepthShadow(_DepthShadowOffset, _DepthOffsetShadowReverseX, _DepthShadowThresoldOffset, _DepthShadowSoftness, input.positionCS.xy, mainLight.direction, addInputData);
    #else
        lightData.ShadowAttenuation = mainLight.shadowAttenuation * mainLight.distanceAttenuation;
    #endif

    InitializeLightingDataWithClearCoat(mainLight, halfDir, clearCoatNormalWS, viewDirectionWS, lightData);

    return lightData;
}


///////////////////////////////////////////////////////////////////////////////
//                         Shading Function                                  //
///////////////////////////////////////////////////////////////////////////////

float3 NPRDiffuseLighting(BRDFData brdfData, float3 rampColor, LightingAngle lightingData, FernSGAddSurfaceData addSurfData, float radiance)
{
    float3 diffuse = 0;

    #if _LAMBERTIAN
        diffuse = lerp(addSurfData.darkColor.rgb, addSurfData.lightenColor.rgb, radiance);
    #elif _RAMPSHADING
        diffuse = rampColor.rgb;
    #elif _CELLSHADING
        diffuse = CellShadingDiffuse(radiance, addSurfData.cellThreshold, addSurfData.cellSoftness, addSurfData.lightenColor.rgb, addSurfData.darkColor.rgb);
    #endif
    
    diffuse *= brdfData.diffuse;
    return diffuse;
}

/**
 * \brief NPR Specular
 * \param brdfData 
 * \param surfData 
 * \param input 
 * \param inputData 
 * \param albedo 
 * \param addSurfData 
 * \param radiance 
 * \param lightData 
 * \return 
 */
float3 NPRSpecularLighting(BRDFData brdfData, FernSurfaceData surfData, Varyings input, InputData inputData, float3 albedo, FernSGAddSurfaceData addSurfData, float radiance, LightingAngle lightData)
{
    float3 specular = 0;
    #if _STYLIZED
        specular = StylizedSpecular(albedo, lightData.NdotHClamp, addSurfData.StylizedSpecularSize, addSurfData.StylizedSpecularSoftness);
    #elif _BLINNPHONG
        specular = BlinnPhongSpecular((1 - brdfData.perceptualRoughness), lightData.NdotHClamp);
    #elif _KAJIYAHAIR
        float2 anisoUV = input.uv.xy * _AnisoShiftScale;
        AnisoSpecularData anisoSpecularData;
        InitAnisoSpecularData(anisoSpecularData);
        specular = AnisotropyDoubleSpecular(brdfData, anisoUV, input.tangentWS, inputData, lightData, anisoSpecularData,
            TEXTURE2D_ARGS(_AnisoShiftMap, sampler_AnisoShiftMap));
    #elif _ANGLERING
        AngleRingSpecularData angleRingSpecularData;
        InitAngleRingSpecularData(1, angleRingSpecularData);
        specular = AngleRingSpecular(angleRingSpecularData, inputData, radiance, lightData);
    #elif _GGX
        #if _CLEARCOATNORMAL
            specular = GGXDirectBRDFSpecular(brdfData, lightData.LdotHClamp, lightData.NdotHClamp_ClearCoat);
        #else
            specular = GGXDirectBRDFSpecular(brdfData, lightData.LdotHClamp, lightData.NdotHClamp);
        #endif
    #endif
    
    specular *= radiance * brdfData.specular;
    
    return specular;
}

/**
 * \brief Main Lighting, consists of NPR and PBR Lighting Equation
 * \param brdfData 
 * \param brdfDataClearCoat 
 * \param input 
 * \param inputData 
 * \param surfData 
 * \param radiance 
 * \param lightData 
 * \return 
 */
float3 NPRMainLightDirectLighting(BRDFData brdfData, BRDFData brdfDataClearCoat, Varyings input, InputData inputData,
                                 FernSurfaceData surfData, float radiance, FernSGAddSurfaceData addSurfData, LightingAngle lightData)
{
    float3 diffuse = NPRDiffuseLighting(brdfData, addSurfData.rampColor, lightData, addSurfData, radiance);
    float3 specular = NPRSpecularLighting(brdfData, surfData, input, inputData, surfData.albedo, addSurfData, radiance, lightData) * addSurfData.specularColor.rgb;
    float3 brdf = (diffuse + specular) * lightData.lightColor;

    #if defined(_CLEARCOAT) || defined(_CLEARCOATMAP)
        // Clear coat evaluates the specular a second timw and has some common terms with the base specular.
        // We rely on the compiler to merge these and compute them only once.
        half3 brdfCoat = kDielectricSpec.x * NPRSpecularLighting(brdfDataClearCoat, surfData, input, inputData, surfData.albedo, addSurfData, radiance, lightData) * addSurfData.coatSpecularIntensity;
        // Mix clear coat and base layer using khronos glTF recommended formula
        // https://github.com/KhronosGroup/glTF/blob/master/extensions/2.0/Khronos/KHR_materials_clearcoat/README.md
        // Use NoV for direct too instead of LoH as an optimization (NoV is light invariant).
        #if _CLEARCOATNORMAL
            half NoV = lightData.NdotVClamp_ClearCoat;
        #else
            half NoV = lightData.NdotVClamp;
        #endif
        // Use slightly simpler fresnelTerm (Pow4 vs Pow5) as a small optimization.
        // It is matching fresnel used in the GI/Env, so should produce a consistent clear coat blend (env vs. direct)
        half coatFresnel = kDielectricSpec.x + kDielectricSpec.a * Pow4(1.0 - NoV);
        float3 coatDiffuse = brdf * (1.0 - surfData.clearCoatMask * coatFresnel);
        //coatDiffuse = lerp(coatDiffuse, coatDiffuse * surfData.coatTint, surfData.clearCoatMask);
        brdf = coatDiffuse + brdfCoat * surfData.clearCoatMask;

    #endif // _CLEARCOAT
    
    return brdf;
}

float3 NPRMainLightDirectLighting_Planar(BRDFData brdfData, BRDFData brdfDataClearCoat, Varyings input, InputData inputData,
                                 FernSurfaceData surfData, float radiance, FernSGAddSurfaceData addSurfData, LightingAngle lightData)
{
    float3 diffuse = NPRDiffuseLighting(brdfData, addSurfData.rampColor, lightData, addSurfData, radiance);
    float3 specular = 0;
    float3 brdf = (diffuse + specular) * lightData.lightColor;
    return brdf;
}

#define _SIMPLEAREALIGHTS 0

/**
 * \brief AdditionLighting, Lighting Equation base on MainLight, TODO: if cell-shading should use other lighting equation
 * \param brdfData 
 * \param brdfDataClearCoat 
 * \param input 
 * \param inputData 
 * \param surfData 
 * \param addInputData 
 * \param shadowMask 
 * \param meshRenderingLayers 
 * \param aoFactor 
 * \return 
 */
float3 NPRAdditionLightDirectLighting(BRDFData brdfData, BRDFData brdfDataClearCoat, Varyings input, InputData inputData, FernAddInputData addInputData,
                                     FernSurfaceData surfData,float4 shadowMask, float meshRenderingLayers, FernSGAddSurfaceData addSurfData,
                                     AmbientOcclusionFactor aoFactor)
{
    float3 additionLightColor = 0;
    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();

    #if USE_FORWARD_PLUS
    for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK

        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

    #ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
    #endif
        {
            LightingAngle lightingData = InitializeLightingData(light, input, addInputData.clearCoatNormalWS, inputData.normalWS, inputData.viewDirectionWS);
            float radiance = LightingRadiance(lightingData);
            // Additional Light Filter Referenced from https://github.com/unity3d-jp/UnityChanToonShaderVer2_Project
            float pureIntencity = max(0.001,(0.299 * lightingData.lightColor.r + 0.587 * lightingData.lightColor.g + 0.114 * lightingData.lightColor.b));
            //lightingData.lightColor = max(0, lerp(lightingData.lightColor, lerp(0, min(lightingData.lightColor, lightingData.lightColor / pureIntencity * _LightIntensityClamp), 1), _Is_Filter_LightColor));
            float3 addLightColor = NPRMainLightDirectLighting(brdfData, brdfDataClearCoat, input, inputData, surfData, radiance, addSurfData, lightingData);
            additionLightColor += addLightColor;
        }
    }
    #endif

    #if USE_CLUSTERED_LIGHTING
    for (uint lightIndex = 0; lightIndex < min(_AdditionalLightsDirectionalCount, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
    #ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
    #endif
        {
            LightingAngle lightingData = InitializeLightingData(light, input, addInputData.clearCoatNormalWS, inputData.normalWS, inputData.viewDirectionWS);
            float radiance = LightingRadiance(lightingData);
            // Additional Light Filter Referenced from https://github.com/unity3d-jp/UnityChanToonShaderVer2_Project
            float pureIntencity = max(0.001,(0.299 * lightingData.lightColor.r + 0.587 * lightingData.lightColor.g + 0.114 * lightingData.lightColor.b));
            //lightingData.lightColor = max(0, lerp(lightingData.lightColor, lerp(0, min(lightingData.lightColor, lightingData.lightColor / pureIntencity * _LightIntensityClamp), 1), _Is_Filter_LightColor));
            float3 addLightColor = NPRMainLightDirectLighting(brdfData, brdfDataClearCoat, input, inputData, surfData, radiance, addSurfData, lightingData);
            additionLightColor += addLightColor;
        }
    }
    #endif

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
    #ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
    #endif
        {
            LightingAngle lightingData = InitializeLightingData(light, input, addInputData.clearCoatNormalWS, inputData.normalWS, inputData.viewDirectionWS);
            float radiance = LightingRadiance(lightingData);
            // Additional Light Filter Referenced from https://github.com/unity3d-jp/UnityChanToonShaderVer2_Project
            float pureIntencity = max(0.001,(0.299 * lightingData.lightColor.r + 0.587 * lightingData.lightColor.g + 0.114 * lightingData.lightColor.b));
           // TODO: Add SG defined:
           // lightingData.lightColor = max(0, lerp(lightingData.lightColor, lerp(0, min(lightingData.lightColor, lightingData.lightColor / pureIntencity * _LightIntensityClamp), 1), _Is_Filter_LightColor));
            float3 addLightColor = NPRMainLightDirectLighting(brdfData, brdfDataClearCoat, input, inputData, surfData, radiance, addSurfData, lightingData);
            additionLightColor += addLightColor;
        }
    LIGHT_LOOP_END
    #endif

    // vertex lighting only lambert diffuse for now...
    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
        additionLightColor += inputData.vertexLighting * brdfData.diffuse;
    #endif

    return additionLightColor;
}

float3 NPRAdditionLightDirectLighting_Planar(BRDFData brdfData, BRDFData brdfDataClearCoat, Varyings input, InputData inputData, FernAddInputData addInputData,
                                     FernSurfaceData surfData,float4 shadowMask, float meshRenderingLayers, FernSGAddSurfaceData addSurfData,
                                     AmbientOcclusionFactor aoFactor)
{
    float3 additionLightColor = 0;
    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();

    #if USE_FORWARD_PLUS
    for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK

        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

    #ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
    #endif
        {
            LightingAngle lightingData = InitializeLightingData(light, input, addInputData.clearCoatNormalWS, inputData.normalWS, inputData.viewDirectionWS);
            float radiance = LightingRadiance(lightingData);
            // Additional Light Filter Referenced from https://github.com/unity3d-jp/UnityChanToonShaderVer2_Project
            float pureIntencity = max(0.001,(0.299 * lightingData.lightColor.r + 0.587 * lightingData.lightColor.g + 0.114 * lightingData.lightColor.b));
            //lightingData.lightColor = max(0, lerp(lightingData.lightColor, lerp(0, min(lightingData.lightColor, lightingData.lightColor / pureIntencity * _LightIntensityClamp), 1), _Is_Filter_LightColor));
            float3 addLightColor = NPRMainLightDirectLighting_Planar(brdfData, brdfDataClearCoat, input, inputData, surfData, radiance, addSurfData, lightingData);
            additionLightColor += addLightColor;
        }
    }
    #endif

    #if USE_CLUSTERED_LIGHTING
    for (uint lightIndex = 0; lightIndex < min(_AdditionalLightsDirectionalCount, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
    #ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
    #endif
        {
            LightingAngle lightingData = InitializeLightingData(light, input, addInputData.clearCoatNormalWS, inputData.normalWS, inputData.viewDirectionWS);
            float radiance = LightingRadiance(lightingData);
            // Additional Light Filter Referenced from https://github.com/unity3d-jp/UnityChanToonShaderVer2_Project
            float pureIntencity = max(0.001,(0.299 * lightingData.lightColor.r + 0.587 * lightingData.lightColor.g + 0.114 * lightingData.lightColor.b));
            //lightingData.lightColor = max(0, lerp(lightingData.lightColor, lerp(0, min(lightingData.lightColor, lightingData.lightColor / pureIntencity * _LightIntensityClamp), 1), _Is_Filter_LightColor));
            float3 addLightColor = NPRMainLightDirectLighting_Planar(brdfData, brdfDataClearCoat, input, inputData, surfData, radiance, addSurfData, lightingData);
            additionLightColor += addLightColor;
        }
    }
    #endif

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
    #ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
    #endif
        {
            LightingAngle lightingData = InitializeLightingData(light, input, addInputData.clearCoatNormalWS, inputData.normalWS, inputData.viewDirectionWS);
            float radiance = LightingRadiance(lightingData);
            // Additional Light Filter Referenced from https://github.com/unity3d-jp/UnityChanToonShaderVer2_Project
            float pureIntencity = max(0.001,(0.299 * lightingData.lightColor.r + 0.587 * lightingData.lightColor.g + 0.114 * lightingData.lightColor.b));
           // TODO: Add SG defined:
           // lightingData.lightColor = max(0, lerp(lightingData.lightColor, lerp(0, min(lightingData.lightColor, lightingData.lightColor / pureIntencity * _LightIntensityClamp), 1), _Is_Filter_LightColor));
            float3 addLightColor = NPRMainLightDirectLighting_Planar(brdfData, brdfDataClearCoat, input, inputData, surfData, radiance, addSurfData, lightingData);
            additionLightColor += addLightColor;
        }
    LIGHT_LOOP_END
    #endif

    // vertex lighting only lambert diffuse for now...
    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
        additionLightColor += inputData.vertexLighting * brdfData.diffuse;
    #endif

    return additionLightColor;
}

float3 NPRIndirectLighting(BRDFData brdfData, BRDFData brdfDataClearCoat, float clearCoatMask, InputData inputData, FernAddInputData addInputData, Varyings input, FernSGAddSurfaceData addSurfData, float occlusion)
{
    float3 indirectDiffuse = inputData.bakedGI * occlusion;
    float3 reflectVector = reflect(-inputData.viewDirectionWS, inputData.normalWS);
    reflectVector = RotateAroundYInDegrees(reflectVector, addSurfData.envRotate);
    float NoV = saturate(dot(inputData.normalWS, inputData.viewDirectionWS));
    float fresnelTerm = Pow4(1.0 - NoV);
    float3 indirectSpecular = 0;
    #if _ENVDEFAULT
        indirectSpecular = NPRGlossyEnvironmentReflection(reflectVector, inputData.positionWS, inputData.normalizedScreenSpaceUV, brdfData.perceptualRoughness, occlusion) * addSurfData.envSpecularIntensity;
    #elif _ENVCUSTOM
        indirectSpecular = NPRGlossyEnvironmentReflection_Custom(addSurfData.envCustomReflection, occlusion) * addSurfData.envSpecularIntensity;
    #else
        indirectSpecular = _GlossyEnvironmentColor.rgb * occlusion;
    #endif
    
    //half3 hso = GetHorizonOcclusion(inputData.viewDirectionWS, inputData.normalWS, input.normalWS, 4);
    
    float3 indirectColor = EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);

    #if _MATCAP
        float3 matCap = SamplerMatCap(_MatCapColor, input.uv.zw, inputData.normalWS, inputData.normalizedScreenSpaceUV, TEXTURE2D_ARGS(_MatCapTex, sampler_MatCapTex));
        indirectColor += lerp(matCap, matCap * brdfData.diffuse, _MatCapAlbedoWeight);
    #endif
    
    #if defined(_CLEARCOAT) || defined(_CLEARCOATMAP)
        //half3 coatIndirectSpecular = GlossyEnvironmentReflection(reflectVector, inputData.positionWS, inputData.normalizedScreenSpaceUV, brdfDataClearCoat.perceptualRoughness, occlusion) * addSurfData.envSpecularIntensity;
        half3 coatIndirectSpecular = GlossyEnvironmentReflection(reflectVector, inputData.positionWS, brdfDataClearCoat.perceptualRoughness, 1.0h, inputData.normalizedScreenSpaceUV);

        #if _CLEARCOATNORMAL
            NoV = saturate(dot(addInputData.clearCoatNormalWS, inputData.viewDirectionWS));
            fresnelTerm = Pow4(1.0 - NoV);
        #endif

        // TODO: "grazing term" causes problems on full roughness
        half3 coatColor = EnvironmentBRDFClearCoat(brdfDataClearCoat, clearCoatMask, coatIndirectSpecular, fresnelTerm);

        // Blend with base layer using khronos glTF recommended way using NoV
        // Smooth surface & "ambiguous" lighting
        // NOTE: fresnelTerm (above) is pow4 instead of pow5, but should be ok as blend weight.
        half coatFresnel = kDielectricSpec.x + kDielectricSpec.a * fresnelTerm;
        return (indirectColor * (1.0 - coatFresnel * clearCoatMask) + coatColor) * occlusion;
    #else
        return indirectColor;
    #endif
}

// ====================== Vert/Fragment ============================
PackedVaryings vert(Attributes input)
{
    Varyings output = (Varyings)0;
    output = BuildVaryings(input);
    PackedVaryings packedOutput = (PackedVaryings)0;
    packedOutput = PackVaryings(output);
    return packedOutput;
}

void frag(
    PackedVaryings packedInput
    , out float4 outColor : SV_Target0
#ifdef _WRITE_RENDERING_LAYERS
    , out float4 outRenderingLayers : SV_Target1
#endif
)
{
    Varyings unpacked = UnpackVaryings(packedInput);
    UNITY_SETUP_INSTANCE_ID(unpacked);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(unpacked);
    SurfaceDescription surfaceDescription = BuildSurfaceDescription(unpacked);

#if defined(_SURFACE_TYPE_TRANSPARENT)
    bool isTransparent = true;
#else
    bool isTransparent = false;
#endif

#if defined(_ALPHATEST_ON)
    float alpha = AlphaDiscard(surfaceDescription.Alpha, surfaceDescription.AlphaClipThreshold);
#elif defined(_SURFACE_TYPE_TRANSPARENT)
    float alpha = surfaceDescription.Alpha;
#else
    float alpha = float(1.0);
#endif

    #if defined(LOD_FADE_CROSSFADE) && USE_UNITY_CROSSFADE
        LODFadeCrossFade(unpacked.positionCS);
    #endif

    float specularContribute = 0;
    
    #ifdef _SPECULAR_SETUP
        float3 specular = surfaceDescription.Specular;
        float metallic = 1;
        specularContribute = specular.r + 0.587 * specular.g + 0.114 * specular.b;
    specularContribute = metallic;
    #else
        float3 specular = 0;
        float metallic = surfaceDescription.Metallic;
        specularContribute = metallic;
    #endif

    float3 normalTS = float3(0, 0, 0);
    #if defined(_NORMALMAP) && defined(_NORMAL_DROPOFF_TS)
        normalTS = surfaceDescription.NormalTS;
    #endif

    FernSurfaceData surfData = (FernSurfaceData)0;
    surfData.albedo              = surfaceDescription.BaseColor;
    surfData.albedo = FastLinearToSRGB(surfData.albedo);
    surfData.metallic            = saturate(metallic);
    surfData.specular            = specular;
    surfData.smoothness          = saturate(surfaceDescription.Smoothness),
    surfData.occlusion           = surfaceDescription.Occlusion,
    surfData.emission            = surfaceDescription.Emission,
    surfData.alpha               = saturate(alpha);
    surfData.normalTS            = normalTS;
    surfData.clearCoatMask       = 0;
    surfData.clearCoatSmoothness = 1;

    float3 finalBaseColor = surfData.albedo + surfData.emission;
    // art control
    surfData.albedo = AlphaModulate(lerp(finalBaseColor, clamp(finalBaseColor,0.1,1), step(specularContribute, 0)), surfData.alpha);

    outColor = half4(surfData.albedo, specularContribute);

}