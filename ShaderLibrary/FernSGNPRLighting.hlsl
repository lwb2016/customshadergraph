#ifndef UNIVERSAL_LIGHTING_INCLUDED
#define UNIVERSAL_LIGHTING_INCLUDED

#include "NPRInput.hlsl"
#include "FernSGSurfaceData.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "RealtimeLights.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/BSDF.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"
#include "FernBxDF.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Debug/Debugging3D.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/AmbientOcclusion.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
#include "LightingCommon.hlsl"
#include "DeclareDepthShadowTexture.hlsl"
#include "NPRUtils.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/AreaLighting.hlsl"

#define PI8 25.1327
#define INV_PI8 0.039789
#define UNITY_PI 3.14159265358979323846
// 15 degrees
#define TRANSMISSION_WRAP_ANGLE (PI/12)
#define TRANSMISSION_WRAP_LIGHT cos(PI/2 - TRANSMISSION_WRAP_ANGLE)

#if defined(LIGHTMAP_ON)
    #define DECLARE_LIGHTMAP_OR_SH(lmName, shName, index) float2 lmName : TEXCOORD##index
    #define OUTPUT_LIGHTMAP_UV(lightmapUV, lightmapScaleOffset, OUT) OUT.xy = lightmapUV.xy * lightmapScaleOffset.xy + lightmapScaleOffset.zw;
    #define OUTPUT_SH(normalWS, OUT)
#else
    #define DECLARE_LIGHTMAP_OR_SH(lmName, shName, index) float3 shName : TEXCOORD##index
    #define OUTPUT_LIGHTMAP_UV(lightmapUV, lightmapScaleOffset, OUT)
    #define OUTPUT_SH(normalWS, OUT) OUT.xyz = SampleSHVertex(normalWS)
#endif

#if FACE
CBUFFER_START(SDFFaceObjectToWorld)
    float4x4 _FaceObjectToWorld;
CBUFFER_END
#endif

// Global Property
float4 _DepthTextureSourceSize;
float _CameraAspect;
float _CameraFOV;

///////////////////////////////////////////////////////////////////////////////
//                          Lighting Data                                    //
///////////////////////////////////////////////////////////////////////////////

#if _AREALIGHT

struct SimpleAreaLight
{
    float4 lightColor;
    // calculated specular area lighting direction
    float3 specLightDir;
    // calculateddiffuse area lighting direction
    float3 diffLightDir;
    // calculated specular lighting normalization factor
    float3 positionWS;
    float energy;
};

SimpleAreaLight GetSimpleAreaLight(uint i)
{
    #if USE_FORWARD_PLUS
        int lightIndex = i;
    #else
        int lightIndex = GetPerObjectLightIndex(i);
    #endif

    #if USE_STRUCTURED_BUFFER_FOR_LIGHT_DATA
        float4 lightPositionWS = _AdditionalLightsBuffer[lightIndex].position;
        float3 color = _AdditionalLightsBuffer[lightIndex].color.rgb;
        float4 distanceAndSpotAttenuation = _AdditionalLightsBuffer[lightIndex].attenuation;
        float4 spotDirection = _AdditionalLightsBuffer[lightIndex].spotDirection;
        uint lightLayerMask = _AdditionalLightsBuffer[lightIndex].layerMask;
    #else
        float4 lightPositionWS = _AdditionalLightsPosition[lightIndex];
        float3 color = _AdditionalLightsColor[lightIndex].rgb;
        float4 distanceAndSpotAttenuation = _AdditionalLightsAttenuation[lightIndex];
        float4 spotDirection = _AdditionalLightsSpotDir[lightIndex];
        uint lightLayerMask = asuint(_AdditionalLightsLayerMasks[lightIndex]);
    #endif

    SimpleAreaLight simpleAreaLight = (SimpleAreaLight)0;
    simpleAreaLight.lightColor =  _AdditionalLightsColor[lightIndex];
    simpleAreaLight.positionWS = lightPositionWS.xyz;
    return simpleAreaLight;
}

void Lux_CalcTubeLightToLight (
    inout SimpleAreaLight areaLight, 
    float3 worldPos,
    float3 lightPos,
    float3 eyeVec,
    float3 normal,
    float tubeRad,
    float lightLength,
    float3 lightDir,
    float3 lightAxisX,
    float roughness)
{

    float3 viewDir = -eyeVec;
    float3 r = reflect (viewDir, normal);

    float normalization = 1.0;
    float3 L = lightPos - worldPos;
    float invDistToLight = rsqrt(dot(L, L));

    float3 tubeStart = lightPos + lightAxisX * lightLength;
    float3 tubeEnd = lightPos - lightAxisX * lightLength;

    //	///////////////
    // 	Length
    //  Energy conservation
    //	We do not reduce energy according to length here
    //	float lineAngle = saturate( lightLength * invDistToLight );
    //	normalization = roughness / saturate( roughness + 0.5 * lineAngle );

    float3 L0 = tubeStart - worldPos;
    float3 L1 = tubeEnd - worldPos;
    float3 Ld = L1 - L0;
    float RoL0 = dot( r, L0 );
    float RoLd = dot( r, Ld );
    float L0oLd = dot( L0, Ld);
    float t = (RoL0 * RoLd - L0oLd) / (dot(Ld, Ld) - RoLd * RoLd);
    float3 closestPoint	= L0 + Ld * saturate(t);
    areaLight.specLightDir  = closestPoint;
    return;
	
    //	///////////////
    // 	Radius
    // Energy conservation
    float sphereAngle = saturate(tubeRad * invDistToLight);
    float m_square = roughness / saturate(roughness + 0.5 * sphereAngle);
    normalization *= m_square * m_square; 
	
    float3 centerToRay	= dot(closestPoint, r) * r - closestPoint;
    closestPoint = closestPoint + centerToRay * saturate(tubeRad * rsqrt(dot(centerToRay, centerToRay)));

    float3 diffLightDir = L - clamp(dot(L, lightAxisX), -lightLength, lightLength) * lightAxisX;
    float invDistToDiffLightDir = rsqrt(dot(diffLightDir, diffLightDir));
	
    areaLight.specLightDir = normalize(closestPoint);
    areaLight.diffLightDir = diffLightDir * invDistToDiffLightDir;
    areaLight.energy = normalization;
}

// Baum's equation
// Expects non-normalized vertex positions
float PolygonRadiance(float4x3 L)
{
	// detect clipping config	
	uint config = 0;
	if (L[0].z > 0) config += 1;
	if (L[1].z > 0) config += 2;
	if (L[2].z > 0) config += 4;
	if (L[3].z > 0) config += 8;


	// The fifth vertex for cases when clipping cuts off one corner.
	// Due to a compiler bug, copying L into a vector array with 5 rows
	// messes something up, so we need to stick with the matrix + the L4 vertex.
	float3 L4 = L[3];

	// This switch is surprisingly fast. Tried replacing it with a lookup array of vertices.
	// Even though that replaced the switch with just some indexing and no branches, it became
	// way, way slower - mem fetch stalls?

	// clip
	uint n = 0;
	switch(config)
	{
		case 0: // clip all
			break;
			
		case 1: // V1 clip V2 V3 V4
			n = 3;
			L[1] = -L[1].z * L[0] + L[0].z * L[1];
			L[2] = -L[3].z * L[0] + L[0].z * L[3];
			break;
			
		case 2: // V2 clip V1 V3 V4
			n = 3;
			L[0] = -L[0].z * L[1] + L[1].z * L[0];
			L[2] = -L[2].z * L[1] + L[1].z * L[2];
			break;
			
		case 3: // V1 V2 clip V3 V4
			n = 4;
			L[2] = -L[2].z * L[1] + L[1].z * L[2];
			L[3] = -L[3].z * L[0] + L[0].z * L[3];
			break;
			
		case 4: // V3 clip V1 V2 V4
			n = 3;	
			L[0] = -L[3].z * L[2] + L[2].z * L[3];
			L[1] = -L[1].z * L[2] + L[2].z * L[1];				
			break;
			
		case 5: // V1 V3 clip V2 V4: impossible
			break;
			
		case 6: // V2 V3 clip V1 V4
			n = 4;
			L[0] = -L[0].z * L[1] + L[1].z * L[0];
			L[3] = -L[3].z * L[2] + L[2].z * L[3];			
			break;
			
		case 7: // V1 V2 V3 clip V4
			n = 5;
			L4 = -L[3].z * L[0] + L[0].z * L[3];
			L[3] = -L[3].z * L[2] + L[2].z * L[3];
			break;
			
		case 8: // V4 clip V1 V2 V3
			n = 3;
			L[0] = -L[0].z * L[3] + L[3].z * L[0];
			L[1] = -L[2].z * L[3] + L[3].z * L[2];
			L[2] =  L[3];
			break;
			
		case 9: // V1 V4 clip V2 V3
			n = 4;
			L[1] = -L[1].z * L[0] + L[0].z * L[1];
			L[2] = -L[2].z * L[3] + L[3].z * L[2];
			break;
			
		case 10: // V2 V4 clip V1 V3: impossible
			break;
			
		case 11: // V1 V2 V4 clip V3
			n = 5;
			L[3] = -L[2].z * L[3] + L[3].z * L[2];
			L[2] = -L[2].z * L[1] + L[1].z * L[2];			
			break;
			
		case 12: // V3 V4 clip V1 V2
			n = 4;
			L[1] = -L[1].z * L[2] + L[2].z * L[1];
			L[0] = -L[0].z * L[3] + L[3].z * L[0];
			break;
			
		case 13: // V1 V3 V4 clip V2
			n = 5;
			L[3] = L[2];
			L[2] = -L[1].z * L[2] + L[2].z * L[1];
			L[1] = -L[1].z * L[0] + L[0].z * L[1];
			break;
			
		case 14: // V2 V3 V4 clip V1
			n = 5;
			L4 = -L[0].z * L[3] + L[3].z * L[0];
			L[0] = -L[0].z * L[1] + L[1].z * L[0];
			break;
			
		case 15: // V1 V2 V3 V4
			n = 4;
			break;
	}

	if (n == 0)
		return 0;

	// normalize
	L[0] = normalize(L[0]);
	L[1] = normalize(L[1]);
	L[2] = normalize(L[2]);
	if(n == 3)
		L[3] = L[0];
	else
	{
		L[3] = normalize(L[3]);
		if (n == 4)
			L4 = L[0];
		else
			L4 = normalize(L4);
	}
	
	// integrate
	float sum = 0;
	sum += IntegrateEdge(L[0], L[1]);
	sum += IntegrateEdge(L[1], L[2]);
	sum += IntegrateEdge(L[2], L[3]);
	if(n >= 4)	
		sum += IntegrateEdge(L[3], L4);
	if(n == 5)
		sum += IntegrateEdge(L4, L[0]);
	
	sum *= 0.15915; // 1/2pi

	return max(0, sum);
}

float TransformedPolygonRadiance(float4x3 L, float2 uv, sampler2D transformInv, float amplitude)
{
    // Get the inverse LTC matrix M
    float3x3 Minv = 0;
    Minv._m22 = 1;
    Minv._m00_m02_m11_m20 = tex2D(transformInv, uv);

    // Transform light vertices into diffuse configuration
    float4x3 LTransformed = mul(L, Minv);

    // Polygon radiance in transformed configuration - specular
    return PolygonIrradiance(LTransformed) * amplitude;
}

//Test Area Lights
sampler2D _AmpDiffAmpSpecFresnel;
sampler2D _TransformInv_Diffuse;
sampler2D _TransformInv_Specular;
float3 CalculateAreaLight (LitProBRDFData brdfData, LitProBRDFData brdfDataClearCoat,
    float coatSpecularIntensity, float coatMask, float3 specularColor, 
    float3 position, float3 N, float3 viewWS,  Light_Area light_area)
{
    float shadow = 0;
    float3 result = 0;

    float3 unL = light_area.positionWS.rgb - position;

    if (dot(light_area.Forward, unL) < FLT_EPS)
    {
        float floatWidth  = light_area.LightVerts[0][3] * 0.5;
        float floatHeight = light_area.LightVerts[1][3] * 0.5;
        float range = light_area.LightVerts[2][3];
        float3 invHalfDim = rcp(float3(range + floatWidth,
                                        range + floatHeight,
                                        range));
        float intensity = EllipsoidalDistanceAttenuation(unL, invHalfDim,
                                                    range,
                                                    1);
        
        // TODO: larger and smaller values cause artifacts - why?
        float roughness = lerp(0.1f, 0.95f, brdfData.perceptualRoughness);

        // Construct orthonormal basis around N, aligned with V
        float3x3 basis;
        basis[0] = normalize(viewWS - N * dot(viewWS, N));
        basis[1] = normalize(cross(N, basis[0]));
        basis[2] = N;

        // Transform light vertices into that space
        float4x3 L;
        L = light_area.LightVerts - float4x3(position, position, position, position);
        L = mul(L, transpose(basis));

        // UVs for sampling the LUTs
        float theta = acos(dot(viewWS, N));
        float2 uv = float2(roughness, theta/1.57);

        float3 AmpDiffAmpSpecFresnel = tex2D(_AmpDiffAmpSpecFresnel, uv).rgb;
        float diffuseTerm = TransformedPolygonRadiance(L, uv, _TransformInv_Diffuse, AmpDiffAmpSpecFresnel.x);
        result = diffuseTerm * brdfData.diffuse;

        float specularTerm = TransformedPolygonRadiance(L, uv, _TransformInv_Specular, AmpDiffAmpSpecFresnel.y);
        float3 fresnelTerm = brdfData.specular + (1.0 - brdfData.specular) * AmpDiffAmpSpecFresnel.z;
        result += max(0.0001f, specularTerm * fresnelTerm * PI * specularColor);

        #if defined(_CLEARCOAT) || defined(_CLEARCOATMAP)
            float roughnessCoat = lerp(0.1f, 0.98f, brdfDataClearCoat.perceptualRoughness);
            float2 uvCoat = float2(roughnessCoat, theta/1.57);
            float specularTermCoat = TransformedPolygonRadiance(L, uvCoat, _TransformInv_Specular, AmpDiffAmpSpecFresnel.y);
            float3 fresnelTermCoat = brdfDataClearCoat.specular + (1.0 - brdfDataClearCoat.specular) * AmpDiffAmpSpecFresnel.z;
            float3 specularCoat = kDielectricSpec.x * max(0.0001f, fresnelTermCoat * specularTermCoat * PI) * coatSpecularIntensity;
            float3 coatFresnel = kDielectricSpec.x + kDielectricSpec.a * fresnelTerm;
            float3 diffuseCoat = result *  (1.0 - coatMask * coatFresnel);
            result = diffuseCoat + specularCoat * coatMask;
        #endif
        result *= intensity * light_area.LightColor.rgb;
    }

    return result;
}
#endif
struct LightingData
{
    float3 giColor;
    float3 mainLightColor;
    float3 additionalLightsColor;
    float3 vertexLightingColor;
    float3 emissionColor;
};

LightingData CreateLightingData(InputData inputData, FernSurfaceData surfaceData)
{
    LightingData lightingData;

    lightingData.giColor = inputData.bakedGI;
    lightingData.emissionColor = surfaceData.emission;
    lightingData.vertexLightingColor = 0;
    lightingData.mainLightColor = 0;
    lightingData.additionalLightsColor = 0;

    return lightingData;
}


float3 CalculateLightingColor(LightingData lightingData, float3 albedo)
{
    float3 lightingColor = 0;

    if (IsOnlyAOLightingFeatureEnabled())
    {
        return lightingData.giColor; // Contains white + AO
    }

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_GLOBAL_ILLUMINATION))
    {
        lightingColor += lightingData.giColor;
    }

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_MAIN_LIGHT))
    {
        lightingColor += lightingData.mainLightColor;
    }

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_ADDITIONAL_LIGHTS))
    {
        lightingColor += lightingData.additionalLightsColor;
    }

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_VERTEX_LIGHTING))
    {
        lightingColor += lightingData.vertexLightingColor;
    }

    lightingColor *= albedo;

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_EMISSION))
    {
        lightingColor += lightingData.emissionColor;
    }

    return lightingColor;
}

float4 CalculateFinalColor(LightingData lightingData, float alpha)
{
    float3 finalColor = CalculateLightingColor(lightingData, 1);

    return float4(finalColor, alpha);
}

float3 RotateAroundYInDegrees (float3 vertex, float degrees)
{
    float alpha = degrees * UNITY_PI / 180.0;
    float sina, cosa;
    sincos(alpha, sina, cosa);
    float2x2 m = float2x2(cosa, -sina, sina, cosa);
    return float3(mul(m, vertex.xz), vertex.y).xzy;
}

/**
 * \brief DepthUV For Rim Or Shadow
 * \param offset 
 * \param reverseX usually use directional light's dir, but sometime need x reverse
 * \param positionCSXY 
 * \param mainLightDir 
 * \param depthTexWH 
 * \param addInputData 
 * \return 
 */
inline int2 GetDepthUVOffset(float offset, float reverseX, float2 positionCSXY, float3 mainLightDir, float2 depthTexWH, FernAddInputData addInputData)
{
    // 1 / depth when depth < 1 is wrong, this is like point light attenuation
    // 0.5625 is aspect, hard code for now
    // 0.333 is fov, hard code for now
    float2 UVOffset = _CameraAspect * (offset * _CameraFOV / (1 + addInputData.linearEyeDepth)); 
    float2 mainLightDirVS = TransformWorldToView(mainLightDir).xy;
    mainLightDirVS.x *= lerp(1, -1, reverseX);
    UVOffset = mainLightDirVS * UVOffset;
    float2 downSampleFix = _DepthTextureSourceSize.zw / depthTexWH.xy;
    int2 loadTexPos = positionCSXY / downSampleFix + UVOffset * depthTexWH.xy;
    loadTexPos = min(loadTexPos, depthTexWH.xy-1);
    return loadTexPos;
}

inline float DepthShadow(float depthShadowOffset, float reverseX, float depthShadowThresoldOffset, float depthShadowSoftness, float2 positionCSXY, float3 mainLightDir, FernAddInputData addInputData)
{
    int2 loadPos = GetDepthUVOffset(depthShadowOffset, reverseX, positionCSXY, mainLightDir, _CameraDepthShadowTexture_TexelSize.zw, addInputData);
    float depthShadowTextureValue = LoadSceneDepthShadow(loadPos);
    float depthTextureLinearDepth = DepthSamplerToLinearDepth(depthShadowTextureValue);
    float depthTexShadowDepthDiffThreshold = 0.025f + depthShadowThresoldOffset;

    float depthShadow = saturate((depthTextureLinearDepth - (addInputData.linearEyeDepth - depthTexShadowDepthDiffThreshold)) * 50 / depthShadowSoftness);
    return depthShadow;
}

inline float DepthRim(float depthRimOffset, float reverseX, float rimDepthDiffThresholdOffset, float2 positionCSXY, float3 mainLightDir, FernAddInputData addInputData)
{
    int2 loadPos = GetDepthUVOffset(depthRimOffset, reverseX, positionCSXY, mainLightDir,  _DepthTextureSourceSize.zw, addInputData);
    float depthTextureValue = LoadSceneDepth(loadPos);
    float depthTextureLinearDepth = DepthSamplerToLinearDepth(depthTextureValue);
    
    float threshold = saturate(0.1 + rimDepthDiffThresholdOffset);
    float depthRim = saturate((depthTextureLinearDepth - (addInputData.linearEyeDepth + threshold)) * 5);
    depthRim = lerp(0, depthRim, addInputData.linearEyeDepth);
    return depthRim;
}

struct LightingAngle
{
    float3 lightColor;
    float3 HalfDir;
    float3 lightDir;
    float HalfLambert;
    float NdotL;
    float NdotV;

    // Clamp
    float LdotHClamp;
    float VdotHClamp;
    float NdotLClamp;
    float NdotHClamp;
    float NdotVClamp;
    
    // Shadow
    float ShadowAttenuation;

    //#if _FABRIC_COTTON_WOOL || _FABRIC_SILK || _ANISO
        float LdotV;
        float NdotH;
        float LdotH;
        float invLenLV;
    //#endif

    //#if _CLEARCOATNORMAL
        float HalfLambert_ClearCoat;
        float NdotL_ClearCoat;
        float NdotLClamp_ClearCoat;
        float NdotHClamp_ClearCoat;
        float NdotVClamp_ClearCoat;
    //#endif
};


///////////////////////////////////////////////////////////////////////////////
//                      Lighting Functions                                   //
///////////////////////////////////////////////////////////////////////////////

#if FACE
inline void SDFFaceUV(float reversal, float faceArea, out float2 result)
    {
        Light mainLight = GetMainLight();
        float2 lightDir = normalize(mainLight.direction.xz);

        float2 Front = normalize(_FaceObjectToWorld._13_33);
        float2 Right = normalize(_FaceObjectToWorld._11_31);

        float FdotL = dot(Front, lightDir);
        float RdotL = dot(Right, lightDir) * lerp(1, -1, reversal);
        result.x = 1 - max(0,-(acos(FdotL) * INV_PI * 90.0 /(faceArea+90.0) -0.5) * 2);
        result.y = 1 - 2 * step(RdotL, 0);
    }

    inline float3 SDFFaceDiffuse(float4 uv, LightingAngle lightData, float SDFShadingSoftness, float3 highColor, float3 darkColor, TEXTURE2D_X_PARAM(_SDFFaceTex, sampler_SDFFaceTex))
    {
        float FdotL = uv.z;
        float sign = uv.w;
        float SDFMap = SAMPLE_TEXTURE2D(_SDFFaceTex, sampler_SDFFaceTex, uv.xy * float2(-sign, 1)).r;
        //float diffuseRadiance = saturate((abs(FdotL) - SDFMap) * SDFShadingSoftness * 500);
        float diffuseRadiance = smoothstep(-SDFShadingSoftness * 0.1, SDFShadingSoftness * 0.1, (abs(FdotL) - SDFMap)) * lightData.ShadowAttenuation;
        float3 diffuseColor = lerp(darkColor.rgb, highColor.rgb, diffuseRadiance);
        return diffuseColor;
    }
    #endif

inline void NPRMainLightCorrect(float lightDirectionObliqueWeight, inout Light mainLight)
{
    #if FACE
        mainLight.direction.y = lerp(mainLight.direction.y, 0, lightDirectionObliqueWeight);
        mainLight.direction = normalize(mainLight.direction);
    #endif
}

// float3 LightingLambert(float3 lightColor, float3 lightDir, float3 normal)
// {
//     float NdotL = saturate(dot(normal, lightDir));
//     return lightColor * NdotL;
// }

float3 VertexLighting(float3 positionWS, float3 normalWS)
{
    float3 vertexLightColor = float3(0.0, 0.0, 0.0);

#ifdef _ADDITIONAL_LIGHTS_VERTEX
    uint lightsCount = GetAdditionalLightsCount();
    LIGHT_LOOP_BEGIN(lightsCount)
        Light light = GetAdditionalLight(lightIndex, positionWS);
        float3 lightColor = light.color * light.distanceAttenuation;
        vertexLightColor += LightingLambert(lightColor, light.direction, normalWS);
    LIGHT_LOOP_END
#endif

    return vertexLightColor;
}

float LightingRadiance(LightingAngle lightingData)
{
    float radiance = lightingData.NdotLClamp * lightingData.ShadowAttenuation;
    return radiance;
}

/**
 * \brief Get Cell Shading Radiance
 * \param radiance 
 * \param shadowThreshold 
 * \param shadowSmooth 
 * \param diffuse [Out]
 */
inline float3 CellShadingDiffuse(inout float radiance, float cellThreshold, float cellSmooth, float3 lightenColor, float3 darkColor)
{
    float3 diffuse = 0;
    //cellSmooth *= 0.5;
    radiance = saturate(1 + (radiance - cellThreshold - cellSmooth) / max(cellSmooth, 1e-3));
    // 0.5 cellThreshold 0.5 smooth = Lambert
    //radiance = LinearStep(cellThreshold - cellSmooth, cellThreshold + cellSmooth, radiance);
    diffuse = lerp(darkColor.rgb, lightenColor.rgb, radiance);
    return diffuse;
}

inline float3 CellBandsShadingDiffuse(inout float radiance, float cellThreshold, float cellBandSoftness, float cellBands, float3 highColor, float3 darkColor)
{
    float3 diffuse = 0;
    //cellSmooth *= 0.5;
    radiance = saturate(1 + (radiance - cellThreshold - cellBandSoftness) / max(cellBandSoftness, 1e-3));
    // 0.5 cellThreshold 0.5 smooth = Lambert
    //radiance = LinearStep(cellThreshold - cellSmooth, cellThreshold + cellSmooth, radiance);

    #if _CELLBANDSHADING
        float bandsSmooth = cellBandSoftness;
        radiance = saturate((LinearStep(0.5 - bandsSmooth, 0.5 + bandsSmooth, frac(radiance * cellBands)) + floor(radiance * cellBands)) / cellBands);
    #endif

    diffuse = lerp(darkColor.rgb, highColor.rgb, radiance);
    return diffuse;
}

inline float3 RampShadingDiffuse(float radiance, float rampVOffset, float uOffset, TEXTURE2D_PARAM(rampMap, sampler_rampMap))
{
    float3 diffuse = 0;
    float2 uv = float2(saturate(radiance + uOffset), rampVOffset);
    diffuse = SAMPLE_TEXTURE2D(rampMap, sampler_rampMap, uv).rgb;
    return diffuse;
}

float GGXDirectBRDFSpecular(LitProBRDFData brdfData, float3 LoH, float3 NoH, float3 NoHClearCoat)
{
    #if _CLEARCOATNORMAL
        float d = NoHClearCoat.x * NoHClearCoat.x * brdfData.roughness2MinusOne + 1.00001f;
    #else
        float d = NoH.x * NoH.x * brdfData.roughness2MinusOne + 1.00001f;
    #endif
    float LoH2 = LoH.x * LoH.x;
    float specularTerm = brdfData.roughness2 / ((d * d) * max(0.1h, LoH2) * brdfData.normalizationTerm);

    #if REAL_IS_HALF
        specularTerm = specularTerm - HALF_MIN;
        specularTerm = clamp(specularTerm, 0.0, 100.0); // Prevent FP16 overflow on mobiles
    #endif

    return specularTerm;
}

float3 StylizedSpecular(float3 albedo, float ndothClamp, float specularSize, float specularSoftness)
{
    float specSize = 1 - (specularSize * specularSize);
    float ndothStylized = (ndothClamp - specSize * specSize) / (1 - specSize);
    float3 specular = LinearStep(0, specularSoftness, ndothStylized);
    return specular;
}

float BlinnPhongSpecular(float shininess, float ndoth)
{
    float phongSmoothness = exp2(10 * shininess + 1);
    float normalize = (phongSmoothness + 7) * INV_PI8; // bling-phong 能量守恒系数
    float specular = max(pow(ndoth, phongSmoothness) * normalize, 0.001);
    return specular;
}

real3 F_SchlickSilk(real3 f0, real f90, real u)
{
    real x = 1.0 - u;
    real x2 = x * x;
    real x5 = x * x2 * x2;
    return f0 * (1.0 - x5) + (f90 * x5);        // sub mul mul mul sub mul mad*3
}

real3 F_SchlickSilk(real3 f0, real u)
{
    return F_SchlickSilk(f0, 1.0, u);               // sub mul mul mul sub mad*3
}

inline float3 AnisotropyDoubleSpecular(BRDFData brdfData, float2 uv, float4 tangentWS, InputData inputData, LightingAngle lightingData,
    AnisoSpecularData anisoSpecularData, TEXTURE2D_PARAM(anisoDetailMap, sampler_anisoDetailMap))
{
    float specMask = 1; // TODO ADD Mask
    float4 detailNormal = SAMPLE_TEXTURE2D(anisoDetailMap,sampler_anisoDetailMap, uv);

    float2 jitter =(detailNormal.y-0.5) * float2(anisoSpecularData.spread1,anisoSpecularData.spread2);

    float sgn = tangentWS.w;
    float3 T = normalize(sgn * cross(inputData.normalWS.xyz, tangentWS.xyz));
    //float3 T = normalize(tangentWS.xyz);

    float3 t1 = ShiftTangent(T, inputData.normalWS.xyz, anisoSpecularData.specularShift + jitter.x);
    float3 t2 = ShiftTangent(T, inputData.normalWS.xyz, anisoSpecularData.specularSecondaryShift + jitter.y);

    float3 hairSpec1 = anisoSpecularData.specularColor * anisoSpecularData.specularStrength *
        D_KajiyaKay(t1, lightingData.HalfDir, anisoSpecularData.specularExponent);
    float3 hairSpec2 = anisoSpecularData.specularSecondaryColor * anisoSpecularData.specularSecondaryStrength *
        D_KajiyaKay(t2, lightingData.HalfDir, anisoSpecularData.specularSecondaryExponent);

    float3 F = F_Schlick(float3(0.2,0.2,0.2), lightingData.LdotHClamp);
    float3 anisoSpecularColor = 0.25 * F * (hairSpec1 + hairSpec2) * lightingData.NdotLClamp * specMask * brdfData.specular;
    return anisoSpecularColor;
}

inline float3 AngleRingSpecular(AngleRingSpecularData specularData, InputData inputData, float radiance, LightingAngle lightingData)
{
    float3 specularColor = 0;
    float mask = specularData.mask;
    float3 normalV = mul(UNITY_MATRIX_V, float4(inputData.normalWS, 0)).xyz;
    float3 floatV = mul(UNITY_MATRIX_V, float4(lightingData.HalfDir, 0)).xyz;
    float ndh = dot(normalize(normalV.xz), normalize(floatV.xz));

    ndh = pow(ndh, 6) * specularData.width * radiance;

    float lightFeather = specularData.softness * ndh;

    float lightStepMax = saturate(1 - ndh + lightFeather);
    float lightStepMin = saturate(1 - ndh - lightFeather);

    float brightArea = LinearStep(lightStepMin, lightStepMax, min(mask, 0.99));
    float3 lightColor_B = brightArea * specularData.brightColor;
    float3 lightColor_S = LinearStep(specularData.threshold, 1, mask) * specularData.shadowColor;
    specularColor = (lightColor_S + lightColor_B) * specularData.intensity;
    return specularColor;
}

float3 NPRGlossyEnvironmentReflection(float3 reflectVector, float3 positionWS, float2 normalizedScreenSpaceUV, float perceptualRoughness, float occlusion)
{
    #if _ENVDEFAULT
        float3 irradiance;
        #if defined(_REFLECTION_PROBE_BLENDING) || USE_FORWARD_PLUS
            irradiance = CalculateIrradianceFromReflectionProbes(reflectVector, positionWS, perceptualRoughness, normalizedScreenSpaceUV);
        #else
            #ifdef _REFLECTION_PROBE_BOX_PROJECTION
                reflectVector = BoxProjectedCubemapDirection(reflectVector, positionWS, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
            #endif 

            float mip = PerceptualRoughnessToMipmapLevel(perceptualRoughness);
            float4 encodedIrradiance = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectVector, mip);

            #if defined(UNITY_USE_NATIVE_HDR)
                irradiance = encodedIrradiance.rgb;
            #else
                irradiance = DecodeHDREnvironment(encodedIrradiance, unity_SpecCube0_HDR);
            #endif
        #endif
        return irradiance * occlusion;
    #else
        return _GlossyEnvironmentColor.rgb * occlusion;
    #endif // GLOSSY_REFLECTIONS
}

// Computes the specular term for EnvironmentBRDF
float3 LitPor_EnvironmentBRDFSpecular(LitProBRDFData brdfData, float fresnelTerm)
{
    float surfaceReduction = 1.0 / (brdfData.roughness2 + 1.0);
    return float3(surfaceReduction * lerp(brdfData.specular, brdfData.grazingTerm, fresnelTerm));
}

float3 LitPro_EnvironmentBRDF(LitProBRDFData brdfData, float3 indirectDiffuse, float3 indirectSpecular, float fresnelTerm)
{
    float3 c = indirectDiffuse * brdfData.diffuse;
    c += indirectSpecular * LitPor_EnvironmentBRDFSpecular(brdfData, fresnelTerm);
    return c;
}

// Environment BRDF without diffuse for clear coat
float3 LitPro_EnvironmentBRDFClearCoat(LitProBRDFData brdfData, float clearCoatMask, float3 indirectSpecular, float fresnelTerm)
{
    float surfaceReduction = 1.0 / (brdfData.roughness2 + 1.0);
    return indirectSpecular * LitPor_EnvironmentBRDFSpecular(brdfData, fresnelTerm) * clearCoatMask;
}

float3 NPRGlossyEnvironmentReflection_Custom(float4 encodedIrradiance, float occlusion)
{
    // float3 irradiance;
    //
    // #if defined(UNITY_USE_NATIVE_HDR)
    //     irradiance = encodedIrradiance.rgb;
    // #else
    //     irradiance = DecodeHDREnvironment(encodedIrradiance, unity_SpecCube0_HDR);
    // #endif
    return encodedIrradiance.rgb * occlusion;
}

float3 RefractionColor(float3 specularColor, float alpha, float bumpRefraction, float projectionCoordW, float2 screenUV, float3 normalTS, LightingAngle lightingAngle)
{
    float3 refractionSample = 0;
    #if _REFRACTION
        screenUV += normalTS.xy * bumpRefraction * rcp(projectionCoordW);
        refractionSample = SAMPLE_TEXTURE2D_X(_CameraOpaqueTexture, sampler_LinearClamp, screenUV).rgb;
        refractionSample *= max(0.5h, 1.0h - F_Schlick(specularColor.rgb, lightingAngle.NdotV)) * (1.0h - alpha);
    #endif
    return refractionSample;
}

///////////////////////////////////////////////////////////////////////////////
//                         Depth Screen Space                                //
///////////////////////////////////////////////////////////////////////////////
float DepthNormal(float depth)
{
    float near = _ProjectionParams.y;
    float far = _ProjectionParams.z;
	
    #if UNITY_REVERSED_Z
    depth = 1.0 - depth;
    #endif
	
    float ortho = (far - near) * depth + near;
    return lerp(depth, ortho, unity_OrthoParams.w);
}

inline float3 SamplerMatCap(float4 matCapColor, float2 uv, float3 normalWS, float2 screenUV, TEXTURE2D_PARAM(matCapTex, sampler_matCapTex))
{
    float3 finalMatCapColor = 0;
    #if _MATCAP
        #if _NORMALMAP
            float3 normalVS = mul((float3x3)UNITY_MATRIX_V, normalWS);
            float2 matcapUV = normalVS.xy * 0.5 + 0.5;
        #else
            float2 matcapUV = uv;
        #endif
        float3 matCap = SAMPLE_TEXTURE2D(matCapTex, sampler_matCapTex, matcapUV).xyz;
        finalMatCapColor = matCap.xyz * matCapColor.rgb;
    #endif
    return finalMatCapColor;
}

#endif // UNIVERSAL_INPUT_SURFACE_PBR_INCLUDED
