// Vidrio desenfocado para UI (URP) — TouristMAR
// Desenfoca lo que ve la cámara detrás del panel, como el "Liquid Glass" de Apple.
// Requisitos:
//   1) Canvas en "Screen Space - Camera" usando la Main Camera
//   2) URP Asset: "Opaque Texture" activado (Downsampling: 4x Box para más desenfoque)
// El color de la Image funciona como tinte: su alfa indica cuánto tinte se mezcla.
Shader "TouristMAR/VidrioUI"
{
    Properties
    {
        [PerRendererData] _MainTex ("Forma", 2D) = "white" {}
        _Desenfoque ("Desenfoque (px)", Range(0, 60)) = 24
        _Saturacion ("Saturación", Range(0, 2)) = 1.25
        _Luz ("Brillo", Range(0.5, 1.5)) = 1.05

        [HideInInspector] _StencilComp ("Stencil Comparison", Float) = 8
        [HideInInspector] _Stencil ("Stencil ID", Float) = 0
        [HideInInspector] _StencilOp ("Stencil Operation", Float) = 0
        [HideInInspector] _StencilWriteMask ("Stencil Write Mask", Float) = 255
        [HideInInspector] _StencilReadMask ("Stencil Read Mask", Float) = 255
        [HideInInspector] _ColorMask ("Color Mask", Float) = 15
    }

    SubShader
    {
        Tags
        {
            "Queue"="Transparent"
            "IgnoreProjector"="True"
            "RenderType"="Transparent"
            "PreviewType"="Plane"
            "RenderPipeline"="UniversalPipeline"
        }

        Stencil
        {
            Ref [_Stencil]
            Comp [_StencilComp]
            Pass [_StencilOp]
            ReadMask [_StencilReadMask]
            WriteMask [_StencilWriteMask]
        }

        Cull Off
        ZWrite Off
        ZTest [unity_GUIZTestMode]
        Blend SrcAlpha OneMinusSrcAlpha
        ColorMask [_ColorMask]

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float4 color      : COLOR;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                half4  color      : COLOR;
                float2 uv         : TEXCOORD0;
                float4 screenPos  : TEXCOORD1;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float _Desenfoque;
                float _Saturacion;
                float _Luz;
            CBUFFER_END

            Varyings vert (Attributes v)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = v.uv;
                o.color = v.color;
                o.screenPos = ComputeScreenPos(o.positionCS);
                return o;
            }

            half4 frag (Varyings i) : SV_Target
            {
                half forma = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).a;
                float2 uv = i.screenPos.xy / i.screenPos.w;
                float2 paso = _Desenfoque / _ScreenParams.xy;

                // Desenfoque: centro + dos anillos de 8 muestras
                half3 suma = SampleSceneColor(uv);
                float peso = 1.0;
                [unroll] for (int a = 0; a < 8; a++)
                {
                    float ang = a * 0.785398;
                    float2 dir = float2(cos(ang), sin(ang));
                    suma += SampleSceneColor(uv + dir * paso * 0.5) * 0.8;
                    suma += SampleSceneColor(uv + dir * paso) * 0.5;
                    peso += 1.3;
                }
                half3 fondo = suma / peso;

                // Un poco más de saturación y luz, como el vidrio de Apple
                half luma = dot(fondo, half3(0.299, 0.587, 0.114));
                fondo = lerp(luma.xxx, fondo, _Saturacion) * _Luz;

                half3 rgb = lerp(fondo, i.color.rgb, i.color.a);
                return half4(rgb, forma);
            }
            ENDHLSL
        }
    }
}
