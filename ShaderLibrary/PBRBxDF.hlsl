#ifndef UNIVERSAL_BxDF_INCLUDED
#define UNIVERSAL_BxDF_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Debug/Debugging3D.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/AmbientOcclusion.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

#define Pow2(x) x*x

struct BxDFContext
{
    float NoV;
    float NoL;
    float VoL;
    float NoH;
    float VoH;
    float XoV;
    float XoL;
    float XoH;
    float YoV;
    float YoL;
    float YoH;
};

void Init( inout BxDFContext Context, float3 N, float3 X, float3 Y, float3 V, float3 L )
{
    Context.NoL = dot(N, L);
    Context.NoV = dot(N, V);
    Context.VoL = dot(V, L);
    float InvLenH = rsqrt( 2 + 2 * Context.VoL );
    Context.NoH = saturate( ( Context.NoL + Context.NoV ) * InvLenH );
    Context.VoH = saturate( InvLenH + InvLenH * Context.VoL );
    //NoL = saturate( NoL );
    //NoV = saturate( abs( NoV ) + 1e-5 );

    Context.XoV = dot(X, V);
    Context.XoL = dot(X, L);
    Context.XoH = (Context.XoL + Context.XoV) * InvLenH;
    Context.YoV = dot(Y, V);
    Context.YoL = dot(Y, L);
    Context.YoH = (Context.YoL + Context.YoV) * InvLenH;
}

void Init( inout BxDFContext Context, float3 N, float3 V, float3 L )
{
    Context.NoL = dot(N, L);
    Context.NoV = dot(N, V);
    Context.VoL = dot(V, L);
    float InvLenH = rsqrt( 2 + 2 * Context.VoL );
    Context.NoH = saturate( ( Context.NoL + Context.NoV ) * InvLenH );
    Context.VoH = saturate( InvLenH + InvLenH * Context.VoL );
    //NoL = saturate( NoL );
    //NoV = saturate( abs( NoV ) + 1e-5 );

    Context.XoV = 0.0f;
    Context.XoL = 0.0f;
    Context.XoH = 0.0f;
    Context.YoV = 0.0f;
    Context.YoL = 0.0f;
    Context.YoH = 0.0f;
}

void InitMobile(inout BxDFContext Context, float3 N, float3 V, float3 L, float NoL)
{
    Context.NoL = NoL;
    Context.NoV = dot(N, V);
    Context.VoL = dot(V, L);
    float3 H = normalize(float3(V + L));
    Context.NoH = max(0, dot(N, H));
    Context.VoH = max(0, dot(V, H));

    //NoL = saturate( NoL );
    //NoV = saturate( abs( NoV ) + 1e-5 );

    Context.XoV = 0.0f;
    Context.XoL = 0.0f;
    Context.XoH = 0.0f;
    Context.YoV = 0.0f;
    Context.YoL = 0.0f;
    Context.YoH = 0.0f;
}


// [ de Carpentier 2017, "Decima Engine: Advances in Lighting and AA" ]
void SphereMaxNoH( inout BxDFContext Context, float SinAlpha, bool bNewtonIteration )
{
	if( SinAlpha > 0 )
	{
		float CosAlpha = sqrt( 1 - Pow2( SinAlpha ) );
	
		float RoL = 2 * Context.NoL * Context.NoV - Context.VoL;
		if( RoL >= CosAlpha )
		{
			Context.NoH = 1;
			Context.XoH = 0;
			Context.YoH = 0;
			Context.VoH = abs( Context.NoV );
		}
		else
		{
			float rInvLengthT = SinAlpha * rsqrt( 1 - RoL*RoL );
			float NoTr = rInvLengthT * ( Context.NoV - RoL * Context.NoL );
// Enable once anisotropic materials support area lights
#if 0
			float XoTr = rInvLengthT * ( Context.XoV - RoL * Context.XoL );
			float YoTr = rInvLengthT * ( Context.YoV - RoL * Context.YoL );
#endif
			float VoTr = rInvLengthT * ( 2 * Context.NoV*Context.NoV - 1 - RoL * Context.VoL );

			if (bNewtonIteration)
			{
				// dot( cross(N,L), V )
				float NxLoV = sqrt( saturate( 1 - Pow2(Context.NoL) - Pow2(Context.NoV) - Pow2(Context.VoL) + 2 * Context.NoL * Context.NoV * Context.VoL ) );

				float NoBr = rInvLengthT * NxLoV;
				float VoBr = rInvLengthT * NxLoV * 2 * Context.NoV;

				float NoLVTr = Context.NoL * CosAlpha + Context.NoV + NoTr;
				float VoLVTr = Context.VoL * CosAlpha + 1   + VoTr;

				float p = NoBr   * VoLVTr;
				float q = NoLVTr * VoLVTr;
				float s = VoBr   * NoLVTr;

				float xNum = q * ( -0.5 * p + 0.25 * VoBr * NoLVTr );
				float xDenom = p*p + s * (s - 2*p) + NoLVTr * ( (Context.NoL * CosAlpha + Context.NoV) * Pow2(VoLVTr) + q * (-0.5 * (VoLVTr + Context.VoL * CosAlpha) - 0.5) );
				float TwoX1 = 2 * xNum / ( Pow2(xDenom) + Pow2(xNum) );
				float SinTheta = TwoX1 * xDenom;
				float CosTheta = 1.0 - TwoX1 * xNum;
				NoTr = CosTheta * NoTr + SinTheta * NoBr;
				VoTr = CosTheta * VoTr + SinTheta * VoBr;
			}

			Context.NoL = Context.NoL * CosAlpha + NoTr; // dot( N, L * CosAlpha + T * SinAlpha )
// Enable once anisotropic materials support area lights
#if 0
			Context.XoL = Context.XoL * CosAlpha + XoTr;
			Context.YoL = Context.YoL * CosAlpha + YoTr;
#endif
			Context.VoL = Context.VoL * CosAlpha + VoTr;

			float InvLenH = rsqrt( 2 + 2 * Context.VoL );
			Context.NoH = saturate( ( Context.NoL + Context.NoV ) * InvLenH );
// Enable once anisotropic materials support area lights
#if 0
			Context.XoH = ((Context.XoL + Context.XoV) * InvLenH);	// dot(X, (L+V)/|L+V|)
			Context.YoH = ((Context.YoL + Context.YoV) * InvLenH);
#endif
			Context.VoH = saturate( InvLenH + InvLenH * Context.VoL );
		}
	}
}

float3 Diffuse_Lambert( float3 DiffuseColor )
{
	return DiffuseColor * (1 / PI);
}

// Convert a roughness and an anisotropy factor into GGX alpha values respectively for the major and minor axis of the tangent frame
void GetAnisotropicRoughness(float Alpha, float Anisotropy, out float ax, out float ay)
{
	#if 1
		// Anisotropic parameters: ax and ay are the roughness along the tangent and bitangent	
		// Kulla 2017, "Revisiting Physically Based Shading at Imageworks"
		ax = max(Alpha * (1.0 + Anisotropy), 0.001f);
		ay = max(Alpha * (1.0 - Anisotropy), 0.001f);
	#else
		float K = sqrt(1.0f - 0.95f * Anisotropy);
		ax = max(Alpha / K, 0.001f);
		ay = max(Alpha * K, 0.001f);
#endif
}

// Anisotropic GGX
// [Burley 2012, "Physically-Based Shading at Disney"]
float D_GGXaniso( float ax, float ay, float NoH, float XoH, float YoH )
{
	// The two formulations are mathematically equivalent
	#if 1
	float a2 = ax * ay;
	float3 V = float3(ay * XoH, ax * YoH, a2 * NoH);
	float S = dot(V, V);

	return (1.0f / PI) * a2 * sqrt(a2 / S);
	#else
	float d = XoH*XoH / (ax*ax) + YoH*YoH / (ay*ay) + NoH*NoH;
	return 1.0f / ( PI * ax*ay * d*d );
	#endif
}

// [Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"]
float Vis_SmithJointAniso(float ax, float ay, float NoV, float NoL, float XoV, float XoL, float YoV, float YoL)
{
	float Vis_SmithV = NoL * length(float3(ax * XoV, ay * YoV, NoV));
	float Vis_SmithL = NoV * length(float3(ax * XoL, ay * YoL, NoL));
	return 0.5 * rcp(Vis_SmithV + Vis_SmithL);
}

float DielectricSpecularToF0(float Specular)
{
	return 0.08f * Specular;
}

float3 ComputeF0(float Specular, float3 BaseColor, float Metallic)
{
	return lerp(DielectricSpecularToF0(Specular).xxx, BaseColor, Metallic.xxx);
}


// Appoximation of joint Smith term for GGX
// [Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"]
float Vis_SmithJointApprox( float a2, float NoV, float NoL )
{
	float a = sqrt(a2);
	float Vis_SmithV = NoL * ( NoV * ( 1 - a ) + a );
	float Vis_SmithL = NoV * ( NoL * ( 1 - a ) + a );
	return 0.5 * rcp( Vis_SmithV + Vis_SmithL );
}

struct BXDF_ENERGY_SUFFIX
{
	float3 W; // overall weight to scale the lobe BxDF by to ensure energy conservation
	float3 E; // Directional albedo of the lobe for energy preservation and lobe picking
};

float3 GetF0F90(float3 InF0)
{
	#if IS_BXDF_ENERGY_TYPE_ACHROMATIC
		return max3(InF0.x, InF0.y, InF0.z);
	#else
		return InF0;
	#endif
}

BXDF_ENERGY_SUFFIX ComputeGGXSpecEnergyTerms(float Roughness, float NoV, float3 F0, float3 F90)
{
	BXDF_ENERGY_SUFFIX Out;
	#if USE_ENERGY_CONSERVATION > 0
		{
		Out = BXDF_ENERGY_SUFFIX(ComputeFresnelEnergyTerms)(GGXEnergyLookup(Roughness, NoV), F0, F90);
		}
	#else
{
	Out.W = 1.0f;
	Out.E = GetF0F90(F0);
}
	#endif
	return Out;
}

BXDF_ENERGY_SUFFIX ComputeGGXSpecEnergyTerms(float Roughness, float NoV, float3 F0)
{
	const float F90 = saturate(50.0 * F0.g); // See F_Schlick implementation
	return ComputeGGXSpecEnergyTerms(Roughness, NoV, F0, F90);
}

float ComputeEnergyPreservation(BXDF_ENERGY_SUFFIX EnergyTerms)
{
	#if USE_ENERGY_CONSERVATION > 0
		#if USE_DEVELOPMENT_SHADERS
			return View.bShadingEnergyPreservation ? (1 - Luminance(EnergyTerms.E)) : 1.0f;
		#else
			return 1 - Luminance(EnergyTerms.E);
		#endif
	#else
	return 1.0f;
#endif
}

// Return the energy conservation weight factor for account energy loss in the BSDF model (i.e. due to micro-facet multiple scattering)
float3 ComputeEnergyConservation(BXDF_ENERGY_SUFFIX EnergyTerms)
{
	return EnergyTerms.W;
}

#endif
