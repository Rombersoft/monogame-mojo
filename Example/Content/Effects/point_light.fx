﻿#if OPENGL
	#define SV_POSITION POSITION
	#define VS_SHADERMODEL vs_3_0
	#define PS_SHADERMODEL ps_3_0
#else
	#define VS_SHADERMODEL vs_4_0_level_9_3
	#define PS_SHADERMODEL ps_4_0_level_9_3
#endif

texture shadowMap: register(t0);
sampler shadowMapSampler: register(s0);

texture normalMap: register(t1);
sampler normalMapSampler: register(s1);

texture spacularMap: register(t2);
sampler specularMapSampler: register(s2);

matrix WorldViewProj;
float2 lightPos;
float intensity;
float radius;
float2 inv_tex_size;
float m_LightDepth;
float useNormalmap;

struct VertexShaderInput
{
	float4 Position : POSITION0;
	float4 Color	: COLOR0;
	float2 TexCoord : TEXCOORD;
};

struct VertexShaderOutput
{
	float4 Position : SV_POSITION;
	float4 LightColor		: COLOR0;
	float2 TexCoord0	:TEXCOORD0;
	float2 light_dir	: TEXCOORD1;
};

VertexShaderOutput MainVS(VertexShaderInput input)
{
	VertexShaderOutput output = (VertexShaderOutput)0;

	output.Position = mul(input.Position, WorldViewProj);
	output.LightColor = input.Color;
	output.TexCoord0 = input.Position.xy  * inv_tex_size;

	float2 p_light = lightPos - input.Position.xy;
	p_light.y *= -1;

	output.light_dir = p_light;

	return output;
}

float4 MainPS(VertexShaderOutput input) : COLOR
{
	const float specular_factor = 1.0f;

	//////

	float2 light_dir =  input.light_dir;

	// lighting attentuation
	//
	float dist =  length(light_dir);
	float alpha = pow(clamp(1.0f - dist / radius, 0.0f, 1.0f), intensity);

	// shadow
	float shadow = tex2D(shadowMapSampler, input.TexCoord0).a;

	float factor = alpha * shadow;

	if (useNormalmap != 0)
	{

		// normal
		//
		float3 normal = tex2D(normalMapSampler, input.TexCoord0).xyz;
		float gloss = normal.z;
		normal.xy = mad(normal.xy, 2.0f, -1.0f);
		normal.z = sqrt(1.0 - dot(normal.xy, normal.xy));

		// normal lighting
		float3 light_dir_norm = normalize(float3(input.light_dir, m_LightDepth));
		float ndotl = max(dot(normal, light_dir_norm), 0.0);

		// specular
		float3 hvec = normalize(light_dir_norm + float3(0.0f, 0.0f, 1.0f));
		float ndoth = max(dot(normal, hvec), 0.0f);
		float specular = pow(ndoth, 128.0f) * gloss;

		// rgb = lightmap
		// a = specular reflection
		return float4(input.LightColor.rgb * ndotl * factor, specular * shadow  * factor);

	}
	else
	{
		return float4(input.LightColor.rgb * factor, 0.0f);
	}
}

technique BasicColorDrawing{
	pass P0{
		VertexShader = compile VS_SHADERMODEL MainVS();
		PixelShader = compile PS_SHADERMODEL MainPS();
	}
}