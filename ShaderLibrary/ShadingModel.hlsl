#ifndef UNIVERSAL_SHADINGMODEL_INCLUDED
#define UNIVERSAL_SHADINGMODEL_INCLUDED

#include "NPRInput.hlsl"
#include "FernSGSurfaceData.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "RealtimeLights.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/BSDF.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Debug/Debugging3D.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/AmbientOcclusion.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
#include "LightingCommon.hlsl"
#include "DeclareDepthShadowTexture.hlsl"
#include "NPRUtils.hlsl"
#include "PBRBxDF.hlsl"

struct FernSGAddSurfaceData
{
	float4 envCustomReflection;
	float3 rampColor;
	float3 darkColor;
	float3 lightenColor;
	float3 specular;
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

struct FDirectLighting
{
    float3	Diffuse;
    float3	Specular;
    float3	Transmission;
};

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

	#if _FABRIC_COTTON_WOOL || _FABRIC_SILK
	float LdotV;
	float NdotH;
	float LdotH;
	float invLenLV;
	#endif

	#if _CLEARCOATNORMAL
	float HalfLambert_ClearCoat;
	float NdotL_ClearCoat;
	float NdotLClamp_ClearCoat;
	float NdotHClamp_ClearCoat;
	float NdotVClamp_ClearCoat;
	#endif
};

float3 SpecularGGX(float Roughness, float Anisotropy, float3 SpecularColor, BxDFContext Context, float NoL)
{
	float Alpha = Roughness * Roughness;
	float a2 = Alpha * Alpha;

	//TODO: UE Area Light
	// FAreaLight Punctual = AreaLight;
	// Punctual.SphereSinAlpha = 0;
	// Punctual.SphereSinAlphaSoft = 0;
	// Punctual.LineCosSubtended = 1;
	// Punctual.Rect = (FRect)0;
	// Punctual.IsRectAndDiffuseMicroReflWeight = 0;
	//float Energy = EnergyNormalization(a2, Context.VoH, Punctual); 
	
	float Energy = 1;

	float ax = 0;
	float ay = 0;
	GetAnisotropicRoughness(Alpha, Anisotropy, ax, ay);

	// Generalized microfacet specular
	float3 D = D_GGXaniso(ax, ay, Context.NoH, Context.XoH, Context.YoH) * Energy;
	float3 Vis = Vis_SmithJointAniso(ax, ay, Context.NoV, NoL, Context.XoV, Context.XoL, Context.YoV, Context.YoL);
	float3 F = F_Schlick( SpecularColor, Context.VoH );

	return (D * Vis) * F;
}

float3 SpecularGGX( float Roughness, float3 SpecularColor, BxDFContext Context, half NoL)
{
	float a2 = Pow4( Roughness );
	float Energy = 1;
	
	#if SHADING_PATH_MOBILE
	half D = D_GGX_Mobile(Roughness, Context.NoH) * Energy;
	return MobileSpecularGGXInner(D, SpecularColor, Roughness, Context.NoV, NoL, Context.VoH, MOBILE_HIGH_QUALITY_BRDF);
	#else
	// Generalized microfacet specular
	float D = D_GGX( a2, Context.NoH ) * Energy;
	float Vis = Vis_SmithJointApprox( a2, Context.NoV, NoL );
	float3 F = F_Schlick( SpecularColor, Context.VoH );

	return (D * Vis) * F;
	#endif
}

FDirectLighting DefaultLitBxDF( FernSurfaceData surfaceData, FernSGAddSurfaceData addSurfaceData, FernAddInputData addInputData, LightingAngle lightingAngle, half3 N, half3 V, half3 L, float Falloff, half NoL)
{
	BxDFContext Context;
	FDirectLighting Lighting;

#if SUPPORTS_ANISOTROPIC_MATERIALS
	bool bHasAnisotropy = HasAnisotropy(GBuffer.SelectiveOutputMask);
#else
	bool bHasAnisotropy = false;
#endif

	float NoV, VoH, NoH;
	UNITY_BRANCH
	if (bHasAnisotropy)
	{
		half3 X = addInputData.tangentWS;
		half3 Y = normalize(cross(N, X));
		Init(Context, N, X, Y, V, L);

		NoV = Context.NoV;
		VoH = Context.VoH;
		NoH = Context.NoH;
	}
	else
	{
#if SHADING_PATH_MOBILE
		InitMobile(Context, N, V, L, NoL);
#else
		Init(Context, N, V, L);
#endif

		NoV = Context.NoV;
		VoH = Context.VoH;
		NoH = Context.NoH;

		// TODO: UE Area Light
		//SphereMaxNoH(Context, AreaLight.SphereSinAlpha, true);
	}

	Context.NoV = saturate(abs( Context.NoV ) + 1e-5);

#if MATERIAL_ROUGHDIFFUSE
	// Chan diffuse model with roughness == specular roughness. This is not necessarily a good modelisation of reality because when the mean free path is super small, the diffuse can in fact looks rougher. But this is a start.
	// Also we cannot use the morphed context maximising NoH as this is causing visual artefact when interpolating rough/smooth diffuse response. 
	Lighting.Diffuse = Diffuse_Chan(GBuffer.DiffuseColor, Pow4(GBuffer.Roughness), NoV, NoL, VoH, NoH, GetAreaLightDiffuseMicroReflWeight(AreaLight));
#else
	Lighting.Diffuse = Diffuse_Lambert(surfaceData.albedo);
#endif
	Lighting.Diffuse *= (Falloff * NoL);

	float roughness = 1 - surfaceData.smoothness;
	float anisotropy = addSurfaceData.anisotropy;
	float specularColor = ComputeF0(addSurfaceData.specular, surfaceData.albedo, surfaceData.metallic);
	
	UNITY_BRANCH
	if (bHasAnisotropy)
	{
		//Lighting.Specular = GBuffer.WorldTangent * .5f + .5f;
		
		Lighting.Specular = (Falloff * NoL) * SpecularGGX(roughness, anisotropy, specularColor, Context, NoL);
	}
	else
	{
		Lighting.Specular =  (Falloff * NoL) * SpecularGGX(roughness, specularColor, Context, NoL);
	}

	BXDF_ENERGY_SUFFIX EnergyTerms = ComputeGGXSpecEnergyTerms(roughness, Context.NoV, specularColor);

	// Add energy presevation (i.e. attenuation of the specular layer onto the diffuse component
	Lighting.Diffuse *= ComputeEnergyPreservation(EnergyTerms);

	// Add specular microfacet multiple scattering term (energy-conservation)
	Lighting.Specular *= ComputeEnergyConservation(EnergyTerms);

	Lighting.Transmission = 0;
	return Lighting;
}

#endif // UNIVERSAL_INPUT_SURFACE_PBR_INCLUDED
