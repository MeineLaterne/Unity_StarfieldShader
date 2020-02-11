// https://www.ronja-tutorials.com/2019/01/20/screenspace-texture.html
// https://youtu.be/rvDo9LvfoVE
// https://www.shadertoy.com/view/tlyGW3
Shader "Custom/Unlit/StarfieldUnlit"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Tint ("Tint", Color) = (0, 0, 0, 1)
        _GlowRate ("Glow Rate", Range(1., 10.)) = 1.
        _Flare ("Flare", Range(0., 1.)) = 1.
        _ScrollSpeed ("ScrollSpeed", Range(0.01, 1.)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            // #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #define NUM_LAYERS 6.

            struct appdata
            {
                float4 vertex : POSITION;
                //float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 screenPosition : TEXCOORD0;
                
                float4 position : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _Flare;
            float _GlowRate;
            float _ScrollSpeed;
            fixed4 _Tint;

            // generiert sowas wie eine Pseudozufallszahl
            float hash21(float2 p) {
                p = frac(p * float2(482.468, 176.89));
                p += dot(p, p + 45.89);
                return frac(p.x * p.y);
            }

            float star(float2 uv, float flare) {
                // Distanz von unserem Pixel zum origin
                float d = length(uv);
                // Glow
                float m = 0.025 / d;

                // Kreuzförmige Strahlen. Können über den Flare Parameter gesteuert werden
                float rays = max(0, 1 - (abs(uv.x * uv.y * 1024)));
                m += rays * flare;
                // hier faden wir den Glow wieder aus, damit wir keine harten Kanten zwischen den Zellen sehen 
                m *= smoothstep(.5, .2, d);
                return m;
            }

            fixed4 starLayer(float2 uv, float depth) {
                fixed4 col = 0;
                // grid uvs berechnen
                // frac gibt uns nur die Dezimalbruchstellen
                // also hat jede Zelle nun uvs zwischen 0 und 1
                // der Origin der Zellen ist die linke untere Ecke
                // um ihn in die Mitte zu setzen subtrahieren wir 0.5 
                float2 gv = frac(uv) - 0.5;
                // die cellId ist eindeutig für jede Zelle
                float2 cellId = floor(uv);

                // wir müssen die Farbwerte unserer Nachbarzellen mit berücksichtigen
                // deshalb iterieren wir kurz über unsere Nachbarn und schauen, was die so beizutragen haben
                for (int y = -1; y <= 1; y++) {
                    for (int x = -1; x <= 1; x++) {
                        // offset von unserer id (0, 0) zu den Nachbarn
                        float2 nId = float2(x, y);
                        // der offset der Sterne in ihren Zellen
                        float ofst = hash21(cellId + nId); // random zwischen 0 und 1

                        // Größe der Sterne
                        float size = 1. / depth;// max(0.1, frac(ofst * 486.98));

                        // wenn wir hier nun die grid uvs übergeben
                        // erhalten wir für jede Box einen Stern
                        // mit dem Vector, den wir zu gv addieren verschieben
                        // wir den Stern von seinem Ursprung (der Mitte der Zelle)
                        // allerdings können wir nicht die selbe Zahl für x und y verwenden,
                        // da die Sterne sonst diagonal angeordnet würden.
                        // hier muss der nId offset wieder rausgerechnet werden
                        // damit wir die korrekten uvs an die star funktion übergeben
                        float2 star_uvs = gv - nId - float2(ofst, frac(ofst * 32.)) + 0.5;

                        float s = star(star_uvs, smoothstep(0.9, 1.0, size) * _Flare); // flare abhängig von der Größe
                        // jeder Stern kriegt seine eigene Farbe
                        float4 sc = sin(_Tint * frac(ofst * 3845.85) * 6.2831) * 0.5 + 0.5;
                        // ein bisschen Grün rausfiltern
                        sc *= float4(.4, .26, .4, .4);
                        s *= sin(_Time.y * _GlowRate + ofst * 6.2831) * .2 + 1.;
                        col += s * size * sc;
                    }
                }

                return col;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.position = UnityObjectToClipPos(v.vertex);
                o.screenPosition = ComputeScreenPos(o.position);
                
                return o;
            }

            fixed4 frag(v2f i) : SV_Target {
                float2 uv = i.screenPosition.xy / i.screenPosition.w;
                float aspect = _ScreenParams.x / _ScreenParams.y;
                fixed4 col = 0;
                uv *= 4;
                
                // Verzerrung durch ungleiche Seitenlängen korrigieren
                uv.x *= aspect;
                uv = TRANSFORM_TEX(uv, _MainTex);
                float inc = 1. / NUM_LAYERS;
                float depth = 1.;
                //float t = _Time.y * _ScrollSpeed;
                for (float l = 0.; l < 1.; l += inc) {
                    // Geschwindigkeit ist abhängig von der depth des layers
                    // so bewegen sich weiter entfernte Sterne langsamer
                    float speed = _ScrollSpeed / depth;
                    uv.y += _Time.y * 0.1 * speed;
                    
                    col += starLayer(uv + l * 235.94, depth);
                    depth -= inc;
                }
                
                // grid visualisieren
                //float2 gv = frac(uv) - 0.5;
                //if (gv.x > 0.49 || gv.y > 0.49) col.r = 1.0;

                
                return col;
            }
            ENDCG
        }

        
    }
}
