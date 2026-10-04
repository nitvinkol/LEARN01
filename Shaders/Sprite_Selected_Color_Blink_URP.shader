Shader "Custom/SpriteColorBlink"
{
    Properties
    {
        [MainTexture] _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)

        [Header(Target Color)]
        _TargetColor ("Target Color (pick from sprite)", Color) = (1,0,0,1)
        _Tolerance ("Match Tolerance", Range(0, 1)) = 0.05
        _Softness ("Match Edge Softness", Range(0, 0.5)) = 0.05

        [Header(Blink)]
        [Toggle] _BlinkEnabled ("Blink Enabled", Float) = 1
        [Enum(Fade Out, 0, Tint To Color, 1)] _BlinkMode ("Blink Mode", Float) = 1
        [HDR] _BlinkColor ("Blink Color (Tint mode)", Color) = (1,1,1,1)
        _BlinkStrength ("Blink Strength", Range(0, 1)) = 1
        _BlinkFrequency ("Blinks Per Second", Range(0, 10)) = 1
        _BlinkOffset ("Blink Start Offset (cycles)", Range(0, 1)) = 0
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
            Name "SpriteColorBlink"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            // No _ST or _TexelSize here: the 2D SRP Batcher doesn't support them.
            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float4 _TargetColor;
                float  _Tolerance;
                float  _Softness;
                float  _BlinkEnabled;
                float  _BlinkMode;
                float4 _BlinkColor;
                float  _BlinkStrength;
                float  _BlinkFrequency;
                float  _BlinkOffset;
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
                OUT.color = IN.color * _Color; // SpriteRenderer color arrives as vertex color
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 src = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                half4 sprite = src * IN.color;

                // How close is this pixel's ORIGINAL texture color to the target color?
                // 1 = matches, 0 = doesn't. Tolerance = how far off still counts as a match,
                // Softness = how gradually the match fades out beyond the tolerance.
                float dist = distance(src.rgb, _TargetColor.rgb);
                float match = 1.0 - smoothstep(_Tolerance, _Tolerance + max(_Softness, 0.00001), dist);
                match *= src.a; // ignore transparent pixels

                // Smooth fade in / fade out: 0 at start of each cycle, 1 halfway through.
                float phase = _BlinkFrequency * _Time.y + _BlinkOffset;
                float wave = 0.5 - 0.5 * cos(6.2831853 * phase);
                float pulse = wave * step(0.5, _BlinkEnabled); // 0 when blinking is off

                float k = match * pulse * _BlinkStrength;

                half3 rgb = sprite.rgb;
                half  a   = sprite.a;

                if (_BlinkMode < 0.5)
                {
                    // Fade Out: matching pixels fade toward transparent
                    a *= 1.0 - k;
                }
                else
                {
                    // Tint To Color: matching pixels blend toward the blink color
                    rgb = lerp(rgb, _BlinkColor.rgb, k);
                }

                return half4(rgb, a);
            }
            ENDHLSL
        }
    }
}
