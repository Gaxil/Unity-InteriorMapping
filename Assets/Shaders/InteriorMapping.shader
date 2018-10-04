// The MIT License
// Copyright © 2013 Gil Damoiseaux
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
// and associated documentation files (the "Software"), to deal in the Software without restriction, 
// including without limitation the rights to use, copy, modify, merge, publish, distribute, 
// sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
// furnished to do so, subject to the following conditions: The above copyright notice and this
// permission notice shall be included in all copies or substantial portions of the Software. 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT 
// NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH 
// THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Shader "Custom/InteriorMapping"
{
	Properties
	{
		_WindowAlbedo ("Window Albedo", 2D) = "white" { }
		[NoScaleOffset]_WindowRMW ("Window Rough/Metal/Window", 2D) = "white" { }
		[NoScaleOffset]_WindowNormal ("Window normal", 2D) = "white" { }
		[NoScaleOffset]_AlbedoAtlas ("Albedo Atlas", 2D) = "white" { }
		[NoScaleOffset]_DecorationAtlas ("Decoration Atlas", 2D) = "white" { }
		
		[Header(Room topology)]
		_RoomDepth("Room depth", Range( 0.25 , 5)) = 2
		[IntRange]_RoomWidth("Room width", Range( 1 , 50)) = 4
		[IntRange]_RoomOffset("Room offset", Range( 0 , 50)) = 0
		// _RoomWidth("Room width", Range( 1 , 50)) = 4
		// _RoomOffset("Room offset", Range( 0 , 50)) = 0
		[Toggle] _Corridor("Has corridor ?", Float) = 0
		_CorridorDepth("Corridor depth", Range( 0.25 , 10)) = 5

		[Header(Room lighting)]
		[Toggle] _DirectLighting("Has direct lighting ?", Float) = 1
		[Toggle] _GlobalShadows("Has global shadows ?", Float) = 1
		_RoomMaxAmbient("Room max ambient", Range( 0.0 , 0.75)) = 0.25
		_RoomMinAmbient("Room min ambient", Range( 0.0 , 0.75)) = 0.125
		_CorridorMaxAmbient("Corridor max ambient", Range( 0.0 , 0.75)) = 0.5
		_CorridorMinAmbient("Corridor min ambient", Range( 0.0 , 0.75)) = 0.25
		_SunIntensity("Sun intensity", Range( 1.0 , 4.0)) = 2.0
		_DepthFade("Depth fade distance", Range( 1.0 , 20)) = 2

		[Header(Visuals)]
		_RandomSeed("Random seed", Range( 0.0 , 1000.0)) = 0.0
		_RefractionIntensity("Refraction intensity", Range( 0.0 , 1.0)) = 0.05
		_WindowsReflectionBoost("Windows reflexion boost", Range( 0.0 , 10.0)) = 2.0
		_WindowsTint("Windows tint", Color) = (0.9, 0.9, 0.9)
		_Fresnel("Windows fresnel", Range(0.1, 10)) = 0.5
		_TextureUnitSize("Size of texture in world unit", Float) = 0.2666666
		[IntRange]_BlindsVariations("Blinds variations", Range( 1 , 4)) = 3
		[Toggle] _Decorations("Back walls has random decorations?", Float) = 0
		_DecorationChance("Chance of decoration", Range(0.0, 1)) = 0.25

		[Header(Extra)]
		[Toggle] _Sphere("Has a sphere per room?", Float) = 0
		[HDR]_SphereColor("Sphere color", Color) = (1.9, 1.9, 1.9)
		_LinearAttenuation("Linear attenuation", Range(0.0, 50)) = 1
		_SquareAttenuation("Linear attenuation", Range(0.0, 50)) = 5
		_AnimationSpeed("Animation speed", Range(-2.0, 2)) = 1

	}
	
	SubShader
	{
		Tags{ "RenderType" = "Opaque"  "Queue" = "Geometry+0" "IsEmissive" = "true"  }
		Cull Back
		CGPROGRAM
		
		#include "Shadows.cginc"
		#include "UnityCG.cginc"
		#include "UnityPBSLighting.cginc"
		#include "Lighting.cginc"



		#pragma surface surf Standard keepalpha fullforwardshadows 
		#pragma shader_feature _CORRIDOR_ON
		#pragma shader_feature _DIRECTLIGHTING_ON
		#pragma shader_feature _GLOBALSHADOWS_ON
		#pragma shader_feature _SPHERE_ON
		#pragma shader_feature _DECORATIONS_ON

		#pragma target 5.0
		
		sampler2D _WindowAlbedo;
		sampler2D _AlbedoAtlas;
		sampler2D _DecorationAtlas;
		sampler2D _LightAtlas;
		sampler2D _WindowRMW;
		sampler2D _WindowNormal;
		
		float _RoomWidth;
		float _RoomDepth;
		float _RoomOffset;
		float _DepthFade;
		float _Corridor;
		float _CorridorDepth;
		float _RefractionIntensity;
		float _BlindsVariations;
		float _RandomSeed;
		float _RoomMaxAmbient;
		float _RoomMinAmbient;
		float _CorridorMaxAmbient;
		float _CorridorMinAmbient;
		float _SunIntensity;
		float _WindowsReflectionBoost;
		float3 _WindowsTint;
		float _Fresnel;
		float _TextureUnitSize;
		float3 _SphereColor;
		float _LinearAttenuation;
		float _SquareAttenuation;
		float _AnimationSpeed;
		float _DecorationChance;

		struct Input
		{
			float3 worldNormal;
			float2 uv_WindowAlbedo;
			float3 viewDir;
			float3 worldPos;
			float4 screenPos;
			
			half3 internalSurfaceTtoW0; 
			half3 internalSurfaceTtoW1; 
			half3 internalSurfaceTtoW2;
		};

		// Random/hash function by Inigo Quilez
		// see https://www.shadertoy.com/view/4sfGzS for more details
		float random(float2 p)
		{
			p += _RandomSeed.xx;
			p  = frac( p*0.3183099+.1 );
			p *= 17.0;
			return frac( p.x*p.y*(p.x+p.y) );
		}
		
		void surf(Input IN, inout SurfaceOutputStandard o)
		{
			o.Normal = float3(0,0,1);
			float3 normal = UnpackNormal( tex2D( _WindowNormal, IN.uv_WindowAlbedo) );
			float3 viewDir = normalize(IN.viewDir.xyz + _RefractionIntensity * float3(normal.x, normal.y, 0.0f));
			float3 color = 0.0.xxx;
			
			float3 positionCell = float3(frac(IN.uv_WindowAlbedo), 0.0f);
			float2 indexCell = floor(IN.uv_WindowAlbedo)+float2(floor(_RoomOffset), 0.0f);
		
			float cellCount = floor(_RoomWidth);		
			float leftShift = fmod(indexCell.x, cellCount);
			float rightShift = cellCount - leftShift-1;
			#ifdef _CORRIDOR_ON
				float cellCountPerRoom = cellCount-1;
				float firstCell = step(leftShift, 0.5f);
				rightShift *= (1-firstCell);
				leftShift = max(0, leftShift-1);
			#else
				float cellCountPerRoom = cellCount;
				float firstCell = 0.0f;
			#endif

			float randomFromCell = random(float2(floor(indexCell.x/cellCount),indexCell.y));		
			float blindsModel = fmod(floor(randomFromCell*37), _BlindsVariations);
			#ifdef _CORRIDOR_ON
			blindsModel = lerp(blindsModel, 0, firstCell);
			#endif

			float3 normalWS = WorldNormalVector( IN, float3( 0, 0, 1 ) );
			float3 tangentWS = WorldNormalVector( IN, float3( 1, 0, 0 ) );
			float3 bitangentWS = WorldNormalVector( IN, float3( 0, 1, 0 ) );
			float3x3 worldToTangent = float3x3( tangentWS, bitangentWS, normalWS );

			float3 positionWS = IN.worldPos;
			float3 lightDirWS = UnityWorldSpaceLightDir( positionWS );
			// Light dir in tangent/cell space
			float3 lightDirCell = normalize(mul( worldToTangent, normalize(lightDirWS) ));

			////////////////////////////////////////////
			// Interior mapping intersections
			////////////////////////////////////////////
			float4 uvMaxDist = float4(1.0f, 1.0f, 1.0f, 100.0f);

			// Ground
			float isGroundVisible = step( 0.0f, viewDir.y );
			float distToGround = (positionCell.y / viewDir.y);
			float3 intersectPos = positionCell - distToGround * viewDir;
			uvMaxDist = lerp(uvMaxDist, float4(frac(intersectPos.x), frac(-intersectPos.z), 0.0f, distToGround), step(distToGround, uvMaxDist.w) * isGroundVisible);	

			// Roof
			float isRoofVisible = 1.0f - isGroundVisible;
			float distToRoof = (-(1.0f-positionCell.y) / viewDir.y);
			intersectPos = positionCell - distToRoof * viewDir;
			uvMaxDist = lerp(uvMaxDist, float4(1.0f+frac(intersectPos.x), frac(-intersectPos.z), 0.0f, distToRoof), step(distToRoof, uvMaxDist.w) * isRoofVisible);	

			// Left wall
			float isLeftVisible = step( 0.0f, viewDir.x );
			float distToLeft = ((positionCell.x+leftShift) / viewDir.x);
			intersectPos = positionCell - distToLeft * viewDir;
			uvMaxDist = lerp(uvMaxDist, float4(2.0f+frac(intersectPos.z*0.5f), intersectPos.y, 0.0f, distToLeft), step(distToLeft, uvMaxDist.w) * isLeftVisible);

			// Right wall
			float isRightVisible = 1.0f - isLeftVisible;
			float distToRight = (-(1.0f-positionCell.x+rightShift) / viewDir.x);
			intersectPos = positionCell - distToRight * viewDir;
			uvMaxDist = lerp(uvMaxDist, float4(2.0f+frac(intersectPos.z*0.5f), intersectPos.y, 0.0f, distToRight), step(distToRight, uvMaxDist.w) * isRightVisible);

			// Back wall
			#ifdef _CORRIDOR_ON
				float cellDepth = lerp(_RoomDepth, _CorridorDepth, firstCell);
			#else
				float cellDepth = _RoomDepth;
			#endif
			float distToBack = cellDepth / viewDir.z;
			intersectPos = positionCell - distToBack * viewDir;

			#ifdef _DECORATIONS_ON
			float4 decorations = 0.0.xxxx;
			float2 uniqueCellWallID = indexCell + float2(floor(intersectPos.x), 0.0f);
			float decorationRandom = random(uniqueCellWallID);
			float decorationModel;
			float decorationChance = modf(decorationRandom*4.0f, decorationModel);
			decorations = tex2D(_DecorationAtlas, float2(frac(intersectPos.x)*0.25f + decorationModel*0.25f, intersectPos.y)) * step(distToBack, uvMaxDist.w) * (1.0f-firstCell) * step(decorationChance, _DecorationChance);
			#endif

			uvMaxDist = lerp(uvMaxDist, float4(3.0f+frac(intersectPos.x*0.5f), intersectPos.y, 0.0f, distToBack), step(distToBack, uvMaxDist.w));

			
			#ifdef _SPHERE_ON
			float sphereTime = (_Time.y*_AnimationSpeed + randomFromCell*10.0f)*5.0f;
			float sphereRadius = 0.125f;		
			float pingPong = 2.0f*abs(0.5f - frac(0.05f*sphereTime+0.25f));
			float3 sphereCenter = float3(-leftShift + lerp(sphereRadius, cellCountPerRoom-sphereRadius, pingPong), 
										sphereRadius+abs(sin(sphereTime))*0.5f, -1.5f);
			{
				float3 oc = positionCell - sphereCenter;
				float b = dot(oc, -viewDir);
				float c = dot(oc, oc) - sphereRadius*sphereRadius;
				float h = b*b - c;
				float distToSphere = 0.0f;
				if ((h>=0) && (firstCell==0.0f))
				{
					h = sqrt(h);
					distToSphere = min(-b-h, -b+h);

					#ifdef _DECORATIONS_ON
					decorations *= step(uvMaxDist.w, distToSphere);
					#endif

					uvMaxDist = lerp(uvMaxDist, float4(0.0f, 0.0f, 1.0f, distToSphere), step(distToSphere, uvMaxDist.w));
				}
			}
			#endif

			float roomModel = lerp(-floor(random(float2(1000.0f,indexCell.y))*3.0f), 1.0f, firstCell);

			////////////////////////////////////////////
			// Windows/ Direct light
			////////////////////////////////////////////
			float directLight = 0.0f;

			#ifdef _DIRECTLIGHTING_ON
			intersectPos = positionCell - uvMaxDist.w * viewDir;	// Final intersect position in TS

			float lightBackDistance = intersectPos.z/lightDirCell.z;	// Distance from interior to window in the light direction
			float2 shadowsUV = float2(									// Intersection position between window
				intersectPos.x - lightBackDistance*lightDirCell.x,		// plane and ray from interior position and 
				intersectPos.y - lightBackDistance*lightDirCell.y);		// light direction
			shadowsUV.y = saturate(shadowsUV.y);						// Avoid light leaking from other floors
			directLight = 1.0f-tex2Dlod(_WindowAlbedo, float4(float2(0.0f, 0.75f-0.25f*blindsModel) + frac(shadowsUV.xy)*float2(1.0f, 0.25f), 0.0f, clamp(abs(lightBackDistance)*2, 0, 4))).a;
			// Avoid light leaking from adjacent rooms on the right
			#ifdef _CORRIDOR_ON
				directLight*=step(shadowsUV.x+leftShift, lerp(cellCount-1, 1, firstCell));
			#else
				directLight*=step(shadowsUV.x+leftShift, cellCount);							
			#endif
			// Avoid light leaking from adjacent rooms on the left
			directLight*=step(0, shadowsUV.x+leftShift);
			// Avoid light coming from behind
			directLight*=step(0.0f, lightDirCell.z);				
			#endif

			////////////////////////////////////////////
			// Ambient and final light computation
			////////////////////////////////////////////
			float externalLightIntensity = dot(lightDirCell, float3(0.0f, 0.0f, 1.0f));
			float ambientLevel = smoothstep(0.0f, 0.85f, externalLightIntensity);
			float fresnel = pow (saturate(dot(viewDir, float3(0.0f, 0.0f, 1.0f))),_Fresnel);

			uvMaxDist.y += roomModel;
			color = tex2Dgrad(_AlbedoAtlas, float2(0.0f, 0.25f) + uvMaxDist.xy*0.25f, ddx(IN.uv_WindowAlbedo), ddy(IN.uv_WindowAlbedo));
			color *= saturate(1.0f - uvMaxDist.w/_DepthFade);	

			#ifdef _DECORATIONS_ON
			color = lerp(color, decorations.rgb, decorations.a);
			#endif

		
			#if (_DIRECTLIGHTING_ON && _GLOBALSHADOWS_ON)

			float3 shadowPosition = positionWS - normalize(UnityWorldSpaceViewDir( positionWS )) * uvMaxDist.w * _TextureUnitSize
											- normalize(lightDirWS) * lightBackDistance * _TextureUnitSize;
			float shadowAttenuation = GetSunShadowsAttenuation_PCF5x5(shadowPosition, IN.screenPos.z, 0).x;		// Access shadow map

			directLight*=shadowAttenuation;
			#endif

			float ambient = lerp(_RoomMinAmbient, _RoomMaxAmbient, ambientLevel);
			#ifdef _CORRIDOR_ON
			ambient = lerp(ambient, lerp(_CorridorMinAmbient, _CorridorMaxAmbient, ambientLevel), firstCell);
			#endif

			#ifdef _SPHERE_ON
			float distanceToSphere = length(sphereCenter-intersectPos);
			float attenuation = 1.0f/(1.0f + _LinearAttenuation*distanceToSphere + _SquareAttenuation*distanceToSphere*distanceToSphere);
			color = color * lerp(_SunIntensity, ambient, 1.0f-directLight) + 
					color * attenuation * _SphereColor * (1.0f-firstCell);
			#else
			color *= lerp(_SunIntensity, ambient, 1.0f-directLight);
			#endif

			////////////////////////////////////////////
			// Main textures 
			////////////////////////////////////////////
			float3 windowsRMW = tex2D(_WindowRMW, IN.uv_WindowAlbedo);
			o.Smoothness = 1.0f-windowsRMW.r;
			float4 window = tex2Dgrad(_WindowAlbedo, float2(0.0f, 0.75f-0.25f*blindsModel) + float2(positionCell.x, positionCell.y*0.25f), ddx(IN.uv_WindowAlbedo*float2(1.0f, .25f)), ddy(IN.uv_WindowAlbedo*float2(1.0f, .25f)));
			o.Emission = fresnel*_WindowsTint * color * (1.0f-window.a);
			o.Albedo = window.rgb * window.a * (lerp(_WindowsTint, 1.0.xxx,windowsRMW.b));
			o.Metallic = windowsRMW.g;
			o.Occlusion = lerp(1.0f + _WindowsReflectionBoost*(1.0f-fresnel)*smoothstep(0.0f, 0.35f, externalLightIntensity), 1.0f, windowsRMW.b) ;
			o.Normal = lerp(float3(0.0f, 0.0f, 1.0f), normal,windowsRMW.b);

		}

		ENDCG
		
	}
	FallBack "Diffuse"
}