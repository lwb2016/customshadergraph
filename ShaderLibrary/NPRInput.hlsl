#ifndef UNIVERSAL_NPR_INPUT_INCLUDED
#define UNIVERSAL_NPR_INPUT_INCLUDED

// Must match Universal ShaderGraph master node
struct FernAddInputData
{
    #if EYE
        half3 corneaNormalWS;
        half3 irisNormalWS;
    #endif
    
    float3 clearCoatNormalWS;
    half linearEyeDepth;
    float3 tangentWS;
};

#endif
