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
    float3 refraction;
    float StylizedSpecularSize;
    float StylizedSpecularSoftness;
    float cellThreshold;
    float cellSoftness;
    float geometryAAVariant;
    float geometryAAStrength;
    float envRotate;
    float envSpecularIntensity;
    float coatSpecularIntensity;
    float anisotropy;
};

void InitializeInputData(Varyings input, SurfaceDescription surfaceDescription,FernSGAddSurfaceData addSurfData,
    out FernAddInputData addInputData, out InputData inputData)
{
    inputData = (InputData)0;
    addInputData = (FernAddInputData)0;

    inputData.positionWS = input.positionWS; 
    addInputData.tangentWS = normalize(input.tangentWS.xyz);

    #ifdef _NORMALMAP
        // IMPORTANT! If we ever support Flip on double sided materials ensure bitangent and tangent are NOT flipped.
        float crossSign = (input.tangentWS.w > 0.0 ? 1.0 : -1.0) * GetOddNegativeScale();
        float3 bitangent = crossSign * cross(input.normalWS.xyz, input.tangentWS.xyz);

        inputData.tangentToWorld = float3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);
        #if _NORMAL_DROPOFF_TS
            inputData.normalWS = TransformTangentToWorld(surfaceDescription.NormalTS, inputData.tangentToWorld);
        #elif _NORMAL_DROPOFF_OS
            inputData.normalWS = TransformObjectToWorldNormal(surfaceDescription.NormalOS);
        #elif _NORMAL_DROPOFF_WS
            inputData.normalWS = surfaceDescription.NormalWS;
        #endif
        #ifdef _CLEARCOATNORMAL
            addInputData.clearCoatNormalWS = (addSurfData.clearCoatNormal);
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
        lightData.HalfLambert_ClearCoat = lightData. NdotL_ClearCoat* 0.5 + 0.5;
        lightData.NdotLClamp_ClearCoat = saturate(lightData.NdotL_ClearCoat);
        lightData.NdotHClamp_ClearCoat = saturate(dot(clearCoatNormalWS.xyz, halfDir.xyz));
        lightData.NdotVClamp_ClearCoat = saturate(dot(clearCoatNormalWS.xyz, viewDirectionWS.xyz));
    #endif
}

LightingAngle InitializeLightingAngle(Light mainLight, Varyings input, float3 clearCoatNormalWS, float3 normalWS, float3 viewDirectionWS)
{
    LightingAngle lightData = (LightingAngle)0;
    lightData.lightColor = mainLight.color;
    lightData.lightDir = mainLight.direction;

    lightData.NdotL = dot(normalWS, mainLight.direction.xyz);
    lightData.NdotLClamp = saturate(lightData.NdotL);
    lightData.HalfLambert = lightData.NdotL * 0.5 + 0.5;
    
    lightData.NdotV = dot(normalWS.xyz, viewDirectionWS.xyz);
    lightData.NdotVClamp = max(lightData.NdotV, 0.0001);
    
    float3 halfDir = SafeNormalize(mainLight.direction + viewDirectionWS);
    float LdotH = dot(mainLight.direction.xyz, halfDir.xyz);
    lightData.LdotHClamp = saturate(LdotH);
    lightData.NdotHClamp = saturate(dot(normalWS.xyz, halfDir.xyz));
    lightData.HalfDir = halfDir;

    GetBSDFAngle(viewDirectionWS, mainLight.direction, lightData.NdotL, lightData.NdotV, lightData.LdotV, lightData.NdotH, lightData.LdotH, lightData.invLenLV);
    
    #if defined(_RECEIVE_SHADOWS_OFF)
    lightData.ShadowAttenuation = 1;
    #elif _DEPTHSHADOW
    lightData.ShadowAttenuation = DepthShadow(_DepthShadowOffset, _DepthOffsetShadowReverseX, _DepthShadowThresoldOffset, _DepthShadowSoftness, input.positionCS.xy, mainLight.direction, addInputData);
    #else
    lightData.ShadowAttenuation = mainLight.shadowAttenuation;
    #endif

    // Important, otherwise there are problems with multiple light source attenuation
    lightData.ShadowAttenuation *= mainLight.distanceAttenuation;

    InitializeLightingDataWithClearCoat(mainLight, halfDir, clearCoatNormalWS, viewDirectionWS, lightData);

    return lightData;
}


///////////////////////////////////////////////////////////////////////////////
//                         Shading Function                                  //
///////////////////////////////////////////////////////////////////////////////

float3 NPRDiffuseLighting(LitProBRDFData brdfData, float3 rampColor, LightingAngle lightingData, FernSGAddSurfaceData addSurfData, float radiance)
{
    float3 diffuse = 0;

    #if _LAMBERTIAN
        diffuse = lerp(addSurfData.darkColor.rgb, addSurfData.lightenColor.rgb, radiance);
    #elif _RAMPSHADING
        diffuse = rampColor.rgb;
    #elif _CELLSHADING
        diffuse = CellShadingDiffuse(radiance, addSurfData.cellThreshold, addSurfData.cellSoftness, addSurfData.lightenColor.rgb, addSurfData.darkColor.rgb);
    #elif _DISNEY
        diffuse = lerp(addSurfData.darkColor.rgb, addSurfData.lightenColor.rgb, DisneyDiffuse(lightingData.NdotVClamp, abs(lightingData.NdotL), lightingData.LdotV, brdfData.perceptualRoughness));
    #endif
    
    diffuse *= brdfData.diffuse;
    return diffuse;
}

//#define _ANISO 1

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
float3 NPRSpecularLighting(LitProBRDFData brdfData, FernSurfaceData surfData, Varyings input, InputData inputData, float3 albedo, FernSGAddSurfaceData addSurfData, float radiance, LightingAngle lightData)
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
        specular = GGXDirectBRDFSpecular(brdfData, lightData.LdotHClamp, lightData.NdotHClamp, lightData.NdotHClamp_ClearCoat) * radiance;
    #elif _ANISO
        float TdotH = dot(brdfData.tangentWS, lightData.HalfDir);
        float TdotL = dot(brdfData.tangentWS, lightData.lightDir);
        float BdotH = dot(brdfData.bitangentWS, lightData.HalfDir);
        float BdotL = dot(brdfData.bitangentWS, lightData.lightDir); 
        float TdotV = dot(brdfData.tangentWS, inputData.viewDirectionWS);
        float BdotV = dot(brdfData.bitangentWS, inputData.viewDirectionWS);

        // TODO: Do comparison between this correct version and the one from isotropic and see if there is any visual difference
        // We use abs(NdotL) to handle the none case of double sided
        float D = D_GGXaniso(brdfData.roughnessT, brdfData.roughnessB, lightData.NdotHClamp, TdotH, BdotH);
        float Vis = Vis_SmithJointAniso(brdfData.roughnessT, brdfData.roughnessB, lightData.NdotV, lightData.NdotL, TdotV, TdotL, BdotV, BdotL);
        float3 F = F_SchlickAniso(brdfData.specular, lightData.VdotHClamp);

        specular = F * D * Vis * lightData.ShadowAttenuation * lightData.NdotLClamp;
        return specular;
    #endif
    

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
float3 FernMainLightDirectLighting(LitProBRDFData brdfData, LitProBRDFData brdfDataClearCoat, Varyings input, InputData inputData,
                                 FernSurfaceData surfData, float radiance, FernSGAddSurfaceData addSurfData, LightingAngle lightData)
{

    float3 diffuse = NPRDiffuseLighting(brdfData, addSurfData.rampColor, lightData, addSurfData, radiance);
    float3 specular = NPRSpecularLighting(brdfData, surfData, input, inputData, surfData.albedo, addSurfData, radiance, lightData) * brdfData.specular;

    float3 brdf = (diffuse + specular * addSurfData.specularColor.rgb);
    
    #if defined(_CLEARCOAT) || defined(_CLEARCOATMAP) 
        // Clear coat evaluates the specular a second timw and has some common terms with the base specular.
        // We rely on the compiler to merge these and compute them only once.
    // Mix clear coat and base layer using khronos glTF recommended formula
        // https://github.com/KhronosGroup/glTF/blob/master/extensions/2.0/Khronos/KHR_materials_clearcoat/README.md
        // Use NoV for direct too instead of LoH as an optimization (NoV is light invariant).
        float3 brdfCoat = kDielectricSpec.x * NPRSpecularLighting(brdfDataClearCoat, surfData, input, inputData, surfData.albedo, addSurfData, radiance, lightData) * addSurfData.coatSpecularIntensity;

        #if _CLEARCOATNORMAL
            float NoV = lightData.NdotVClamp_ClearCoat;
        #else
            float NoV = lightData.NdotVClamp;
        #endif
        // Use slightly simpler fresnelTerm (Pow4 vs Pow5) as a small optimization.
        // It is matching fresnel used in the GI/Env, so should produce a consistent clear coat blend (env vs. direct)
        float coatFresnel = kDielectricSpec.x + kDielectricSpec.a * Pow4(1.0 - NoV);
        float3 coatDiffuse = brdf * (1.0 - surfData.clearCoatMask * coatFresnel);
        //coatDiffuse = lerp(coatDiffuse, coatDiffuse * surfData.coatTint, surfData.clearCoatMask);
        brdf = coatDiffuse + brdfCoat * surfData.clearCoatMask;

    #endif // _CLEARCOAT
    
    return brdf * lightData.lightColor;
}

float3 NPRMainLightDirectLighting_Planar(LitProBRDFData brdfData, LitProBRDFData brdfDataClearCoat, Varyings input, InputData inputData,
                                 FernSurfaceData surfData, float radiance, FernSGAddSurfaceData addSurfData, LightingAngle lightData)
{
    float3 diffuse = NPRDiffuseLighting(brdfData, addSurfData.rampColor, lightData, addSurfData, radiance);
    float3 specular = 0;
    float3 brdf = (diffuse + specular) * lightData.lightColor;
    return brdf;
}

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
float3 FernAdditionLightDirectLighting(LitProBRDFData brdfData, LitProBRDFData brdfDataClearCoat, Varyings input, InputData inputData, FernAddInputData addInputData,
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
             {
                 LightingAngle lightingData = InitializeLightingAngle(light, input, addInputData.clearCoatNormalWS, inputData.normalWS, inputData.viewDirectionWS);
                 float radiance = LightingRadiance(lightingData);
                 float3 addLightColor = NPRMainLightDirectLighting_Planar(brdfData, brdfDataClearCoat, input, inputData, surfData, radiance, addSurfData, lightingData);
                 additionLightColor += addLightColor;
             }
        }
    }
    #endif

     LIGHT_LOOP_BEGIN(pixelLightCount)
         Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
     #ifdef _LIGHT_LAYERS
         if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
     #endif
         {
             {
                 LightingAngle lightingData = InitializeLightingAngle(light, input, addInputData.clearCoatNormalWS, inputData.normalWS, inputData.viewDirectionWS);
                 float radiance = LightingRadiance(lightingData);
                 float3 addLightColor = NPRMainLightDirectLighting_Planar(brdfData, brdfDataClearCoat, input, inputData, surfData, radiance, addSurfData, lightingData);
                 additionLightColor += addLightColor;
             }
         }
     LIGHT_LOOP_END
    #endif

    // vertex lighting only lambert diffuse for now...
    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
        additionLightColor += inputData.vertexLighting * brdfData.diffuse;
    #endif

    return additionLightColor;
}

float3 NPRAdditionLightDirectLighting_Planar(LitProBRDFData brdfData, LitProBRDFData brdfDataClearCoat, Varyings input, InputData inputData, FernAddInputData addInputData,
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
                    LightingAngle lightingData = InitializeLightingAngle(light, input, addInputData.clearCoatNormalWS, inputData.normalWS, inputData.viewDirectionWS);
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
                LightingAngle lightingData = InitializeLightingAngle(light, input, addInputData.clearCoatNormalWS, inputData.normalWS, inputData.viewDirectionWS);
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
            LightingAngle lightingData = InitializeLightingAngle(light, input, addInputData.clearCoatNormalWS, inputData.normalWS, inputData.viewDirectionWS);
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

float3 FernIndirectLighting(LitProBRDFData brdfData, LitProBRDFData brdfDataClearCoat, float clearCoatMask, InputData inputData, FernAddInputData addInputData, Varyings input, FernSGAddSurfaceData addSurfData, float occlusion)
{
    float3 indirectDiffuse = inputData.bakedGI * occlusion;
    float3 normalWS = inputData.normalWS;
    #if _ANISO
        float3 grainDirWS = (addSurfData.anisotropy >= 0.0) ? brdfData.bitangentWS : brdfData.tangentWS;
        float stretch = abs(addSurfData.anisotropy) * saturate(1.5h * sqrt(brdfData.perceptualRoughness));
        normalWS = GetAnisotropicModifiedNormal(grainDirWS, inputData.normalWS, inputData.viewDirectionWS, stretch);
    #endif

    float3 reflectVector = reflect(-inputData.viewDirectionWS, normalWS);
    #if _ENVROTATE
        reflectVector = RotateAroundYInDegrees(reflectVector, addSurfData.envRotate);
    #endif

    float NoV = saturate(dot(normalWS, inputData.viewDirectionWS));
    float fresnelTerm = Pow4(1.0 - NoV);
    //float fresnelTerm = (1.0 - NoV); // For Move Reflection
    float3 indirectSpecular = 0;
    #if _ENVDEFAULT
        indirectSpecular = NPRGlossyEnvironmentReflection(reflectVector, inputData.positionWS, inputData.normalizedScreenSpaceUV, brdfData.perceptualRoughness, occlusion) * addSurfData.envSpecularIntensity;
    #elif _ENVCUSTOM
        indirectSpecular = NPRGlossyEnvironmentReflection_Custom(addSurfData.envCustomReflection, occlusion) * addSurfData.envSpecularIntensity;
    #else
        indirectSpecular = _GlossyEnvironmentColor.rgb * occlusion;
    #endif
    
    //float3 hso = GetHorizonOcclusion(inputData.viewDirectionWS, inputData.normalWS, input.normalWS, 4);
    
    float3 indirectColor = LitPro_EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);

    #if _MATCAP
        float3 matCap = SamplerMatCap(_MatCapColor, input.uv.zw, inputData.normalWS, inputData.normalizedScreenSpaceUV, TEXTURE2D_ARGS(_MatCapTex, sampler_MatCapTex));
        indirectColor += lerp(matCap, matCap * brdfData.diffuse, _MatCapAlbedoWeight);
    #endif
    
    #if defined(_CLEARCOAT) || defined(_CLEARCOATMAP)

        #if _CLEARCOATNORMAL
            float3 clearCoatNormalWS = addInputData.clearCoatNormalWS;
        #elif _ANISO
            float3 clearCoatNormalWS = inputData.normalWS;
        #endif

        #if _ANISO || _CLEARCOATNORMAL
            reflectVector = reflect(-inputData.viewDirectionWS, clearCoatNormalWS);
            #if _ENVROTATE
            reflectVector = RotateAroundYInDegrees(reflectVector, addSurfData.envRotate);
            #endif
            NoV = saturate(dot(clearCoatNormalWS, inputData.viewDirectionWS));
            fresnelTerm = Pow4(1.0 - NoV);
        #endif
    
        //float3 coatIndirectSpecular = GlossyEnvironmentReflection(reflectVector, inputData.positionWS, inputData.normalizedScreenSpaceUV, brdfDataClearCoat.perceptualRoughness, occlusion) * addSurfData.envSpecularIntensity;
        float3 coatIndirectSpecular = GlossyEnvironmentReflection(reflectVector, inputData.positionWS, brdfDataClearCoat.perceptualRoughness, 1.0h, inputData.normalizedScreenSpaceUV);
       
        // TODO: "grazing term" causes problems on full roughness
        float3 coatColor = LitPro_EnvironmentBRDFClearCoat(brdfDataClearCoat, clearCoatMask, coatIndirectSpecular, fresnelTerm);

        // Blend with base layer using khronos glTF recommended way using NoV
        // Smooth surface & "ambiguous" lighting
        // NOTE: fresnelTerm (above) is pow4 instead of pow5, but should be ok as blend weight.
        float coatFresnel = kDielectricSpec.x + kDielectricSpec.a * fresnelTerm;
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

    #ifdef _SPECULAR_SETUP
        float3 specular = surfaceDescription.Specular;
        float metallic = 1;
    #else
        float3 specular = 0;
        float metallic = surfaceDescription.Metallic;
    #endif

    float3 normalTS = float3(0, 0, 0);
    #if defined(_NORMALMAP) && defined(_NORMAL_DROPOFF_TS)
        normalTS = surfaceDescription.NormalTS;
    #endif

    FernSurfaceData surfData = (FernSurfaceData)0;
    surfData.albedo              = surfaceDescription.BaseColor;
    surfData.metallic            = saturate(metallic);
    surfData.specular            = specular;
    surfData.smoothness          = saturate(surfaceDescription.Smoothness),
    surfData.occlusion           = surfaceDescription.Occlusion,
    surfData.emission            = surfaceDescription.Emission,
    surfData.alpha               = saturate(alpha);
    surfData.normalTS            = normalTS;
    surfData.clearCoatMask       = 0;
    surfData.clearCoatSmoothness = 1;

    #ifdef _CLEARCOAT
        surfData.clearCoatMask       = surfaceDescription.CoatMask;
        surfData.clearCoatSmoothness = surfaceDescription.CoatSmoothness;
        surfData.coatTint = surfaceDescription.ClearCoatTint;
    #endif

    // Init AddSurfaceData
    FernSGAddSurfaceData addSurfData = (FernSGAddSurfaceData)0;
    #if _ANISO
        addSurfData.anisotropy = surfaceDescription.Anisotropy;
    #endif
    addSurfData.specularColor = surfaceDescription.SpecularColor;
    #if _RAMPSHADING
        addSurfData.rampColor = surfaceDescription.RampColor;
    #endif
    #if _STYLIZED
        addSurfData.StylizedSpecularSize = surfaceDescription.StylizedSpecularSize;
        addSurfData.StylizedSpecularSoftness = surfaceDescription.StylizedSpecularSoftness;
    #endif
    #if _CELLSHADING
        addSurfData.cellThreshold = surfaceDescription.CellThreshold;
        addSurfData.cellSoftness = surfaceDescription.CellSmoothness;
    #endif
    #if _ENVCUSTOM ||_ENVDEFAULT
    addSurfData.envSpecularIntensity = surfaceDescription.EnvSpecularIntensity;
    #endif
    #if _ENVCUSTOM
        addSurfData.envCustomReflection = surfaceDescription.EnvReflection;
    #endif
    #if _ENVROTATE && _ENVDEFAULT
        addSurfData.envRotate = surfaceDescription.EnvRotate;
    #endif
    #if _CLEARCOATNORMAL
        addSurfData.clearCoatNormal = surfaceDescription.ClearCoatNormal;
    #endif
    #ifdef _CLEARCOAT
        addSurfData.coatTint = surfaceDescription.ClearCoatTint;
        addSurfData.coatSpecularIntensity = surfaceDescription.ClearCoatSpecularIntensity;
    #endif
    #ifdef _REFRACTION
        addSurfData.refraction = surfaceDescription.Refraction;
    #endif
    #if !_RAMPSHADING
        addSurfData.darkColor = surfaceDescription.DarkColor;
        addSurfData.lightenColor = surfaceDescription.LightenColor;
    #endif

    surfData.albedo = AlphaModulate(surfData.albedo, surfData.alpha);

    InputData inputData;
    FernAddInputData addInputData;
    InitializeInputData(unpacked, surfaceDescription, addSurfData, addInputData, inputData);
    // TODO: Mip debug modes would require this, open question how to do this on ShaderGraph.
    //SETUP_DEBUG_TEXTURE_DATA(inputData, unpacked.texCoord1.xy, _MainTex);

    #if _SPECULARAA
        addSurfData.geometryAAVariant = surfaceDescription.GeometryAAVariant;
        addSurfData.geometryAAStrength = surfaceDescription.GeometryAAStrength;
        float geometryAA = GeometryAA(inputData.normalWS, surfData.smoothness, addSurfData);
        float geometryAAClearCoat = GeometryAA(inputData.normalWS, surfData.clearCoatSmoothness, addSurfData);
        surfData.clearCoatSmoothness *= geometryAAClearCoat;
        surfData.smoothness *= geometryAA;
        //surfData.occlusion *= geometryAA;
    #endif

#ifdef _DBUFFER
    ApplyDecalToSurfaceData(unpacked.positionCS, surface, inputData);
#endif

    float4 shadowMask = CalculateShadowMask(inputData);

    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData.normalizedScreenSpaceUV, surfData.occlusion);
    uint meshRenderingLayers = GetMeshRenderingLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LitProBRDFData brdfData, clearCoatbrdfData;
    FernInitializeBRDFData(surfData, inputData.normalWS, addInputData.tangentWS, addSurfData.anisotropy, brdfData, clearCoatbrdfData);

    LightingAngle lightingData = InitializeLightingAngle(mainLight, unpacked, addInputData.clearCoatNormalWS, inputData.normalWS, inputData.viewDirectionWS);
    float radiance = LightingRadiance(lightingData);

    float4 color = 0;

    #if defined(DEBUG_DISPLAY)
        float4 debugColor;
        SurfaceData surface_data = (SurfaceData)0;
        surface_data.albedo = surfData.albedo;
        surface_data.normalTS = surfData.normalTS;
        surface_data.smoothness = surfData.smoothness;
        surface_data.metallic = surfData.metallic;
        surface_data.occlusion = surfData.occlusion;
        surface_data.alpha = surfData.alpha;
        surface_data.specular = surfData.specular;
        surface_data.emission = surfData.emission;
        surface_data.clearCoatMask = surfData.clearCoatMask;
        BRDFData brdfDataDebug = (BRDFData)0;
        brdfDataDebug.albedo = brdfData.albedo;
        brdfDataDebug.diffuse = brdfData.albedo;
        brdfDataDebug.roughness = brdfData.albedo;
        brdfDataDebug.specular = brdfData.albedo;
        
        if (CanDebugOverrideOutputColor(inputData, surface_data, brdfDataDebug, debugColor))
        {
            outColor = debugColor;
            return;
        }
    #endif

    #ifdef _LIGHT_LAYERS
    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    #endif
    {
        color.rgb = FernMainLightDirectLighting(brdfData, clearCoatbrdfData, unpacked, inputData, surfData, radiance, addSurfData, lightingData);
    }
    color.rgb += FernAdditionLightDirectLighting(brdfData, clearCoatbrdfData, unpacked, inputData, addInputData, surfData, shadowMask, meshRenderingLayers, addSurfData, aoFactor);
    color.rgb += FernIndirectLighting(brdfData, clearCoatbrdfData, surfData.clearCoatMask, inputData, addInputData, unpacked, addSurfData, aoFactor.indirectAmbientOcclusion);
    color.rgb += surfData.emission + addSurfData.refraction;
    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    color.a = OutputAlpha(surfData.alpha, isTransparent);

    outColor = color;

#ifdef _WRITE_RENDERING_LAYERS
    uint renderingLayers = GetMeshRenderingLayer();
    outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
#endif
}

// ============ Planar Reflection Pass ===============//

half _IsDepthFade;
half _DepthFade;

void frag_PlanarReflection(
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

    #ifdef _SPECULAR_SETUP
        float3 specular = surfaceDescription.Specular;
        float metallic = 1;
    #else
        float3 specular = 0;
        float metallic = surfaceDescription.Metallic;
    #endif

    float3 normalTS = float3(0, 0, 0);
    #if defined(_NORMALMAP) && defined(_NORMAL_DROPOFF_TS)
        normalTS = surfaceDescription.NormalTS;
    #endif

    FernSurfaceData surfData = (FernSurfaceData)0;
    surfData.albedo              = surfaceDescription.BaseColor;
    surfData.metallic            = saturate(metallic);
    surfData.specular            = specular;
    surfData.smoothness          = saturate(surfaceDescription.Smoothness),
    surfData.occlusion           = surfaceDescription.Occlusion,
    surfData.emission            = surfaceDescription.Emission,
    surfData.alpha               = saturate(alpha);
    surfData.normalTS            = normalTS;
    surfData.clearCoatMask       = 0;
    surfData.clearCoatSmoothness = 1;

    float planarIntensity = surfaceDescription.PlanarReflectionIntensity;

    #ifdef _CLEARCOAT
        surfData.clearCoatMask       = surfaceDescription.CoatMask;
        surfData.clearCoatSmoothness = surfaceDescription.CoatSmoothness;
        surfData.coatTint = surfaceDescription.ClearCoatTint;
    #endif

    // Init AddSurfaceData
    FernSGAddSurfaceData addSurfData = (FernSGAddSurfaceData)0;
    #if _ANISO
        addSurfData.anisotropy = surfaceDescription.Anisotropy;
    #endif
    addSurfData.specularColor = surfaceDescription.SpecularColor;
    #if _RAMPSHADING
        addSurfData.rampColor = surfaceDescription.RampColor;
    #endif
    #if _STYLIZED
        addSurfData.StylizedSpecularSize = surfaceDescription.StylizedSpecularSize;
        addSurfData.StylizedSpecularSoftness = surfaceDescription.StylizedSpecularSoftness;
    #endif
    #if _CELLSHADING
        addSurfData.cellThreshold = surfaceDescription.CellThreshold;
        addSurfData.cellSoftness = surfaceDescription.CellSmoothness;
    #endif
    #if _ENVCUSTOM ||_ENVDEFAULT
    addSurfData.envSpecularIntensity = surfaceDescription.EnvSpecularIntensity;
    #endif
    #if _ENVCUSTOM
        addSurfData.envCustomReflection = surfaceDescription.EnvReflection;
    #endif
    #if _ENVROTATE && _ENVDEFAULT
        addSurfData.envRotate = surfaceDescription.EnvRotate;
    #endif
    #if _CLEARCOATNORMAL
        addSurfData.clearCoatNormal = surfaceDescription.ClearCoatNormal;
    #endif
    #ifdef _CLEARCOAT
        addSurfData.coatTint = surfaceDescription.ClearCoatTint;
        addSurfData.coatSpecularIntensity = surfaceDescription.ClearCoatSpecularIntensity;
    #endif
    #ifdef _REFRACTION
        addSurfData.refraction = surfaceDescription.Refraction;
    #endif
    #if !_RAMPSHADING
        addSurfData.darkColor = surfaceDescription.DarkColor;
        addSurfData.lightenColor = surfaceDescription.LightenColor;
    #endif

    surfData.albedo = AlphaModulate(surfData.albedo, surfData.alpha);

    InputData inputData;
    FernAddInputData addInputData;
    InitializeInputData(unpacked, surfaceDescription, addSurfData, addInputData, inputData);
    // TODO: Mip debug modes would require this, open question how to do this on ShaderGraph.
    //SETUP_DEBUG_TEXTURE_DATA(inputData, unpacked.texCoord1.xy, _MainTex);

    #if _SPECULARAA
        addSurfData.geometryAAVariant = surfaceDescription.GeometryAAVariant;
        addSurfData.geometryAAStrength = surfaceDescription.GeometryAAStrength;
        float geometryAA = GeometryAA(inputData.normalWS, surfData.smoothness, addSurfData);
        float geometryAAClearCoat = GeometryAA(inputData.normalWS, surfData.clearCoatSmoothness, addSurfData);
        surfData.clearCoatSmoothness *= geometryAAClearCoat;
        surfData.smoothness *= geometryAA;
        //surfData.occlusion *= geometryAA;
    #endif

#ifdef _DBUFFER
    ApplyDecalToSurfaceData(unpacked.positionCS, surface, inputData);
#endif

    float4 shadowMask = CalculateShadowMask(inputData);

    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData.normalizedScreenSpaceUV, surfData.occlusion);
    uint meshRenderingLayers = GetMeshRenderingLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LitProBRDFData brdfData, clearCoatbrdfData;
    FernInitializeBRDFData(surfData, inputData.normalWS, addInputData.tangentWS, addSurfData.anisotropy, brdfData, clearCoatbrdfData);

    LightingAngle lightingData = InitializeLightingAngle(mainLight, unpacked, addInputData.clearCoatNormalWS, inputData.normalWS, inputData.viewDirectionWS);
    float radiance = LightingRadiance(lightingData);
    
    float4 color = 0;

    #if defined(DEBUG_DISPLAY)
        float4 debugColor;
        SurfaceData surface_data = (SurfaceData)0;
        surface_data.albedo = surfData.albedo;
        surface_data.normalTS = surfData.normalTS;
        surface_data.smoothness = surfData.smoothness;
        surface_data.metallic = surfData.metallic;
        surface_data.occlusion = surfData.occlusion;
        surface_data.alpha = surfData.alpha;
        surface_data.specular = surfData.specular;
        surface_data.emission = surfData.emission;
        surface_data.clearCoatMask = surfData.clearCoatMask;
        BRDFData brdfDataDebug = (BRDFData)0;
        brdfDataDebug.albedo = brdfData.albedo;
        brdfDataDebug.diffuse = brdfData.albedo;
        brdfDataDebug.roughness = brdfData.albedo;
        brdfDataDebug.specular = brdfData.albedo;
        
        if (CanDebugOverrideOutputColor(inputData, surface_data, brdfDataDebug, debugColor))
        {
            outColor = debugColor;
            return;
        }
    #endif

    #ifdef _LIGHT_LAYERS
    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    #endif
    {
        color.rgb = FernMainLightDirectLighting(brdfData, clearCoatbrdfData, unpacked, inputData, surfData, radiance, addSurfData, lightingData);
    }

    //color.rgb += FernAdditionLightDirectLighting(brdfData, clearCoatbrdfData, unpacked, inputData, addInputData, surfData, shadowMask, meshRenderingLayers, addSurfData, aoFactor);
    color.rgb += FernIndirectLighting(brdfData, clearCoatbrdfData, surfData.clearCoatMask, inputData, addInputData, unpacked, addSurfData, aoFactor.indirectAmbientOcclusion);
    color.rgb += surfData.emission + addSurfData.refraction;
    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    color.a = OutputAlpha(surfData.alpha, isTransparent);

    // depth fade
    #if UNITY_REVERSED_Z
        half posZ = unpacked.positionCS.z;
    #else
        half posZ = (1 - unpacked.positionCS.z);
    #endif
    //float viewPos = saturate(-TransformWorldToView(inputData.positionWS).z);
    color.a = lerp(1, saturate(pow(posZ, abs(_DepthFade))), _IsDepthFade);
    //color.rgb = lerp(color.rgb, color.rgb * saturate(pow(posZ, abs(_DepthFade))), _IsDepthFade); 

    outColor = color;

#ifdef _WRITE_RENDERING_LAYERS
    uint renderingLayers = GetMeshRenderingLayer();
    outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
#endif
}
