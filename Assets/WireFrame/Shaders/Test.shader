// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Custom/Test" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
	}
	CGINCLUDE
	
	#include "HLSLSupport.cginc"
	#include "UnityShaderVariables.cginc"
	
	#include "UnityCG.cginc"
	#include "Lighting.cginc"
	#include "UnityPBSLighting.cginc"
	#include "Assets/CgIncludes/Noise.cginc"
	
	#define WorldReflectionVector(data,normal) data.worldRefl
	#define WorldNormalVector(data,normal) normal
	
	sampler2D _MainTex;
	
	struct Input {
		float2 uv_MainTex;
	};
	
	half _Glossiness;
	half _Metallic;
	fixed4 _Color;
	
	void surf (Input IN, inout SurfaceOutputStandard o) {
		// Albedo comes from a texture tinted by color
		fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
		o.Albedo = c.rgb;
		// Metallic and smoothness come from slider variables
		o.Metallic = _Metallic;
		o.Smoothness = _Glossiness;
		o.Alpha = c.a;
	}
	
	
	// vertex-to-fragment interpolation data
	struct v2f_surf {
		float4 pos : SV_POSITION;
		float2 pack0 : TEXCOORD0; // _MainTex
		half3 worldNormal : TEXCOORD1;
		float3 worldPos : TEXCOORD2;
		half3 sh : TEXCOORD3; // SH
	};
	float4 _MainTex_ST;
	
	// vertex shader
	v2f_surf vert_surf (appdata_full v) {
		v2f_surf o;
		UNITY_INITIALIZE_OUTPUT(v2f_surf,o);

		float4 p = v.vertex;
	    float3 _p = float3(p.x, p.z, _Time.x);
		p = p + float4(0, snoise(_p * 5), 0, 0);

		o.pos = UnityObjectToClipPos (p);
		o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
		float3 worldPos = mul(unity_ObjectToWorld, p).xyz;
		fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
		o.worldPos = worldPos;
		o.worldNormal = worldNormal;
		float3 viewDirForLight = UnityWorldSpaceViewDir(worldPos);
		
		o.sh = ShadeSH3Order (half4(worldNormal, 1.0));
		return o;
	}
	
	// fragment shader
	void frag_surf (v2f_surf IN,
		out half4 outDiffuse : SV_Target0,
		out half4 outSpecSmoothness : SV_Target1,
		out half4 outNormal : SV_Target2,
		out half4 outEmission : SV_Target3) 
	{
	// prepare and unpack data
		Input surfIN;
		UNITY_INITIALIZE_OUTPUT(Input,surfIN);
		surfIN.uv_MainTex = IN.pack0.xy;
		float3 worldPos = IN.worldPos;
		
		fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
		
		#ifdef UNITY_COMPILER_HLSL
			SurfaceOutputStandard o = (SurfaceOutputStandard)0;
		#else
			SurfaceOutputStandard o;
		#endif
		
		o.Albedo = 0.0;
		o.Emission = 0.0;
		o.Alpha = 0.0;
		o.Occlusion = 1.0;
		o.Normal = IN.worldNormal;
		
		// call surface function
		surf (surfIN, o);
		fixed3 originalNormal = o.Normal;
		
		// Setup lighting environment
		UnityGI gi;
		UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
		gi.indirect.diffuse = 0;
		gi.indirect.specular = 0;
		gi.light.color = 0;
		gi.light.dir = half3(0,1,0);
		gi.light.ndotl = LambertTerm (o.Normal, gi.light.dir);
		// Call GI (lightmaps/SH/reflections) lighting function
		UnityGIInput giInput;
		UNITY_INITIALIZE_OUTPUT(UnityGIInput, giInput);
		giInput.light = gi.light;
		giInput.worldPos = worldPos;
		giInput.worldViewDir = worldViewDir;
		giInput.atten = 1.0;
		
		giInput.ambient = IN.sh;
		
		giInput.probeHDR[0] = unity_SpecCube0_HDR;
		giInput.probeHDR[1] = unity_SpecCube1_HDR;
		
		#if UNITY_SPECCUBE_BLENDING || UNITY_SPECCUBE_BOX_PROJECTION
			giInput.boxMin[0] = unity_SpecCube0_BoxMin; // .w holds lerp value for blending
		#endif
		
		#if UNITY_SPECCUBE_BOX_PROJECTION
			giInput.boxMax[0] = unity_SpecCube0_BoxMax;
			giInput.probePosition[0] = unity_SpecCube0_ProbePosition;
			giInput.boxMax[1] = unity_SpecCube1_BoxMax;
			giInput.boxMin[1] = unity_SpecCube1_BoxMin;
			giInput.probePosition[1] = unity_SpecCube1_ProbePosition;
		#endif
		
		LightingStandard_GI(o, giInput, gi);
		
		// call lighting function to output g-buffer
		outEmission = LightingStandard_Deferred (o, worldViewDir, gi, outDiffuse, outSpecSmoothness, outNormal);
		outDiffuse.a = 1.0;
		
		#ifndef UNITY_HDR_ON
			outEmission.rgb = exp2(-outEmission.rgb);
		#endif
	}
	ENDCG

	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		Pass {
			Name "DEFERRED"
			Tags { "LightMode" = "Deferred" }
			
			CGPROGRAM
			#pragma vertex vert_surf
			#pragma fragment frag_surf
			#pragma target 3.0
			#pragma exclude_renderers nomrt
			#pragma multi_compile_prepassfinal noshadow
			ENDCG
		}
	}
	FallBack "Diffuse"
}