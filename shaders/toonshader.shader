Shader "Custom/toonshader"
{
    Properties
    {
        _Color ("Base Color", Color) = (1,1,1,1)
        _Shadow("Shadow Color", Color) = (1,1,1,1)
        _shadowamount("shadow amount", Range(0.0, 1.0)) = 0.5
        _midtone("midtone amount", Range(0.0, 1.0)) = 0.51
       
        _OutlineColor("Line Color", Color) = (0,0,0,1)
        _Thickness("Line Thickness",Float) = 1.0

        _Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5
        _GlossMapScale("Smoothness Scale", Range(1.0, 10.0)) = 1.0
        [Enum(Metallic Alpha,0,Albedo Alpha,1)] _SmoothnessTextureChannel ("Smoothness texture channel", Float) = 0

        [Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        _MetallicGlossMap("Metallic", 2D) = "white" {}

        _BumpScale("Scale", Float) = 1.0
        _BumpMap("Normal Map", 2D) = "bump" {}

        _Parallax ("Height Scale", Range (0.005, 0.08)) = 0.02
        _ParallaxMap ("Height Map", 2D) = "black" {}

        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        _OcclusionMap("Occlusion", 2D) = "white" {}

        _EmissionColor("Color", Color) = (0,0,0)
        _EmissionMap("Emission", 2D) = "white" {} _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        //#pragma surface surf MyStandard fullforwardshadows vertex:vert
        #pragma surface surf MyStandard fullforwardshadows finalcolor:Noisefunc
        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        struct Input
        {
            float2 uv_MainTex;
            float3 viewDir; 
            float4 screenPos;
            float3 lightDir;
        };

        
        float4 _Shadow;
        float _shadowamount;
        float _midtone;
        float4 _OutlineColor;
        float _Thickness;
        sampler2D _CameraDepthTexture;

        half4       _Color;
        

        sampler2D   _MainTex;
  
        sampler2D   _BumpMap;
        half        _BumpScale;

        sampler2D   _SpecGlossMap;
        sampler2D   _MetallicGlossMap;
        half        _Metallic;
        float       _Glossiness;
        float       _GlossMapScale;

        sampler2D   _OcclusionMap;
        half        _OcclusionStrength;

        sampler2D   _ParallaxMap;
        half        _Parallax;

        half4       _EmissionColor;
        sampler2D   _EmissionMap;

// From UnityPBSLighting.cginc
        struct MySurfaceOutputStandard {
            fixed3 Albedo;      // base (diffuse or specular) color
            float3 Normal;      // tangent space normal, if written
            half3 Emission;
            half Metallic;      // 0=non-metal, 1=metal
            // Smoothness is the user facing name, it should be perceptual smoothness but user should not have to deal with it.
            // Everywhere in the code you meet smoothness it is perceptual smoothness
            half Smoothness;    // 0=rough, 1=smooth
            half Occlusion;     // occlusion (default 1)
            fixed Alpha;        // alpha for transparencies
        };

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        // Copied from LightingStandard_GI in UnityPBSLighting.cginc
        inline void LightingMyStandard_GI (MySurfaceOutputStandard s, UnityGIInput data, inout UnityGI gi) {
            #if defined(UNITY_PASS_DEFERRED) && UNITY_ENABLE_REFLECTION_BUFFERS
                gi = UnityGlobalIllumination(data, s.Occlusion, s.Normal);
            #else
               Unity_GlossyEnvironmentData g = UnityGlossyEnvironmentSetup(s.Smoothness, data.worldViewDir, s.Normal, lerp(unity_ColorSpaceDielectricSpec.rgb, s.Albedo, s.Metallic));
                gi = UnityGlobalIllumination(data, s.Occlusion, s.Normal, g);
            #endif
        }

        // Copied from LightingStandard in UnityPBSLighting.cginc
        inline half4 LightingMyStandard (MySurfaceOutputStandard s, float3 viewDir, UnityGI gi) {
            s.Normal = normalize(s.Normal);
            float ndotl = dot(s.Normal, normalize(gi.light.dir));
            
            ndotl = ndotl * 0.5 + 0.5;
            float3 h = normalize((gi.light.dir + viewDir)/2);
            half4 c;
            
            
            half4 midtone = (_Shadow+_Color)/2;
        
            float check1 = step(_shadowamount, ndotl);
            float check2 = step(_midtone, ndotl);

            // to include the baked light from the probes? (looks bad)
            // c.rgb = _Shadow.rgb *(1-check1)*(1-check2) + 
            //    midtone.rgb * (check1) * (1-check2) +
            //    _Color.rgb * gi.light.color * (check2)*(check1) + gi.indirect.diffuse;
            
            c.rgb = _Shadow.rgb *(1-check1)*(1-check2) + (
               midtone.rgb * (check1) * (1-check2) +
               _Color.rgb * (check2)*(check1))*(gi.light.color);

            if(ndotl == 1) {
                //not sure if this does anything maybe vaguely
                c.rgb = c.rgb* gi.indirect.specular*(dot(s.Normal,h));
            }

            c.a = 1;
       
            return c;
        }
      
        // I folded UnpackNormalmapRGorAG into this -- all in UnityCG.cginc
        inline fixed3 MyUnpackNormal(fixed4 packednormal) {
            #if defined(UNITY_NO_DXT5nm)
                return packednormal.xyz * 2 - 1;
            #else
                // Unpack normal as DXT5nm (1, y, 1, x) or BC5 (x, y, 0, 1)
                // Note neutral texture like "bump" is (0, 0, 1, 1) to work with both plain RGB normal and DXT5nm/BC5
                // This do the trick
                packednormal.x *= packednormal.w;

                fixed3 normal;
                normal.xy = packednormal.xy * 2 - 1;
                normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));
                return normal;
            #endif
        }

        // I folded UnpackScaleNormalRGorAG into UnpackScaleNormal -- all in UnityStandardUtils.cginc
        half3 MyUnpackScaleNormal(half4 packednormal, half bumpScale) {
            #if defined(UNITY_NO_DXT5nm)
                half3 normal = packednormal.xyz * 2 - 1;
                normal.xy *= bumpScale;
                return normal;
            #else
                // This do the trick
                packednormal.x *= packednormal.w;

                half3 normal;
                normal.xy = (packednormal.xy * 2 - 1);
                normal.xy *= bumpScale;
                normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));
                return normal;
            #endif
        }

        // From UnityStandardUtils.cginc
        half3 MyBlendNormals(half3 n1, half3 n2) {
            return normalize(half3(n1.xy + n2.xy, n1.z*n2.z));
        }

        // From UnityStandardInput.cginc
        half3 MyNormalInTangentSpace(float2 texcoords) {
            half3 normalTangent = UnpackScaleNormal(tex2D(_BumpMap, texcoords), _BumpScale);

            return normalTangent;
        }

        // From UnityStandardInput.cginc
        // Why bother returning 0? Why not just include "else" line directly in a the shader code,
        // bypassing it entirely if the _EMISSION flag isn't set? I'm not sure why they broke
        // this out as a subroutine.
        // half3 MyEmission(float2 uv) {
        //     #ifndef _EMISSION
        //         return 0;
        //     #else
        //         return tex2D(_EmissionMap, uv).rgb * _EmissionColor.rgb;
        //     #endif
        // }
        
        // From UnityStandardInput.cginc
        // StandardShaderGUI.cs custom inspector
        half4 MyAlbedo(float2 texcoords) {
            half4 check = _Color.rgba;
           
            return check;
        }
        //pseudo-random function stolen off unity docs
        float randomrange(float2 Seed, float Min, float Max) {
            float randomno =  frac(sin(dot(Seed, float2(12.9898, 78.233)))*43758.5453);
             float Out = lerp(Min, Max, randomno);
            return Out;
        }

        void Noisefunc (Input IN, MySurfaceOutputStandard o, inout half4 color) {
            
            float check = tex2D(_MainTex, IN.uv_MainTex).r;
            float rand = randomrange(IN.uv_MainTex.x*IN.uv_MainTex.y, -0.5,0.5);
            float ndotl = dot(normalize(o.Normal),normalize(IN.lightDir));
            //uncomment this and ur computer will get more angry 
            // unsure the ENTIRE obj has noice
            //ndotl = ndotl * 0.5 + 0.5;
            half4 midcolor = (_Shadow+_Color)/2;
            float midpoint = (_midtone + _shadowamount)/2;
            if(ndotl <  _midtone+0.08+rand && ndotl >  _midtone-0.08-rand ) {
                //color = lerp(color, _Color, check);
                color = check* color + (1-check)*midcolor;
            } else if (ndotl <  _shadowamount+0.08+rand && ndotl >  _shadowamount-0.08-rand ) {
                color = check* color + (1-check)*_Shadow;
            }
        }
          

        // From UnityStandardInput.cginc
        half MyOcclusion(float2 uv) {
            half occ = tex2D(_OcclusionMap, uv).g;
            return LerpOneTo (occ, _OcclusionStrength);
        }

        // From UnityStandardInput.cginc -- for Metallic workflow
        // This routine puts Metallic in the "red" channel and Smoothness in the "green" channel
        // Note the Standard Shader code often uses the term "Gloss" to refer to Smoothness
        half2 MyMetallicGloss(float2 uv) {
            half2 mg;
            #ifdef _METALLICGLOSSMAP
                #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A // Smoothness source Albedo Alpha
                    mg.r = tex2D(_MetallicGlossMap, uv).r; // Associated with "metallicMap" in StandardShaderGUI.cs
                    mg.g = tex2D(_MainTex, uv).a;
                #else // Smoothness source Metallic Alpha 
                    mg = tex2D(_MetallicGlossMap, uv).ra;
                #endif
                mg.g *= _GlossMapScale; // Associated with "smoothnessScale" in StandardShaderGUI.cs
            #else
                mg.r = _Metallic;
                #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A // Smoothness source Albedo Alpha
                    mg.g = tex2D(_MainTex, uv).a * _GlossMapScale;
                #else
                    mg.g = _Glossiness; // Associated with "smoothness" in StandardShaderGUI.cs
                #endif
            #endif
            return mg;
        }

        // From UnityStandardUtils.cginc
        // Same as ParallaxOffset in Unity CG, except:
        //  *) precision - half instead of float
        // I HALF WAY UNDERSTAND THIS 
        half2 MyParallaxOffset1Step (half h, half height, half3 viewDir) {
            h = h * height - height/2.0;
            half3 v = normalize(viewDir);
            v.z += 0.42;
            return h * (v.xy / v.z);
        }

         half3 MyEmission(float2 uv) {
            #ifndef _EMISSION
                return 0;
            #else
                return tex2D(_EmissionMap, uv).rgb * _EmissionColor.rgb;
            #endif
        }

        // From UnityStandardUtils.cginc
        float2 MyParallax (float2 texcoords, half3 viewDir) {
            #if !defined(_PARALLAXMAP) 
                return texcoords;
            #else
                half h = tex2D (_ParallaxMap, texcoords.xy).g;
                float2 offset = MyParallaxOffset1Step (h, _Parallax, viewDir);
                return float2(texcoords + offset);
            #endif
        }

        //ignore this it doesnt work yet
        uniform float2 textpoints[9] = {
            float2(-1,1), float2(0,1), float2(1,1),
            float2(-1,0), float2(0,0), float2(1,0),
            float2(-1,-1), float2(0,-1), float2(1,-1)
        };

        uniform float sobely[9] = {
            1, 0, -1,
            2, 0, -2,
            1, 0, -1
        };
        uniform float sobelx[9] = {
            1, 2, 1,
            0, 0, 0, 
            -1, -2, -1
        };
        // void edgedetect_float(float2 uvs,float t, out float sobel) {
        //     float sobel = 0;
        //     [unroll] for (int i =0; i<9; i++){
        //         float depth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,uvs + textpoints[i] * t ));
        //         depth = depth * max(sobelx[i], sobely[i]);
        //         const float2 Kernel = float2(sobelx[Iterator], sobely[Iterator]);

        //         sobel += depth * kernel;
        //     SobelX += Normal.x * Kernel;
        //     SobelY += Normal.y * Kernel;
        //     SobelZ += Normal.z * Kernel;
        //     }
        //     return length(sobel);
        //     Output.NormalSobel = max(max(length(SobelX), length(SobelY)), length(SobelZ));
       
        // }

        void surf (Input IN, inout MySurfaceOutputStandard o) {
            float2 texcoords = IN.uv_MainTex;
            // float2 ssuvs = IN.screenPos.xy / IN.screenPos.w;
            // float depth;
            // depth = saturate(edgedetect_float(ssuvs, depth));

            half4 color = MyAlbedo(texcoords);
            o.Albedo = color.rgb;
            o.Alpha = 1;
            
            //This seems strange to me; I think it would be more efficient to use
            //the _EMISSION flag to bypass this altogether if emission not used
            o.Emission = MyEmission(texcoords);
             #ifdef _NORMALMAP
                // if you write to the Normal, write the *tangent space* normal
                o.Normal = MyNormalInTangentSpace(texcoords);
            #endif 

            // This seems strange to me; I think it would be more efficient to use
            // the _EMISSION flag to bypass this altogether if emission not used

            o.Occlusion = MyOcclusion(texcoords);

            float2 mg_result = MyMetallicGloss(texcoords);
            o.Metallic = mg_result.r;
            o.Smoothness = mg_result.g;

        }
        ENDCG
    }
    FallBack "Diffuse"
    //CustomEditor "MySimplerStandardShaderGUI"
   
}

