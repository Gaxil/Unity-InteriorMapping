UNITY_DECLARE_SHADOWMAP(_SunCascadedShadowMap);
float4 _SunCascadedShadowMap_TexelSize;

#define GET_CASCADE_WEIGHTS(wpos, z)    getCascadeWeights_splitSpheres(wpos)
#define GET_SHADOW_FADE(wpos, z)		getShadowFade_SplitSpheres(wpos)

#define GET_SHADOW_COORDINATES(wpos,cascadeWeights)	getShadowCoord(wpos,cascadeWeights)

/**
 * Gets the cascade weights based on the world position of the fragment and the poisitions of the split spheres for each cascade.
 * Returns a float4 with only one component set that corresponds to the appropriate cascade.
 */
inline fixed4 getCascadeWeights_splitSpheres(float3 wpos)
{
	float3 fromCenter0 = wpos.xyz - unity_ShadowSplitSpheres[0].xyz;
	float3 fromCenter1 = wpos.xyz - unity_ShadowSplitSpheres[1].xyz;
	float3 fromCenter2 = wpos.xyz - unity_ShadowSplitSpheres[2].xyz;
	float3 fromCenter3 = wpos.xyz - unity_ShadowSplitSpheres[3].xyz;
	float4 distances2 = float4(dot(fromCenter0,fromCenter0), dot(fromCenter1,fromCenter1), dot(fromCenter2,fromCenter2), dot(fromCenter3,fromCenter3));
	fixed4 weights = float4(distances2 < unity_ShadowSplitSqRadii);
	weights.yzw = saturate(weights.yzw - weights.xyz);
	return weights;
}

/**
 * Returns the shadow fade based on the world position of the fragment, and the distance from the shadow fade center
 */
inline float getShadowFade_SplitSpheres( float3 wpos )
{	
	float sphereDist = distance(wpos.xyz, unity_ShadowFadeCenterAndType.xyz);
	half shadowFade = saturate(sphereDist * _LightShadowData.z + _LightShadowData.w);
	return shadowFade;	
}

/**
 * Returns the shadowmap coordinates for the given fragment based on the world position and z-depth.
 * These coordinates belong to the shadowmap atlas that contains the maps for all cascades.
 */
inline float4 getShadowCoord( float4 wpos, fixed4 cascadeWeights )
{
	float3 sc0 = mul (unity_WorldToShadow[0], wpos).xyz;
	float3 sc1 = mul (unity_WorldToShadow[1], wpos).xyz;
	float3 sc2 = mul (unity_WorldToShadow[2], wpos).xyz;
	float3 sc3 = mul (unity_WorldToShadow[3], wpos).xyz;
	return float4(sc0 * cascadeWeights[0] + sc1 * cascadeWeights[1] + sc2 * cascadeWeights[2] + sc3 * cascadeWeights[3], 1);
}

/**
 * Combines the different components of a shadow coordinate and returns the final coordinate.
 */
inline float3 combineShadowcoordComponents (float2 baseUV, float2 deltaUV, float depth, float2 receiverPlaneDepthBias)
{
	float3 uv = float3( baseUV + deltaUV, depth );
	uv.z += dot (deltaUV, receiverPlaneDepthBias); // apply the depth bias
	return uv;
}

/**
 * PCF shadowmap filtering based on a 3x3 kernel (optimized with 4 taps)
 *
 * Algorithm: http://the-witness.net/news/2013/09/shadow-mapping-summary-part-1/
 * Implementation example: http://mynameismjp.wordpress.com/2013/09/10/shadow-maps/
 */
half sampleShadowmap_PCF3x3 (float4 coord, float2 receiverPlaneDepthBias)
{
	const float2 offset = float2(0.5,0.5);
	float2 uv = (coord.xy * _SunCascadedShadowMap_TexelSize.zw) + offset;
	float2 base_uv = (floor(uv) - offset) * _SunCascadedShadowMap_TexelSize.xy;
	float2 st = frac(uv);

	float2 uw = float2( 3-2*st.x, 1+2*st.x );
	float2 u = float2( (2-st.x) / uw.x - 1, (st.x)/uw.y + 1 );
	u *= _SunCascadedShadowMap_TexelSize.x;

	float2 vw = float2( 3-2*st.y, 1+2*st.y );
	float2 v = float2( (2-st.y) / vw.x - 1, (st.y)/vw.y + 1);
	v *= _SunCascadedShadowMap_TexelSize.y;

    half shadow;
	half sum = 0;

    sum += uw[0] * vw[0] * UNITY_SAMPLE_SHADOW( _SunCascadedShadowMap, combineShadowcoordComponents( base_uv, float2(u[0], v[0]), coord.z, receiverPlaneDepthBias) );
    sum += uw[1] * vw[0] * UNITY_SAMPLE_SHADOW( _SunCascadedShadowMap, combineShadowcoordComponents( base_uv, float2(u[1], v[0]), coord.z, receiverPlaneDepthBias) );
    sum += uw[0] * vw[1] * UNITY_SAMPLE_SHADOW( _SunCascadedShadowMap, combineShadowcoordComponents( base_uv, float2(u[0], v[1]), coord.z, receiverPlaneDepthBias) );
    sum += uw[1] * vw[1] * UNITY_SAMPLE_SHADOW( _SunCascadedShadowMap, combineShadowcoordComponents( base_uv, float2(u[1], v[1]), coord.z, receiverPlaneDepthBias) );

    shadow = sum / 16.0f;
    shadow = lerp (_LightShadowData.r, 1.0f, shadow);

    return shadow;
}

/**
 * PCF shadowmap filtering based on a 5x5 kernel (optimized with 9 taps)
 *
 * Algorithm: http://the-witness.net/news/2013/09/shadow-mapping-summary-part-1/
 * Implementation example: http://mynameismjp.wordpress.com/2013/09/10/shadow-maps/
 */
half sampleShadowmap_PCF5x5 (float4 coord, float2 receiverPlaneDepthBias)
{

	const float2 offset = float2(0.5,0.5);
	float2 uv = (coord.xy * _SunCascadedShadowMap_TexelSize.zw) + offset;
	float2 base_uv = (floor(uv) - offset) * _SunCascadedShadowMap_TexelSize.xy;
	float2 st = frac(uv);

	float3 uw = float3( 4-3*st.x, 7, 1+3*st.x );
	float3 u = float3( (3-2*st.x) / uw.x - 2, (3+st.x)/uw.y, st.x/uw.z + 2 );
	u *= _SunCascadedShadowMap_TexelSize.x;

	float3 vw = float3( 4-3*st.y, 7, 1+3*st.y );
	float3 v = float3( (3-2*st.y) / vw.x - 2, (3+st.y)/vw.y, st.y/vw.z + 2 );
	v *= _SunCascadedShadowMap_TexelSize.y;

	half shadow;
	half sum = 0.0f;

	half3 accum = uw * vw.x;
	sum += accum.x * UNITY_SAMPLE_SHADOW( _SunCascadedShadowMap, combineShadowcoordComponents( base_uv, float2(u.x,v.x), coord.z, receiverPlaneDepthBias) );
    sum += accum.y * UNITY_SAMPLE_SHADOW( _SunCascadedShadowMap, combineShadowcoordComponents( base_uv, float2(u.y,v.x), coord.z, receiverPlaneDepthBias) );
    sum += accum.z * UNITY_SAMPLE_SHADOW( _SunCascadedShadowMap, combineShadowcoordComponents( base_uv, float2(u.z,v.x), coord.z, receiverPlaneDepthBias) );

	accum = uw * vw.y;
    sum += accum.x *  UNITY_SAMPLE_SHADOW( _SunCascadedShadowMap, combineShadowcoordComponents( base_uv, float2(u.x,v.y), coord.z, receiverPlaneDepthBias) );
    sum += accum.y *  UNITY_SAMPLE_SHADOW( _SunCascadedShadowMap, combineShadowcoordComponents( base_uv, float2(u.y,v.y), coord.z, receiverPlaneDepthBias) );
    sum += accum.z *  UNITY_SAMPLE_SHADOW( _SunCascadedShadowMap, combineShadowcoordComponents( base_uv, float2(u.z,v.y), coord.z, receiverPlaneDepthBias) );

	accum = uw * vw.z;
    sum += accum.x * UNITY_SAMPLE_SHADOW( _SunCascadedShadowMap, combineShadowcoordComponents( base_uv, float2(u.x,v.z), coord.z, receiverPlaneDepthBias) );
    sum += accum.y * UNITY_SAMPLE_SHADOW( _SunCascadedShadowMap, combineShadowcoordComponents( base_uv, float2(u.y,v.z), coord.z, receiverPlaneDepthBias) );
    sum += accum.z * UNITY_SAMPLE_SHADOW( _SunCascadedShadowMap, combineShadowcoordComponents( base_uv, float2(u.z,v.z), coord.z, receiverPlaneDepthBias) );

    shadow = sum / 144.0f;

    shadow = lerp (_LightShadowData.r, 1.0f, shadow);


    return shadow;
}

/**
 *	Samples the shadowmap at the given coordinates.
 */
half unity_sampleShadowmap( float4 coord )
{
	half shadow = UNITY_SAMPLE_SHADOW(_SunCascadedShadowMap,coord);
	shadow = lerp(_LightShadowData.r, 1.0, shadow);
	return shadow;
}



///////////////////
/**
*	Gets the shadows attenuations at world positions.
*/

half GetSunShadowsAttenuation(float3 worldPositions, float screenDepth)
{
	fixed4 cascadeWeights = GET_CASCADE_WEIGHTS(worldPositions.xyz, screenDepth);
	return unity_sampleShadowmap(GET_SHADOW_COORDINATES(float4(worldPositions, 1), cascadeWeights));
}

half GetSunShadowsAttenuation_PCF3x3(float3 worldPositions, float screenDepth, float receiverPlaneDepthBias)
{
	fixed4 cascadeWeights = GET_CASCADE_WEIGHTS(worldPositions.xyz, screenDepth);
	return sampleShadowmap_PCF3x3(GET_SHADOW_COORDINATES(float4(worldPositions, 1), cascadeWeights), receiverPlaneDepthBias);
}

half GetSunShadowsAttenuation_PCF5x5(float3 worldPositions, float screenDepth, float receiverPlaneDepthBias)
{
	fixed4 cascadeWeights = GET_CASCADE_WEIGHTS(worldPositions.xyz, screenDepth);
	return sampleShadowmap_PCF5x5(GET_SHADOW_COORDINATES(float4(worldPositions, 1), cascadeWeights), receiverPlaneDepthBias);
}