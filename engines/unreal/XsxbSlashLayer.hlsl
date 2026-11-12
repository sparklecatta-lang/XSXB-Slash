// XSXB-Slash layer, body of ONE Material "Custom" node (recipe v1, docs/SPEC.md section 3).
// Custom node: Output Type = CMOT Float 4. Add these inputs (names must match exactly):
//   UV        <- TextureCoordinate (index 0)                        float2  (x = age, y = V: 0 inner, 1 outer)
//   Dist      <- TextureCoordinate (index 1) -> ComponentMask R     float   (metres along the tip path)
//   XU        <- TextureCoordinate (index 1) -> ComponentMask G     float   (filled U for texture lookups; see bFillTexture)
//   T         <- Time                                               float
//   ShapeTex, MaskTex, HlTex <- TextureObject parameters (Sampler Type = Linear Color / "Masks", sRGB OFF;
//                               shape & highlight Tiling = Clamp, mask Tiling = Wrap)
//   Color, EdgeColor, HlColor <- VectorParameter (linear RGB, feed .rgb)
//   Alpha, Hdr, WindowNarrow, MaskAmount, MaskTilePerM, MaskPanPerS, ErodeSpeed, ErodeSharp,
//   EdgeWidth, EdgeGlow, Highlight, Additive, DebugMode  <- ScalarParameter
// Material: Domain Surface, Shading Model Unlit, Two Sided, Blend Mode Translucent (alpha layers) or Additive (additive layers).
//   Emissive Color <- result.rgb      Opacity <- result.a
//   For the additive material the HLSL already multiplies rgb by a and returns a = 1.
// recipe.constants are inlined below (v1 values).

const float ErodeBase = -0.12, ErodeAgePow = 1.5, ErodeInner = 0.1, MaskTileV = 0.8, MaskAgeDrift = 0.15, DetailGain = 1.6, HeadSoft = 0.005;
float x = UV.x, v = UV.y, xu = XU;   // x = age (dissolve/taper), xu = filled U (texture lookups)
if (DebugMode > 1.5) return float4(frac(Dist).xxx, 1);
if (DebugMode > 0.5) return float4(xu, v, 0, 1);
float sv = 1 - (1 - v) * (1 + WindowNarrow * x);
// Unreal UV origin is top-left: the PNG's top row (outer edge) is at y = 0, so sample (x, 1 - sv)
float shp = sv < 0 ? 0 : Texture2DSample(ShapeTex, ShapeTexSampler, float2(xu, 1 - sv)).r;
float m = Texture2DSample(MaskTex, MaskTexSampler, float2(Dist * MaskTilePerM + T * MaskPanPerS, v * MaskTileV + x * MaskAgeDrift)).r;
float det = lerp(1, m * DetailGain, MaskAmount);
float thr = ErodeBase + pow(max(x, 0), ErodeAgePow) * ErodeSpeed + (1 - v) * ErodeInner;
float mg = m - thr;
float keep = saturate(mg * ErodeSharp);
float edge = saturate(1 - mg / max(EdgeWidth, 1e-3)) * keep;
float hl = sv < 0 ? 0 : Texture2DSample(HlTex, HlTexSampler, float2(xu, 1 - sv)).r;
float a = saturate(shp * det * keep * Alpha * smoothstep(0, HeadSoft, xu));
float3 c = Color * Hdr + EdgeColor * edge * EdgeGlow + HlColor * hl * Highlight;
return Additive > 0.5 ? float4(c * a, 1) : float4(c, a);
