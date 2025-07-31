// Aaron Lanterman, July 22, 2021
// Modified example from https://github.com/Unity-Technologies/PostProcessing/wiki/Writing-Custom-Effects

Shader "Hidden/Custom/PixelateShader"
{
    HLSLINCLUDE

        #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"

        TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
		TEXTURE2D_SAMPLER2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture);
        TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);

        float4 _MainTex_TexelSize;
        float4 _MainTex_ST;
        SamplerState sampler_point_clamp;
        sampler2D _ascii;

        int _Height;
        int _Width;

        float thres;
        float edgethres;

       

        uniform float2 blockc;
        uniform float2 blocksize;
        uniform float2 halfsize;

        struct Attributes {
            float4 positionOS : POSITION;
            float2 uv : TEXCOORD0;
        };
        struct Varyings {
            float4 positionHCS : SV_POSITION;
            float2 uv : TEXCOORD0;
        };
        // Varyings vert(Attributes IN) {
        //     Varyings OUT;
        //     OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
        //     OUT.uv = TRANSFORM_TEX(IN.uv,_MainTex);
        //     return OUT;
        // }

        float character(int c, float2 pix) {
            float2 p = ((pix/4.0) % 2.0) - float2(1.0,1.0);
            
            p = p*float2(4.0, -4.0) + 2.5;

            if (clamp(p.x, 0.0, 4.0) == p.x)
	        {
                if (clamp(p.y, 0.0, 4.0) == p.y)	
		        {
        	        int a = int(round(p.x) + 5.0 * round(p.y));
			        if (((c >> a) & 1) == 1) return 1.0;
		        }	
            }
	        return 0.0;
        }
        //took these from my homework 5 since I didn't end up using it
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

        float edgedetect(float2 uvs,float t) {
            float gx = 0.0;
            float gy = 0.0;
            [unroll] for (int i =0; i<9; i++){
                float2 offset = textpoints[i] * t;
                float depth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, uvs + offset));
                gx += depth * sobelx[i];
                gy += depth * sobely[i];
            }
            return length(float2(gx, gy));     
        } 
       

        
        float4 Frag(Varyings IN) : SV_Target
        {
   //          float4 original = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);
			// float4 dn_enc = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, i.texcoord);
   //          float4 d_enc = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, i.texcoord);            
   //          float depth = Linear01Depth(d_enc);
   //          float depth = dot(float2(1.0, 1/255.0),dn_enc.zw);
			
   //          float3 n = DecodeViewNormalStereo(dn_enc);
			// float3 display_n = 0.5 * (1 + n);
            float4 d_enc = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, IN.uv);            
            float depth = Linear01Depth(d_enc);
            float4 dn_enc = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, IN.uv);
            float3 n = DecodeViewNormalStereo(dn_enc);
			float3 display_n = 0.5 * (1 + n);

   //  		return(float4(lerp(display_n,depth.xxx,0.5*(cos(_Speed * _Time.y) + 1)),1));
            float2 pos = floor(IN.uv * blockc);
            float2 center = pos * blocksize + halfsize;
            float4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_point_clamp,center);
            

            float lum = ((0.2126*tex.r) + (0.7152*tex.g) + (0.0722*tex.b));

            
            float color;
            if((1-depth) > thres) {
                float sobel = edgedetect(center,blocksize);
                if(sobel > edgethres) {
                    color = color = step(edgethres, sobel);
                } else {
                   lum = lum + (length(n.xy)*0.5);
                    float char = 4096;
                    if (lum > 0.2) char = 448;    // .
                    if (lum > 0.3) char = 131200;   // _
                    if (lum > 0.4) char = 459200; // =
                    if (lum > 0.5) char = 145536; // +
                    if (lum > 0.6) char = 4526404; // $
                    if (lum > 0.7) char = 13195790; // @
                    if (lum > 0.8) char = 11512810; // #
                    //char = 11512810;
                    float check = character(char, IN.positionHCS.xy);
                    if(check == 0.0) {
                        check = lum - (length(n.xy)*0.5);
                    }
                    color = check;
                } 
                
            } else {
                
                float lum = depth - thres;
                float char = 4096;

                if (lum > 0.2) char = 448;    // .
                if (lum > 0.3) char = 131200;   // _
                if (lum > 0.4) char = 459200; // =
                if (lum > 0.5) char = 145536; // +
                if (lum > 0.6) char = 4526404; // $
                if (lum > 0.7) char = 13195790; // @
                if (lum > 0.8) char = 11512810; // #
                //char = 11512810;
                float check = character(char, IN.positionHCS.xy);
                color = check;
                
            }
            
             
            return float4(color,color,color,1);
            

        }

    ENDHLSL

    SubShader {
        Cull Off ZWrite Off ZTest Always

        Pass {
            HLSLPROGRAM

                #pragma vertex VertDefault
                #pragma fragment Frag

            ENDHLSL
        }
    }
}
