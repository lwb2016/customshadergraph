#include "FernSGNPRLighting.hlsl"

struct FernSGAddSurfaceData
{
    float4 envCustomReflection;
    float3 rampColor;
    float3 darkColor;
    float3 lightenColor;
    #if _FABRIC_COTTON_WOOL
        float3 sheenColor;
    #endif
    
    #if _FABRIC_SILK
        float Anisotropy;
    #endif
    
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

void InitializeInputData(Varyings input, SurfaceDescription surfaceDescription,FernSGAddSurfaceData addSurfData, out FernAddInputData addInputData, out InputData inputData)
{
    inputData = (InputData)0;
    addInputData = (FernAddInputData)0;

    inputData.positionWS = input.positionWS;

    #if _FABRIC_SILK
        addInputData.tangentWS = input.tangentWS.xyz;
    #endif

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
            addInputData.clearCoatNormalWS = input.normalWS;
            addInputData.clearCoatNormalWS = NormalizeNormalPerPixel(addInputData.clearCoatNormalWS);
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


void InitializeLightingAngleWithClearCoat(Light mainLight, float3 floatDir, float3 clearCoatNormalWS, float3 viewDirectionWS, inout LightingAngle lightData)
{
    #if _CLEARCOATNORMAL
        lightData.NdotL_ClearCoat = dot(clearCoatNormalWS, mainLight.direction.xyz);
        lightData.HalfLambert_ClearCoat = lightData.HalfLambert_ClearCoat * 0.5 + 0.5;
        lightData.NdotLClamp_ClearCoat = saturate(lightData.NdotL_ClearCoat);
        lightData.NdotHClamp_ClearCoat = saturate(dot(clearCoatNormalWS.xyz, floatDir.xyz));
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
    
    float3 floatDir = SafeNormalize(mainLight.direction + viewDirectionWS);
    float LdotH = dot(mainLight.direction.xyz, floatDir.xyz);
    lightData.LdotHClamp = saturate(LdotH);
    lightData.NdotHClamp = saturate(dot(normalWS.xyz, floatDir.xyz));
    lightData.HalfDir = floatDir;

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

    InitializeLightingAngleWithClearCoat(mainLight, floatDir, clearCoatNormalWS, viewDirectionWS, lightData);

    return lightData;
}


///////////////////////////////////////////////////////////////////////////////
//                         Shading Function                                  //
///////////////////////////////////////////////////////////////////////////////

/**
 * \brief Main Lighting, consists of NPR and PBR Lighting Equation, Ref: HDRP Fabric Lit
 * \param brdfData 
 * \param brdfDataClearCoat 
 * \param input 
 * \param inputData 
 * \param surfData 
 * \param radiance 
 * \param lightData 
 * \return 
 */
float3 FabricMainLightDirectLighting(FabricBRDFData brdfData, Varyings input, InputData inputData,
    FernSurfaceData surfData, FernSGAddSurfaceData addSurfData, LightingAngle lightData)
{
    float flippedNdotL = ComputeWrappedDiffuseLighting(-lightData.NdotL, TRANSMISSION_WRAP_LIGHT);
    float3  diffTerm;
    float3  diffT; // TODO: Translucent
    float3  diffR;
    float3 specTerm;

    #if _FABRIC_COTTON_WOOL
        float D = D_Charlie(lightData.NdotH, brdfData.roughnessT);
        // V_Charlie is expensive, use approx with V_Ashikhmin instead
        // float Vis = V_Charlie(NdotL, clampedNdotV, bsdfData.roughness);
        float Vis = saturate(V_Ashikhmin(lightData.NdotL, lightData.NdotVClamp));
        // Fabric are dieletric but we simulate forward scattering effect with colored specular (fuzz tint term)
        // We don't use Fresnel term for CharlieD
        float3 F = addSurfData.sheenColor;
        specTerm = F * Vis * D;
        diffTerm = FabricLambert(brdfData.roughness);
    #elif _FABRIC_SILK

        float TdotH = dot(brdfData.tangentWS, lightData.HalfDir);
        float TdotL = dot(brdfData.tangentWS, lightData.lightDir);
        float BdotH = dot(brdfData.bitangentWS, lightData.HalfDir);
        float BdotL = dot(brdfData.bitangentWS, lightData.lightDir);
        float TdotV = dot(brdfData.tangentWS, inputData.viewDirectionWS);
        float BdotV = dot(brdfData.bitangentWS, inputData.viewDirectionWS);

        float partLambdaV = GetSmithJointGGXAnisoPartLambdaV(TdotV, BdotV, lightData.NdotV, brdfData.roughnessT, brdfData.roughnessB);

        // TODO: Do comparison between this correct version and the one from isotropic and see if there is any visual difference
        // We use abs(NdotL) to handle the none case of double sided
        float DV = DV_SmithJointGGXAniso(   TdotH, BdotH, lightData.NdotH, lightData.NdotVClamp, TdotL, BdotL, abs(lightData.NdotL),
                                            brdfData.roughnessT, brdfData.roughnessB, partLambdaV);
        float3 F = F_SchlickSilk(brdfData.specular, lightData.LdotH);

        specTerm = F * DV;
        diffTerm = DisneyDiffuse(lightData.NdotVClamp, abs(lightData.NdotL), lightData.LdotV, brdfData.perceptualRoughness);
        //diffTerm = brdfData.diffuse;
    #endif

    // simulator BSDF
    diffR = diffTerm * brdfData.diffuse * lightData.NdotLClamp;
    diffT = diffTerm * brdfData.diffuse * flippedNdotL;
    specTerm *= lightData.NdotLClamp;
    float3 brdf = (diffR + specTerm) * lightData.lightColor * lightData.ShadowAttenuation;
    return brdf;
}

float3 FabricMainLightDirectLighting_Planar(FabricBRDFData brdfData, LightingAngle lightData)
{
    float3 diffuse = brdfData.albedo;
    float3 specular = 0;
    float3 brdf = (diffuse + specular) * lightData.lightColor * lightData.ShadowAttenuation;
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
float3 FernAdditionLightDirectLighting(FabricBRDFData brdfData, Varyings input, InputData inputData, FernAddInputData addInputData,
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
            LightingAngle lightingAngle = InitializeLightingAngle(light, input, addInputData.clearCoatNormalWS, inputData.normalWS, inputData.viewDirectionWS);
            float radiance = LightingRadiance(lightingAngle);
            // Additional Light Filter Referenced from https://github.com/unity3d-jp/UnityChanToonShaderVer2_Project
            float pureIntencity = max(0.001,(0.299 * lightingAngle.lightColor.r + 0.587 * lightingAngle.lightColor.g + 0.114 * lightingAngle.lightColor.b));
            //lightingAngle.lightColor = max(0, lerp(lightingAngle.lightColor, lerp(0, min(lightingAngle.lightColor, lightingAngle.lightColor / pureIntencity * _LightIntensityClamp), 1), _Is_Filter_LightColor));
            float3 addLightColor = FabricMainLightDirectLighting(brdfData, input, inputData, surfData, addSurfData, lightingAngle);
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
            LightingAngle lightingAngle = InitializeLightingAngle(light, input, addInputData.clearCoatNormalWS, inputData.normalWS, inputData.viewDirectionWS);
            float radiance = LightingRadiance(lightingAngle);
            // Additional Light Filter Referenced from https://github.com/unity3d-jp/UnityChanToonShaderVer2_Project
            float pureIntencity = max(0.001,(0.299 * lightingAngle.lightColor.r + 0.587 * lightingAngle.lightColor.g + 0.114 * lightingAngle.lightColor.b));
            //lightingAngle.lightColor = max(0, lerp(lightingAngle.lightColor, lerp(0, min(lightingAngle.lightColor, lightingAngle.lightColor / pureIntencity * _LightIntensityClamp), 1), _Is_Filter_LightColor));
            float3 addLightColor = FabricMainLightDirectLighting(brdfData, input, inputData, surfData, addSurfData, lightingAngle);
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
            LightingAngle lightingAngle = InitializeLightingAngle(light, input, addInputData.clearCoatNormalWS, inputData.normalWS, inputData.viewDirectionWS);
            float radiance = LightingRadiance(lightingAngle);
            // Additional Light Filter Referenced from https://github.com/unity3d-jp/UnityChanToonShaderVer2_Project
            float pureIntencity = max(0.001,(0.299 * lightingAngle.lightColor.r + 0.587 * lightingAngle.lightColor.g + 0.114 * lightingAngle.lightColor.b));
           // TODO: Add SG defined:
           // lightingAngle.lightColor = max(0, lerp(lightingAngle.lightColor, lerp(0, min(lightingAngle.lightColor, lightingAngle.lightColor / pureIntencity * _LightIntensityClamp), 1), _Is_Filter_LightColor));
            float3 addLightColor = FabricMainLightDirectLighting(brdfData, input, inputData, surfData, addSurfData, lightingAngle);
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

float3 NPRAdditionLightDirectLighting_Planar(FabricBRDFData brdfData, Varyings input, InputData inputData, FernAddInputData addInputData,
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
            LightingAngle lightingAngle = InitializeLightingAngle(light, input, addInputData.clearCoatNormalWS, inputData.normalWS, inputData.viewDirectionWS);
            float radiance = LightingRadiance(lightingAngle);
            // Additional Light Filter Referenced from https://github.com/unity3d-jp/UnityChanToonShaderVer2_Project
            float pureIntencity = max(0.001,(0.299 * lightingAngle.lightColor.r + 0.587 * lightingAngle.lightColor.g + 0.114 * lightingAngle.lightColor.b));
            //lightingAngle.lightColor = max(0, lerp(lightingAngle.lightColor, lerp(0, min(lightingAngle.lightColor, lightingAngle.lightColor / pureIntencity * _LightIntensityClamp), 1), _Is_Filter_LightColor));
            float3 addLightColor = FabricMainLightDirectLighting_Planar(brdfData, lightingAngle);
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
            LightingAngle lightingAngle = InitializeLightingAngle(light, input, addInputData.clearCoatNormalWS, inputData.normalWS, inputData.viewDirectionWS);
            float radiance = LightingRadiance(lightingAngle);
            // Additional Light Filter Referenced from https://github.com/unity3d-jp/UnityChanToonShaderVer2_Project
            float pureIntencity = max(0.001,(0.299 * lightingAngle.lightColor.r + 0.587 * lightingAngle.lightColor.g + 0.114 * lightingAngle.lightColor.b));
            //lightingAngle.lightColor = max(0, lerp(lightingAngle.lightColor, lerp(0, min(lightingAngle.lightColor, lightingAngle.lightColor / pureIntencity * _LightIntensityClamp), 1), _Is_Filter_LightColor));
            float3 addLightColor = FabricMainLightDirectLighting_Planar(brdfData, lightingAngle);
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
            LightingAngle lightingAngle = InitializeLightingAngle(light, input, addInputData.clearCoatNormalWS, inputData.normalWS, inputData.viewDirectionWS);
            float radiance = LightingRadiance(lightingAngle);
            // Additional Light Filter Referenced from https://github.com/unity3d-jp/UnityChanToonShaderVer2_Project
            float pureIntencity = max(0.001,(0.299 * lightingAngle.lightColor.r + 0.587 * lightingAngle.lightColor.g + 0.114 * lightingAngle.lightColor.b));
           // TODO: Add SG defined:
           // lightingAngle.lightColor = max(0, lerp(lightingAngle.lightColor, lerp(0, min(lightingAngle.lightColor, lightingAngle.lightColor / pureIntencity * _LightIntensityClamp), 1), _Is_Filter_LightColor));
            float3 addLightColor = FabricMainLightDirectLighting_Planar(brdfData, lightingAngle);
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

// Computes the specular term for EnvironmentBRDF
float3 EnvironmentFabricBRDFSpecular(FabricBRDFData brdfData, float fresnelTerm)
{
    float surfaceReduction = 1.0 / (brdfData.roughness2 + 1.0);
    return float3(surfaceReduction * lerp(brdfData.specular, brdfData.grazingTerm, fresnelTerm));
}

float3 EnvironmentFabricBRDF(FabricBRDFData brdfData, float3 indirectDiffuse, float3 indirectSpecular, float fresnelTerm)
{
    float3 c = indirectDiffuse * brdfData.diffuse;
    c += indirectSpecular * EnvironmentFabricBRDFSpecular(brdfData, fresnelTerm);
    return c;
}


float3 FernIndirectLighting(FabricBRDFData brdfData, float clearCoatMask, InputData inputData, FernAddInputData addInputData, Varyings input, FernSGAddSurfaceData addSurfData, float occlusion)
{
    float3 indirectDiffuse = inputData.bakedGI * occlusion;
    float3 normalWS = inputData.normalWS;
    #if _FABRIC_SILK 
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
    float3 indirectSpecular = 0;
    #if _ENVDEFAULT
        indirectSpecular = NPRGlossyEnvironmentReflection(reflectVector, inputData.positionWS, inputData.normalizedScreenSpaceUV, brdfData.perceptualRoughness, occlusion) * addSurfData.envSpecularIntensity;
    #elif _ENVCUSTOM
        indirectSpecular = NPRGlossyEnvironmentReflection_Custom(addSurfData.envCustomReflection, occlusion) * addSurfData.envSpecularIntensity;
    #else
        indirectSpecular = _GlossyEnvironmentColor.rgb * occlusion;
    #endif
    
    //float3 hso = GetHorizonOcclusion(inputData.viewDirectionWS, normalWS, input.normalWS, 4);
    
    float3 indirectColor = EnvironmentFabricBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);

    #if _MATCAP
        float3 matCap = SamplerMatCap(_MatCapColor, input.uv.zw, normalWS, inputData.normalizedScreenSpaceUV, TEXTURE2D_ARGS(_MatCapTex, sampler_MatCapTex));
        indirectColor += lerp(matCap, matCap * brdfData.diffuse, _MatCapAlbedoWeight);
    #endif
    
    return indirectColor;
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

    // Init AddSurfaceData
    FernSGAddSurfaceData addSurfData = (FernSGAddSurfaceData)0;
    #if _FABRIC_COTTON_WOOL
        addSurfData.anisotropy = 0;
        surfData.smoothness = lerp(0.0h, 0.6h, surfData.smoothness);
        addSurfData.sheenColor = surfaceDescription.SheenColor;
    #elif _FABRIC_SILK
        addSurfData.anisotropy = surfaceDescription.Anisotropy;
    #endif
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

    AmbientOcclusionFactor aoFactor = GetScreenSpaceAmbientOcclusion(inputData.normalizedScreenSpaceUV);
    uint meshRenderingLayers = GetMeshRenderingLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    FabricBRDFData brdfData;
    InitializeFabricBRDFData(surfData, addSurfData.anisotropy, inputData.normalWS, addInputData.tangentWS, brdfData);

    LightingAngle lightingAngle = InitializeLightingAngle(mainLight, unpacked, addInputData.clearCoatNormalWS, inputData.normalWS, inputData.viewDirectionWS);
    float radiance = LightingRadiance(lightingAngle);
    
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

        BRDFData brdfData_Debug;
        brdfData_Debug = InitializeFabricDebugBRDFData(brdfData);
    
        if (CanDebugOverrideOutputColor(inputData, surface_data, brdfData_Debug, debugColor))
        {
            outColor = debugColor;
            return;
        }
    #endif

    LightingData lightingData = CreateLightingData(inputData, surfData);
    
    #ifdef _LIGHT_LAYERS
    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    #endif
    {
        lightingData.mainLightColor = FabricMainLightDirectLighting(brdfData, unpacked, inputData, surfData, addSurfData, lightingAngle);
    }
    lightingData.additionalLightsColor = FernAdditionLightDirectLighting(brdfData, unpacked, inputData, addInputData, surfData, shadowMask, meshRenderingLayers, addSurfData, aoFactor);
    lightingData.giColor = FernIndirectLighting(brdfData, surfData.clearCoatMask, inputData, addInputData, unpacked, addSurfData, surfData.occlusion);
    lightingData.emissionColor = surfData.emission;
    
    // lightingData.emissionColor = 0;
    // lightingData.additionalLightsColor = 0;
    // lightingData.vertexLightingColor = 0;
    // lightingData.giColor = 0;
    
    outColor.rgb = CalculateFinalColor(lightingData, surfData.alpha).rgb;
    outColor.a = OutputAlpha(surfData.alpha, isTransparent);

#ifdef _WRITE_RENDERING_LAYERS
    uint renderingLayers = GetMeshRenderingLayer();
    outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
#endif
}

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

    // Init AddSurfaceData
    FernSGAddSurfaceData addSurfData = (FernSGAddSurfaceData)0;

    #if _FABRIC_COTTON_WOOL
        addSurfData.anisotropy = 0;
        surfData.smoothness = lerp(0.0h, 0.6h, surfData.smoothness);
        addSurfData.sheenColor = surfaceDescription.SheenColor;
    #elif _FABRIC_SILK
        addSurfData.anisotropy = surfaceDescription.Anisotropy;
    #endif
    
    #if _RAMPSHADING
        addSurfData.rampColor = surfaceDescription.RampColor;
    #endif
    #if _STYLIZED
        addSurfData.coatTint = surfaceDescription.ClearCoatTint;
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
    #if !_RAMPSHADING
        addSurfData.darkColor = surfaceDescription.DarkColor;
        addSurfData.lightenColor = surfaceDescription.LightenColor;
    #endif

    surfData.albedo = AlphaModulate(surfData.albedo, surfData.alpha);

    InputData inputData;
    FernAddInputData addInputData;
    InitializeInputData(unpacked, surfaceDescription, addSurfData, addInputData, inputData);

#ifdef _DBUFFER
    ApplyDecalToSurfaceData(unpacked.positionCS, surface, inputData);
#endif

    float4 shadowMask = CalculateShadowMask(inputData);

    AmbientOcclusionFactor aoFactor = GetScreenSpaceAmbientOcclusion(inputData.normalizedScreenSpaceUV);
    uint meshRenderingLayers = GetMeshRenderingLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    FabricBRDFData brdfData;
    InitializeFabricBRDFData(surfData, addSurfData.anisotropy, inputData.normalWS, addInputData.tangentWS, brdfData);
    
    LightingAngle lightingAngle = InitializeLightingAngle(mainLight, unpacked, addInputData.clearCoatNormalWS, inputData.normalWS, inputData.viewDirectionWS);
    float radiance = LightingRadiance(lightingAngle);
    
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

        BRDFData brdfData_debug = InitializeFabricDebugBRDFData(brdfData);
    
        if (CanDebugOverrideOutputColor(inputData, surface_data, brdfData_debug, debugColor))
        {
            outColor = debugColor;
            return;
        }
    #endif

    LightingData lightingData = CreateLightingData(inputData, surfData);
    
    #ifdef _LIGHT_LAYERS
    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    #endif
    {
       lightingData.mainLightColor = FabricMainLightDirectLighting_Planar(brdfData, lightingAngle);
    }
    lightingData.additionalLightsColor = NPRAdditionLightDirectLighting_Planar(brdfData, unpacked, inputData, addInputData, surfData, shadowMask, meshRenderingLayers, addSurfData, aoFactor);
    lightingData.giColor = FernIndirectLighting(brdfData, surfData.clearCoatMask, inputData, addInputData, unpacked, addSurfData, surfData.occlusion);
    lightingData.emissionColor = surfData.emission;

    outColor.rgb =  CalculateFinalColor(lightingData, surfData.alpha).rgb;
    outColor.a = OutputAlpha(surfData.alpha, isTransparent);

#ifdef _WRITE_RENDERING_LAYERS
    uint renderingLayers = GetMeshRenderingLayer();
    outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
#endif
}
