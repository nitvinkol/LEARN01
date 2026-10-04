// Built-in Render Pipeline version (Unity 2022 and later). Same features as Custom/SpriteColorBlink (URP).
Shader "Custom/SpriteColorBlink_2022"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
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
            #pragma target 2.0
            #pragma multi_compile_instancing
            #pragma multi_compile_local _ PIXELSNAP_ON
            #pragma multi_compile _ ETC1_EXTERNAL_ALPHA
            #include "UnityCG.cginc"
            #include "UnitySprites.cginc"   // provides SpriteVert, SampleSpriteTexture, _Color, _MainTex, flip, pixel snap

            float4 _TargetColor;
            float  _Tolerance;
            float  _Softness;
            float  _BlinkEnabled;
            float  _BlinkMode;
            float4 _BlinkColor;
            float  _BlinkStrength;
            float  _BlinkFrequency;
            float  _BlinkOffset;

            fixed4 frag(v2f IN) : SV_Target
            {
                fixed4 src = SampleSpriteTexture(IN.texcoord);
                fixed4 sprite = src * IN.color;   // IN.color = vertex color * Tint * renderer color

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

                float3 rgb = sprite.rgb;
                float  a   = sprite.a;

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

                // Built-in sprites use premultiplied alpha (Blend One OneMinusSrcAlpha)
                return fixed4(rgb * a, a);
            }
            ENDCG
        }
    }
}
