Shader "Custom/SpriteOutlineSmooth"
{
    Properties
    {
        [MainTexture] _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)
        [HDR] _OutlineColor ("Outline Color", Color) = (1,1,1,1)
        _OutlineThickness ("Outline Thickness (px)", Range(0, 32)) = 4
        _OutlineSmoothness ("Outline Smoothness", Range(0.05, 1)) = 0.5

        [Header(Blink)]
        [Toggle] _BlinkEnabled ("Blink Enabled", Float) = 1
        _BlinkFrequency ("Blinks Per Second", Range(0, 10)) = 1
        _BlinkOffset ("Blink Start Offset (cycles)", Range(0, 1)) = 0
        _BlinkMinIntensity ("Blink Min Intensity", Range(0, 1)) = 0
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "IgnoreProjector" = "True"
            "PreviewType" = "Plane"
        }

        Cull Off
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            Name "SpriteOutline"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.5
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            // No _ST or _TexelSize here: the 2D SRP Batcher doesn't support them.
            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float4 _OutlineColor;
                float  _OutlineThickness;
                float  _OutlineSmoothness;
                float  _BlinkEnabled;
                float  _BlinkFrequency;
                float  _BlinkOffset;
                float  _BlinkMinIntensity;
            CBUFFER_END

            struct Attributes
            {
                float3 positionOS : POSITION;
                float4 color      : COLOR;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 color      : COLOR;
                float2 uv         : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS);
                OUT.uv = IN.uv;
                OUT.color = IN.color * _Color;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 src = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                half4 sprite = src * IN.color;

                float texW, texH;
                _MainTex.GetDimensions(texW, texH);
                float2 offsetScale = (1.0 / float2(texW, texH)) * _OutlineThickness;

                float sum = src.a;
                float weight = 1.0;

                [unroll]
                for (int r = 1; r <= 4; r++)
                {
                    float radius = r / 4.0;
                    float angleOffset = (r % 2) * (3.14159265 / 16.0);
                    [unroll]
                    for (int d = 0; d < 16; d++)
                    {
                        float a = 6.2831853 * d / 16.0 + angleOffset;
                        float2 o = float2(cos(a), sin(a)) * radius * offsetScale;
                        sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv + o).a * radius;
                        weight += radius;
                    }
                }

                float field = sum / weight;
                float outlineMask = smoothstep(0.01, lerp(0.04, 0.35, _OutlineSmoothness), field);

                // Phase in cycles: time * frequency, shifted by the start offset (0..1 = one full cycle).
                float phase = _BlinkFrequency * _Time.y + _BlinkOffset;
                float wave = 0.5 - 0.5 * cos(6.2831853 * phase);
                float blink = lerp(1.0, lerp(_BlinkMinIntensity, 1.0, wave), step(0.5, _BlinkEnabled));

                float outlineA = outlineMask * _OutlineColor.a * blink * step(0.0001, _OutlineThickness);
                half3 rgb = lerp(_OutlineColor.rgb, sprite.rgb, sprite.a);
                half  a   = sprite.a + outlineA * (1.0 - sprite.a);

                return half4(rgb, a);
            }
            ENDHLSL
        }
    }
}
