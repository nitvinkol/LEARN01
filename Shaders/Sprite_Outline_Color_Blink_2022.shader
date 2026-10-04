// Built-in Render Pipeline version (Unity 2022 and later). Same features as Custom/SpriteOutlineSmooth (URP).
Shader "Custom/SpriteOutlineSmooth_2022"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)
        [HDR] _OutlineColor ("Outline Color", Color) = (1,1,1,1)
        _OutlineThickness ("Outline Thickness (px)", Range(0, 32)) = 4
        _OutlineSmoothness ("Outline Smoothness", Range(0.05, 1)) = 0.5

        [Header(Blink)]
        [Toggle] _BlinkEnabled ("Blink Enabled", Float) = 1
        _BlinkFrequency ("Blinks Per Second", Range(0, 10)) = 1
        _BlinkOffset ("Blink Start Offset (cycles)", Range(0, 1)) = 0
        _BlinkMinIntensity ("Blink Min Intensity", Range(0, 1)) = 0

        // Set automatically by the Sprite Renderer
        [PerRendererData] _AlphaTex ("External Alpha", 2D) = "white" {}
        [PerRendererData] _EnableExternalAlpha ("Enable External Alpha", Float) = 0
        [HideInInspector] _RendererColor ("RendererColor", Color) = (1,1,1,1)
        [HideInInspector] _Flip ("Flip", Vector) = (1,1,1,1)
        [Toggle(PIXELSNAP_ON)] PixelSnap ("Pixel Snap", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
            "RenderType" = "Transparent"
            "PreviewType" = "Plane"
            "CanUseSpriteAtlas" = "True"
        }

        Cull Off
        Lighting Off
        ZWrite Off
        Blend One OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex SpriteVert
            #pragma fragment frag
            #pragma target 3.0
            #pragma multi_compile_instancing
            #pragma multi_compile_local _ PIXELSNAP_ON
            #pragma multi_compile _ ETC1_EXTERNAL_ALPHA
            #include "UnityCG.cginc"
            #include "UnitySprites.cginc"   // provides SpriteVert, SampleSpriteTexture, _Color, _MainTex, flip, pixel snap

            float4 _MainTex_TexelSize;      // x = 1/width, y = 1/height (filled in by Unity)
            float4 _OutlineColor;
            float  _OutlineThickness;
            float  _OutlineSmoothness;
            float  _BlinkEnabled;
            float  _BlinkFrequency;
            float  _BlinkOffset;
            float  _BlinkMinIntensity;

            fixed4 frag(v2f IN) : SV_Target
            {
                fixed4 src = SampleSpriteTexture(IN.texcoord);
                fixed4 sprite = src * IN.color;   // IN.color = vertex color * Tint * renderer color

                // Average the alpha over a filled disc. Averaging (instead of a hard
                // "any neighbour opaque?" test) blurs jagged edges, and the smoothstep
                // below turns that blur into a clean anti-aliased outline.
                float2 offsetScale = _MainTex_TexelSize.xy * _OutlineThickness;
                float sum = src.a;
                float weight = 1.0;

                [unroll]
                for (int r = 1; r <= 4; r++)
                {
                    float radius = r / 4.0;
                    float angleOffset = (r % 2) * (3.14159265 / 16.0); // stagger rings
                    [unroll]
                    for (int d = 0; d < 16; d++)
                    {
                        float a = 6.2831853 * d / 16.0 + angleOffset;
                        float2 o = float2(cos(a), sin(a)) * radius * offsetScale;
                        sum += SampleSpriteTexture(IN.texcoord + o).a * radius;
                        weight += radius;
                    }
                }

                float field = sum / weight;                       // blurred coverage, 0..1
                float outlineMask = smoothstep(0.01, lerp(0.04, 0.35, _OutlineSmoothness), field);

                // Phase in cycles, shifted by the start offset (0..1 = one full cycle).
                float phase = _BlinkFrequency * _Time.y + _BlinkOffset;
                float wave = 0.5 - 0.5 * cos(6.2831853 * phase);
                float blink = lerp(1.0, lerp(_BlinkMinIntensity, 1.0, wave), step(0.5, _BlinkEnabled));

                float outlineA = outlineMask * _OutlineColor.a * blink * step(0.0001, _OutlineThickness);

                // Outline sits behind the sprite
                float3 rgb = lerp(_OutlineColor.rgb, sprite.rgb, sprite.a);
                float  alpha = sprite.a + outlineA * (1.0 - sprite.a);

                // Built-in sprites use premultiplied alpha (Blend One OneMinusSrcAlpha)
                return fixed4(rgb * alpha, alpha);
            }
            ENDCG
        }
    }
}
