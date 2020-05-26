// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "WireFrame/WireFrame"
{

	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Color("Color", COLOR) = (1, 1, 1, 1)
		_Thickness("Thickness", Range(0.01, 10)) = 0.25
		_height("Height", Range (1, 10)) = 4
		_fineness("Fineness", Range (0.5, 5)) = 1.5
		_surfaceFineness("SurfaceFineness", Range(1, 20)) = 12
		_surfaceheight("Surfaceheight", Range(0.01, 0.5)) = 0.15
		_timeScale("TimeScale", Range(0.01, 2)) = 0.1
		[MaterialToggle] _shading("isShading", Float) = 0
	}

	CGINCLUDE		
	#include "UnityCG.cginc"
	#include "AutoLight.cginc"
	#include "Assets/CgIncludes/Noise.cginc"
	#include "Assets/CgIncludes/Easing.cginc"

	struct v2g
	{
		float2 texcoord : TEXCOORD0;
		float4 pos : SV_POSITION;
		float3 normal : NORMAL;
		float3 lpos : TEXCOORD1;
		float depth : TEXCOORD2;
	};

	struct g2f
	{
		float4 pos : POSITION;
		float3 normal : NORMAL;
		float2 texcoord : TEXCOORD0;
		float3 dist : TEXCOORD3;
		float depth : TEXCOORD4;
	};

	struct f2o
	{
		float4 color : SV_Target;
		float depth : SV_Depth;
	};

	struct s_v2f {
	    float4 hpos : TEXCOORD0;
	    float4 pos : SV_POSITION;
	};

		sampler2D _MainTex;
		float4 _MainTex_ST;
		float _Thickness;
		float4 _Color;
		float _height;
		float _fineness;
		float _surfaceFineness;
		float _surfaceheight;
		float _timeScale;
		float _shading;
			
	v2g vert (appdata_base v)
	{
		v2g o;
		float4 p = v.vertex;

		float s = easeOutElastic(sin(_Time.x));
		float t = _Time.y;

		float3 _p = float3(p.x, p.z, t);
		p = p + float4(0, ((snoise(_p * _fineness)) + (snoise(p.xyz * _surfaceFineness)*_surfaceheight))*_height, 0, 0);
		float4 pos = UnityObjectToClipPos(p);

		o.pos = pos;
		o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
		o.lpos = p.xyz;
		o.depth = pos.z/pos.w;
		return o;
	}

	[maxvertexcount(3)]
	void geom(triangle v2g p[3], inout TriangleStream<g2f> triStream)
	{

		////////
		float2 p0 = _ScreenParams.xy * p[0].pos.xy / p[0].pos.w;
		float2 p1 = _ScreenParams.xy * p[1].pos.xy / p[1].pos.w;
		float2 p2 = _ScreenParams.xy * p[2].pos.xy / p[2].pos.w;

		float2 v0 = p2 - p1;
		float2 v1 = p0 - p2;
		float2 v2 = p1 - p0;

		float area = abs(v1.x * v2.y - v1.y * v2.x);

		float dist0 = area / length(v0);
		float dist1 = area / length(v1);
		float dist2 = area / length(v2);
		////////

		//normalの計算
		float3 v01 = p[1].lpos - p[0].lpos;
		float3 v02 = p[2].lpos - p[0].lpos;
		float3 v10 = p[0].lpos - p[1].lpos;
		float3 v12 = p[2].lpos - p[1].lpos;
		float3 v20 = p[0].lpos - p[2].lpos;
		float3 v21 = p[1].lpos - p[2].lpos;


		g2f o;
		o.pos = p[0].pos;
		o.texcoord = p[0].texcoord;
		o.normal = normalize(cross(v01, v02));
		o.dist = float3(dist0, 0, 0);
		o.depth = p[0].depth;
		triStream.Append(o);

		o.pos = p[1].pos;
		o.texcoord = p[1].texcoord;
		o.normal = normalize(cross(v12, v10));
		o.dist = float3(0, dist1, 0);
		o.depth = p[1].depth;
		triStream.Append(o);

		o.pos = p[2].pos;
		o.texcoord = p[2].texcoord;
		o.normal = normalize(cross(v20, v21));
		o.dist = float3(0, 0, dist2);
		o.depth = p[2].depth;
		triStream.Append(o);
	}
			
	f2o frag (g2f i) : SV_Target
	{
		f2o o;

		//////////
		fixed4 col = tex2D(_MainTex, i.texcoord);

		float val = min( i.dist.x, min( i.dist.y, i.dist.z));
	
		val = exp2( -1/_Thickness * val * val );
			
		float4 targetColor = _Color * tex2D( _MainTex, i.texcoord);
		float4 transCol = _Color * tex2D( _MainTex, i.texcoord);
		transCol.a = 0;
		//////////

		float4 _col;
		if(_shading == 1){
			float v = max(dot(i.normal, _WorldSpaceLightPos0), 0);
			_col = (val * targetColor + ( 1 - val ) * transCol)*(v+0.4);
		}else{
			_col = (val * targetColor + ( 1 - val ) * transCol);
		}

		if(_col.a < 0.1)
			discard;

		o.depth = i.depth;
		o.color = _col;
		return o;
	}


	s_v2f s_vert(appdata_base v)
	{
	    s_v2f o;
	   	
	    float4 p = v.vertex;
	    float3 _p = float3(p.x, p.z, _Time.x);
		p = p + float4(0, ((snoise(_p * _fineness)) + (snoise(p.xyz * _surfaceFineness)*_surfaceheight))*_height, 0, 0);

	    o.pos = UnityClipSpaceShadowCasterPos(v.vertex.xyz, v.normal);
	    o.pos = UnityApplyLinearShadowBias(o.pos);
	    o.hpos = o.pos;
	    return o;
	}

	float4 s_frag(s_v2f i) : SV_Target
	{
	    return i.hpos.zw.x / i.hpos.zw.y;
	}

	ENDCG

	SubShader
	{
		Pass
		{	
			Tags {"RenderType"="Opaque"}
			LOD 100
			Blend SrcAlpha OneMinusSrcAlpha
			cull off
			CGPROGRAM
			#pragma target 5.0
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag
			ENDCG
		}

		Pass
		{
			Name "ShadowCast"
			Tags{"LightMode" = "ShadowCaster"}
			CGPROGRAM
			#pragma vertex s_vert
			#pragma fragment s_frag
			#pragma multi_compile_shadowcaster
			ENDCG
		}
	}
	Fallback "Diffuse"
}