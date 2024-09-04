#ifndef TRIPLANARUVFUNCTION
#define TRIPLANARUVFUNCTION

inline void Rotation_float(float3 RV, out float3 RMx, out float3 RMy, out float3 RMz)
{
    //degrees to radians
    RV = radians(RV);

    //Build LHR euleur rotation matrices
    float3x3 RMX = {
        1, 0, 0,
        0, cos(RV.x), sin(RV.x),
        0, -sin(RV.x), cos(RV.x)
    };

    float3x3 RMY = {
        cos(RV.y), 0, -sin(RV.y),
        0, 1, 0,
        sin(RV.y), 0, cos(RV.y)
    };

    float3x3 RMZ = {
        cos(RV.z), -sin(RV.z), 0,
        sin(RV.z), cos(RV.z), 0,
        0, 0, 1
    };

    //combine rotations
    float3x3 RMXYZ = mul(mul(RMZ,RMY),RMX);

    RMx = RMXYZ[0];
    RMy = RMXYZ[1];
    RMz = RMXYZ[2];
}

inline void Rotation_half(float3 RV, out half3 RMx, out half3 RMy, out half3 RMz)
{
    //degrees to radians
    RV = radians(RV);

    //Build LHR euleur rotation matrices
    half3x3 RMX = {
        1, 0, 0,
        0, cos(RV.x), sin(RV.x),
        0, -sin(RV.x), cos(RV.x)
    };

    half3x3 RMY = {
        cos(RV.y), 0, -sin(RV.y),
        0, 1, 0,
        sin(RV.y), 0, cos(RV.y)
    };

    half3x3 RMZ = {
        cos(RV.z), -sin(RV.z), 0,
        sin(RV.z), cos(RV.z), 0,
        0, 0, 1
    };

    //combine rotations
    half3x3 RMXYZ = mul(mul(RMZ,RMY),RMX);

    RMx = RMXYZ[0];
    RMy = RMXYZ[1];
    RMz = RMXYZ[2];
}

void RotationVector_float(float3 inVec, float3 RMx, float3 RMy, float3 RMz, out float3 outVec)
{
    float3x3 RM = { RMx,
                RMy,
                RMz };

    outVec = mul(inVec,RM);
}

void RotationVector_half(half3 inVec, half3 RMx, half3 RMy, half3 RMz, out half3 outVec)
{
    half3x3 RM = { RMx,
                RMy,
                RMz };

    outVec = mul(inVec,RM);
}

#endif