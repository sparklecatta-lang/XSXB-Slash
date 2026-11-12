// XSXB-Slash trail for Unity (recipe v1, docs/SPEC.md). Builds one ribbon mesh per recipe layer.
// Setup: put on any GameObject; assign recipe.json (as TextAsset), the hilt and tip transforms of the blade,
// the three textures (import: sRGB OFF; shape/highlight Wrap=Clamp; mask Wrap=Repeat), and the XSXB-Slash/Layer shader.
// Project colour space should be Linear (recipe colours are linear).
using System;
using System.Collections.Generic;
using UnityEngine;
using Object = UnityEngine.Object;

public class XsxbSlashTrail : MonoBehaviour
{
    [Serializable] public class Layer
    {
        public string name, blend, shapeTexture;
        public float[] color, edgeColor, highlightColor;
        public float alpha, hdr, widthM, lifeS, taper, windowNarrow, maskAmount, maskTilePerM, maskPanPerS;
        public float erodeSpeed, erodeSharp, edgeWidth, edgeGlow, highlight;
    }
    [Serializable] public class Constants { public float erodeBase, erodeAgePow, erodeInner, maskTileV, maskAgeDrift, detailGain, headSoft; }
    [Serializable] public class Recipe { public int version; public Constants constants; public Layer[] layers; }

    public TextAsset recipe;
    public Transform hilt, tip;
    public Texture2D shapeTex, maskTex, highlightTex;
    public Shader shader;
    [Tooltip("Off = no new trail (existing trail fades out). Drive it from your attack windows / animation events for clean combos")] public bool emitting = true;
    [Tooltip("Tip speed (m/s) above which the blade counts as swinging")] public float minTipSpeed = 2f;
    [Tooltip("Samples per frame along a Catmull-Rom curve through the frame poses")] [Range(1, 16)] public int substeps = 6;
    [Tooltip("Stretch the shape/highlight textures over the whole visible trail (U = age / oldest age of the stroke), so their dark tail always lands on the trail end. Off = U is plain age, which cuts the texture while the trail is still growing")] public bool fillTexture = true;
    [Tooltip("Multiplies every layer width. Recipe widths assume a ~1 m blade; use your blade length in metres")] public float widthScale = 1f;
    [Range(0, 2)] public int debugMode;
    public int baseRenderQueue = 3000;

    class Sample { public Vector3 tip, dir; public float t, dist; public int swing; }
    struct Key { public Vector3 tip, hilt; public float t; }
    class Run { public Layer p; public Material mat; public Mesh mesh; public GameObject go; }
    readonly List<Run> runs = new List<Run>();
    readonly List<Sample> samples = new List<Sample>();   // shared by all layers; each layer draws the part younger than its life
    readonly List<Key> keys = new List<Key>();             // last frame poses of the current swing (Catmull-Rom control points)
    int provStart = -1; float provDist;                   // samples of the newest segment are provisional until the next frame
    Key prevKey; bool wasSwinging, hasPrev; float dist, maxLife; int swingId;
    readonly List<Vector3> pos = new List<Vector3>(); readonly List<Vector2> uv0 = new List<Vector2>(), uv1 = new List<Vector2>(); readonly List<int> idx = new List<int>();

    void Start() { if (runs.Count == 0) Init(); }

    /// <summary>Reads the recipe and creates one world-space mesh object per layer. Called by Start; call it yourself for edit-mode use.</summary>
    public void Init()
    {
        var r = JsonUtility.FromJson<Recipe>(recipe.text);
        for (int i = 0; i < r.layers.Length; i++)
        {
            var p = r.layers[i];
            var m = new Material(shader) { renderQueue = baseRenderQueue + i };
            bool add = p.blend == "additive";
            m.SetFloat("_SrcBlend", add ? 1 : 5); m.SetFloat("_DstBlend", add ? 1 : 10); m.SetFloat("_Additive", add ? 1 : 0);
            m.SetTexture("_ShapeTex", p.shapeTexture == "highlight" ? highlightTex : p.shapeTexture == "white" ? Texture2D.whiteTexture : shapeTex);
            m.SetTexture("_MaskTex", maskTex); m.SetTexture("_HighlightTex", highlightTex);
            m.SetVector("_Color", V(p.color)); m.SetVector("_EdgeColor", V(p.edgeColor)); m.SetVector("_HighlightColor", V(p.highlightColor));
            m.SetFloat("_Alpha", p.alpha); m.SetFloat("_Hdr", p.hdr); m.SetFloat("_WindowNarrow", p.windowNarrow);
            m.SetFloat("_MaskAmount", p.maskAmount); m.SetFloat("_MaskTilePerM", p.maskTilePerM); m.SetFloat("_MaskPanPerS", p.maskPanPerS);
            m.SetFloat("_ErodeSpeed", p.erodeSpeed); m.SetFloat("_ErodeSharp", p.erodeSharp); m.SetFloat("_EdgeWidth", p.edgeWidth);
            m.SetFloat("_EdgeGlow", p.edgeGlow); m.SetFloat("_Highlight", p.highlight);
            var c = r.constants;
            if (c != null)
            {
                m.SetFloat("_ErodeBase", c.erodeBase); m.SetFloat("_ErodeAgePow", c.erodeAgePow); m.SetFloat("_ErodeInner", c.erodeInner);
                m.SetFloat("_MaskTileV", c.maskTileV); m.SetFloat("_MaskAgeDrift", c.maskAgeDrift); m.SetFloat("_DetailGain", c.detailGain); m.SetFloat("_HeadSoft", c.headSoft);
            }
            var mesh = new Mesh { name = "XsxbSlashTrail_" + p.name }; mesh.MarkDynamic();
            var go = new GameObject("XsxbSlashTrail_" + p.name) { hideFlags = HideFlags.DontSave };   // not parented: vertices are world space
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            var mr = go.AddComponent<MeshRenderer>(); mr.sharedMaterial = m;
            mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; mr.receiveShadows = false; go.layer = gameObject.layer;
            runs.Add(new Run { p = p, mat = m, mesh = mesh, go = go }); maxLife = Mathf.Max(maxLife, p.lifeS);
        }
    }
    static Vector4 V(float[] a) => a != null && a.Length >= 3 ? new Vector4(a[0], a[1], a[2], 0) : Vector4.zero;

    void LateUpdate() => Step(Time.time, Time.deltaTime);

    /// <summary>Samples the blade and rebuilds the meshes. now = seconds, dt = time since the last Step.</summary>
    public void Step(float now, float dt)
    {
        dt = Mathf.Max(dt, 1e-5f);
        var cur = new Key { tip = tip.position, hilt = hilt.position, t = now };
        bool swinging = emitting && hasPrev && (cur.tip - prevKey.tip).magnitude / dt > minTipSpeed;
        if (swinging)
        {
            if (!wasSwinging) { swingId++; dist = 0; keys.Clear(); keys.Add(prevKey); AddSample(prevKey.tip, prevKey.hilt, prevKey.t); provStart = -1; }
            keys.Add(cur); if (keys.Count > 4) keys.RemoveAt(0);
            int n = keys.Count;
            if (n >= 3 && provStart >= 0)
            {
                // the next pose is known now: redraw the previous segment with full Catmull-Rom tangents
                samples.RemoveRange(provStart, samples.Count - provStart); dist = provDist;
                Segment(keys[n - 3], keys[n - 2], n >= 4, n >= 4 ? keys[n - 4] : default, true, keys[n - 1]);
            }
            provStart = samples.Count; provDist = dist;
            Segment(keys[n - 2], keys[n - 1], n >= 3, n >= 3 ? keys[n - 3] : default, false, default);
        }
        else provStart = -1;
        wasSwinging = swinging; prevKey = cur; hasPrev = true;
        int old = 0; while (old < samples.Count && now - samples[old].t > maxLife) old++;
        if (old > 0) { samples.RemoveRange(0, old); if (provStart >= 0) provStart = Mathf.Max(0, provStart - old); }
        foreach (var r in runs) { r.mat.SetFloat("_Debug", debugMode); r.mat.SetFloat("_TrailTime", now); Build(r, now); }
    }
    // Hermite segment a -> b. Tangents: Catmull-Rom (neighbour difference / 2) where the neighbour exists, else the chord.
    void Segment(Key a, Key b, bool hasBefore, Key before, bool hasAfter, Key after)
    {
        // spline the hilt position and the blade vector (tip - hilt) separately, then renormalise the blade:
        // a fast swing stays on its arc instead of cutting the corner
        Vector3 rA = a.tip - a.hilt, rB = b.tip - b.hilt;
        Vector3 mrA = hasBefore ? (rB - (before.tip - before.hilt)) * .5f : rB - rA, mrB = hasAfter ? ((after.tip - after.hilt) - rA) * .5f : rB - rA;
        Vector3 mhA = hasBefore ? (b.hilt - before.hilt) * .5f : b.hilt - a.hilt, mhB = hasAfter ? (after.hilt - a.hilt) * .5f : b.hilt - a.hilt;
        float lA = rA.magnitude, lB = rB.magnitude;
        Vector3 last = a.tip;
        for (int k = 1; k <= substeps; k++)
        {
            float f = (float)k / substeps;
            Vector3 hp = Herm(a.hilt, mhA, b.hilt, mhB, f), r = Herm(rA, mrA, rB, mrB, f);
            Vector3 tp = hp + (r.sqrMagnitude > 1e-12f ? r.normalized : rB.normalized) * Mathf.Lerp(lA, lB, f);
            dist += (tp - last).magnitude; last = tp;
            AddSample(tp, hp, Mathf.Lerp(a.t, b.t, f));
        }
    }
    static Vector3 Herm(Vector3 p0, Vector3 m0, Vector3 p1, Vector3 m1, float f)
    {
        float f2 = f * f, f3 = f2 * f;
        return (2 * f3 - 3 * f2 + 1) * p0 + (f3 - 2 * f2 + f) * m0 + (-2 * f3 + 3 * f2) * p1 + (f3 - f2) * m1;
    }
    void AddSample(Vector3 t, Vector3 h, float time)
    {
        samples.Add(new Sample { tip = t, dir = (t - h).normalized, t = time, dist = dist, swing = swingId });
    }
    void Build(Run r, float now)
    {
        float life = Mathf.Max(0.02f, r.p.lifeS);
        int first = 0; while (first < samples.Count && now - samples[first].t > life) first++;
        pos.Clear(); uv0.Clear(); uv1.Clear(); idx.Clear();
        float oldest = 1;
        for (int i = first; i < samples.Count; i++)
        {
            var s = samples[i]; int j = i - first; float age = Mathf.Clamp01((now - s.t) / life), w = r.p.widthM * widthScale * (1 - r.p.taper * age);
            if (j == 0 || samples[i - 1].swing != s.swing) oldest = Mathf.Max(age, 1e-3f);   // first sample of a stroke = its oldest
            float xu = fillTexture ? Mathf.Min(1, age / oldest) : age;
            pos.Add(s.tip - s.dir * w); uv0.Add(new Vector2(age, 0)); uv1.Add(new Vector2(s.dist, xu));   // inner
            pos.Add(s.tip);             uv0.Add(new Vector2(age, 1)); uv1.Add(new Vector2(s.dist, xu));   // outer
            if (j > 0 && samples[i - 1].swing == s.swing)
            {
                int a = (j - 1) * 2, b = j * 2;
                idx.Add(a); idx.Add(b); idx.Add(a + 1); idx.Add(a + 1); idx.Add(b); idx.Add(b + 1);
            }
        }
        r.mesh.Clear(); r.mesh.SetVertices(pos); r.mesh.SetUVs(0, uv0); r.mesh.SetUVs(1, uv1); r.mesh.SetTriangles(idx, 0); r.mesh.RecalculateBounds();
    }
    void OnDestroy() { foreach (var r in runs) { Kill(r.go); Kill(r.mesh); Kill(r.mat); } runs.Clear(); }
    static void Kill(Object o) { if (!o) return; if (Application.isPlaying) Destroy(o); else DestroyImmediate(o); }
}
