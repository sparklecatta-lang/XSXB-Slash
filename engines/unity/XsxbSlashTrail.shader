// XSXB-Slash layer shader (recipe v1, docs/SPEC.md section 3). Unlit; works in Built-in and URP.
// One material per layer. XsxbSlashTrail.cs sets every property from recipe.json.
Shader "XSXB-Slash/Layer"
{
    Properties
    {
        _ShapeTex ("Shape (Clamp, linear)", 2D) = "white" {}
        _MaskTex ("Mask (Repeat, linear)", 2D) = "white" {}
        _HighlightTex ("Highlight (Clamp, linear)", 2D) = "black" {}
        _Color ("Color (linear)", Vector) = (0,0,0,0)
        _EdgeColor ("Edge Color (linear)", Vector) = (0,0,0,0)
        _HighlightColor ("Highlight Color (linear)", Vector) = (1,1,1,0)
        _Alpha ("Alpha", Float) = 1
        _Hdr ("HDR", Float) = 1
        _WindowNarrow ("Window Narrow", Float) = 0.6
        _MaskAmount ("Mask Amount", Float) = 0.5
        _MaskTilePerM ("Mask Tile / m", Float) = 0.6
        _MaskPanPerS ("Mask Pan / s", Float) = -0.35
        _ErodeSpeed ("Erode Speed", Float) = 0.85
        _ErodeSharp ("Erode Sharp", Float) = 6
        _EdgeWidth ("Edge Width", Float) = 0.08
        _EdgeGlow ("Edge Glow", Float) = 0
        _Highlight ("Highlight", Float) = 0
        _Additive ("Additive (0/1)", Float) = 0
        _Debug ("Debug 0 off / 1 UV0 / 2 dist", Float) = 0
        _TrailTime ("Time (set by XsxbSlashTrail.cs)", Float) = 0
        // recipe.constants
        _ErodeBase ("erodeBase", Float) = -0.12
        _ErodeAgePow ("erodeAgePow", Float) = 1.5
        _ErodeInner ("erodeInner", Float) = 0.1
        _MaskTileV ("maskTileV", Float) = 0.8
        _MaskAgeDrift ("maskAgeDrift", Float) = 0.15
        _DetailGain ("detailGain", Float) = 1.6
        _HeadSoft ("headSoft", Float) = 0.005
        [HideInInspector] _SrcBlend ("", Float) = 5   // SrcAlpha; One for additive
        [HideInInspector] _DstBlend ("", Float) = 10  // OneMinusSrcAlpha; One for additive
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
        Pass
        {
            Blend [_SrcBlend] [_DstBlend]
            ZWrite Off
            Cull Off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            sampler2D _ShapeTex, _MaskTex, _HighlightTex;
            float4 _Color, _EdgeColor, _HighlightColor;
            float _Alpha, _Hdr, _WindowNarrow, _MaskAmount, _MaskTilePerM, _MaskPanPerS, _ErodeSpeed, _ErodeSharp;
            float _EdgeWidth, _EdgeGlow, _Highlight, _Additive, _Debug, _TrailTime;
            float _ErodeBase, _ErodeAgePow, _ErodeInner, _MaskTileV, _MaskAgeDrift, _DetailGain, _HeadSoft;
            struct appdata { float4 vertex : POSITION; float2 uv : TEXCOORD0; float2 uv1 : TEXCOORD1; };
            struct v2f { float4 pos : SV_POSITION; float2 uv : TEXCOORD0; float2 dist : TEXCOORD1; };   // dist.y = filled U
            v2f vert (appdata i) { v2f o; o.pos = UnityObjectToClipPos(i.vertex); o.uv = i.uv; o.dist = i.uv1; return o; }
            float4 frag (v2f i) : SV_Target
            {
                float x = i.uv.x, v = i.uv.y, xu = i.dist.y;   // x = age (dissolve/taper), xu = filled U (texture lookups)
                if (_Debug > 1.5) return float4(frac(i.dist.x).xxx, 1);
                if (_Debug > 0.5) return float4(xu, v, 0, 1);
                float sv = 1 - (1 - v) * (1 + _WindowNarrow * x);
                // Unity UV origin is bottom-left: the PNG's top row (outer edge) is at v = 1, so sample (x, sv) directly
                float shp = sv < 0 ? 0 : tex2D(_ShapeTex, float2(xu, sv)).r;
                float m = tex2D(_MaskTex, float2(i.dist.x * _MaskTilePerM + _TrailTime * _MaskPanPerS, v * _MaskTileV + x * _MaskAgeDrift)).r;
                float det = lerp(1, m * _DetailGain, _MaskAmount);
                float thr = _ErodeBase + pow(max(x, 0), _ErodeAgePow) * _ErodeSpeed + (1 - v) * _ErodeInner;
                float mg = m - thr;
                float keep = saturate(mg * _ErodeSharp);
                float edge = saturate(1 - mg / max(_EdgeWidth, 1e-3)) * keep;
                float hl = sv < 0 ? 0 : tex2D(_HighlightTex, float2(xu, sv)).r;
                float a = saturate(shp * det * keep * _Alpha * smoothstep(0, _HeadSoft, xu));
                float3 c = _Color.rgb * _Hdr + _EdgeColor.rgb * edge * _EdgeGlow + _HighlightColor.rgb * hl * _Highlight;
                // colours are already linear; in a Gamma-space project convert them on the C# side instead
                return _Additive > 0.5 ? float4(c * a, 1) : float4(c, a);
            }
            ENDCG
        }
    }
}
