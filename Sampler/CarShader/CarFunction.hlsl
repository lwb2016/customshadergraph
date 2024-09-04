void RotateVector_half(in half3 origin, in half3x3 rotateMatrix, out half3 result)
{
    result = mul(origin, rotateMatrix);
}

void RotateVector_float(in float3 origin, in float3x3 rotateMatrix, out float3 result)
{
    result = mul(origin, rotateMatrix);
}

void BuildTPRotationMatrix_half(in half3 rotation, out half3 RMX, out half3 RMY, out half3 RMZ)
{
    rotation = radians(rotation);
    //Build LHR euleur rotation matrices
    half3x3 RMx = {
        1, 0, 0,
        0, cos(rotation.x), sin(rotation.x),
        0, -sin(rotation.x), cos(rotation.x)
    };

    half3x3 RMy = {
        cos(rotation.y), 0, -sin(rotation.y),
        0, 1, 0,
        sin(rotation.y), 0, cos(rotation.y)
    };

    half3x3 RMz = {
        cos(rotation.z), -sin(rotation.z), 0,
        sin(rotation.z), cos(rotation.z), 0,
        0, 0, 1
    };

    //combine rotations
    half3x3 RMXYZ = mul(mul(RMx,RMy),RMz);
    
    RMX = RMXYZ[0];
    RMY = RMXYZ[1];
    RMZ = RMXYZ[2];
}

void BuildTPRotationMatrix_float(in float3 rotation, out float3 RMX, out float3 RMY, out float3 RMZ)
{
    rotation = radians(rotation);
    //Build LHR euleur rotation matrices
    float3x3 RMx = {
        1, 0, 0,
        0, cos(rotation.x), sin(rotation.x),
        0, -sin(rotation.x), cos(rotation.x)
    };

    float3x3 RMy = {
        cos(rotation.y), 0, -sin(rotation.y),
        0, 1, 0,
        sin(rotation.y), 0, cos(rotation.y)
    };

    float3x3 RMz = {
        cos(rotation.z), -sin(rotation.z), 0,
        sin(rotation.z), cos(rotation.z), 0,
        0, 0, 1
    };

    //combine rotations
    float3x3 RMXYZ = mul(mul(RMx,RMy),RMz);
    
    RMX = RMXYZ[0];
    RMY = RMXYZ[1];
    RMZ = RMXYZ[2];
}

// Z buffer to linear 0..1 depth (0 at camera position, 1 at far plane).
// Does NOT work with orthographic projections.
// Does NOT correctly handle oblique view frustums.
// zBufferParam = { (f-n)/n, 1, (f-n)/n*f, 1/f }
void Linear01Depth_float(float depth, out float linearDepth)
{
    linearDepth = 1.0 / (_ZBufferParams.x * depth + _ZBufferParams.y);
}

void Linear01Depth_half(half depth, out half linearDepth)
{
    linearDepth = 1.0 / (_ZBufferParams.x * depth + _ZBufferParams.y);
}


float HalfTone(float RepeatRate, float DotSize, float2 UV, out float3 oNormal)
{
    float size = 1.0 / RepeatRate;
    float2 cellSize = float2(size, size);
    float2 cellCenter = cellSize * 0.5;

    float2 uvlocal = fmod(abs(UV), cellSize);
    float dist = length(uvlocal - cellCenter);
    float radius = cellCenter.x * DotSize;
    float threshold = length(ddx(dist) - ddy(dist))/*0.002*/;
    float relDist = dist / radius;
    float2 planeNormalXZ = (uvlocal - cellCenter) / dist;
    float3 planeNormal = normalize(float3(planeNormalXZ.x, 0.25, planeNormalXZ.y));
    oNormal = normalize(lerp(float3(0, 1, 0), planeNormal, pow(relDist, 1)));
    return smoothstep(dist - threshold, dist + threshold, radius);
}

float2 UVNoise(float2 position)
{
    position = fmod(position, 2048.0f);
    float scale = 0.5;
    float magic = 3571.0;
    float2 random = (1.0 / 4320.0) * position + float2(0.25, 0.0);
    random = frac(dot(random * random, magic));
    random = frac(dot(random * random, magic));
    return /*-scale + 2.0 * scale **/ random;
}

void RainDotsNormal(UnityTexture2D noiseTex, float2 uv, float normalAxisValue, float3 normalTS, float dotRepeat, float dotSize, out float3 dotNormal, out float dotWeight)
{
    float2 uv2 = uv;
    float2 cellSize = (1.0 / dotRepeat).xx;
    float2 cellCenter = cellSize * 0.5;
    float cellRadius = cellCenter.x * dotSize;
    float2 bias2 = SAMPLE_TEXTURE2D(noiseTex, noiseTex.samplerstate, uv2 * 10.0).xy;
    
    bias2.xy = bias2.xy * 2 - 1;
    uv2 += bias2.xy * 0.4 * cellRadius;
    uv2.xy += normalTS.xy * 0.5 * cellRadius;
    float dots = HalfTone(dotRepeat, dotSize, uv2, dotNormal);

    uv2 = floor(uv2 / cellSize) * cellSize + cellCenter;

    float noise = UVNoise(floor(uv2 * 10000)).x;
    noise = 1 - frac(noise + _Time.y * 0.06);
    dots = saturate((noise - 0.8) * dots * 5.0);
    dots *= saturate((abs(normalAxisValue) - 0.3) * 1.429);

    dotWeight = dots;
}

void RainDots_float(UnityTexture2D noiseTex, float3 positionWS, float3 normalWS, float3 normalTS, float dotRepeat, float dotSize, float strength, out float3 dotNormal, out float mask)
{
    mask = 0;
    float dotWeightX;
    float3 dotNormalX;
    RainDotsNormal(noiseTex, positionWS.yz, normalWS.x, normalTS, dotRepeat, dotSize, dotNormalX, dotWeightX);
    dotNormalX = dotNormalX.yxz;
    dotNormalX.x *= sign(normalWS.x);

    float dotWeightY;
    float3 dotNormalY;
    RainDotsNormal(noiseTex, positionWS.xz, normalWS.y, normalTS, dotRepeat, dotSize, dotNormalY, dotWeightY);
    dotNormalY = dotNormalY.xyz;
    dotNormalY.xz *= -1;
    dotNormalY.y *= sign(normalWS.y);

    float dotWeightZ; 
    float3 dotNormalZ;
    RainDotsNormal(noiseTex, positionWS.xy, normalWS.z, normalTS, dotRepeat, dotSize, dotNormalZ, dotWeightZ);
    dotNormalZ = dotNormalZ.xzy;
    dotNormalZ.x *= -1;
    dotNormalZ.z *= sign(normalWS.z);

    float dots = dotWeightX + dotWeightY + dotWeightZ;
    dotNormal = (dotNormalX * dotWeightX + dotNormalY * dotWeightY + dotNormalZ * dotWeightZ) / max(dots, 0.001);
    dotNormal = normalize(lerp(normalWS, dotNormal, dots * strength));

    //lerp from raindrops to raindots based on normalY
    float lerpY = saturate((abs(normalWS.y) - 0.5) * 2.0);
    mask = lerp(mask, 0, lerpY);
    mask = max(dots, mask);
}

void RainDots_half(UnityTexture2D noiseTex, float3 positionWS, float3 normalWS, float3 normalTS, half dotRepeat, half dotSize, half strength, out float3 dotNormal, out half mask)
{
    RainDots_float(noiseTex, positionWS, normalWS, normalTS, dotRepeat, dotSize, strength, dotNormal, mask);
}