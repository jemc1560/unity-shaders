
using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.PostProcessing;



// This is the settings class
[Serializable]
[PostProcess(typeof(PixelateRender), PostProcessEvent.AfterStack, "Custom/Pixelate")]
public sealed class Pixelate : PostProcessEffectSettings
{
    [Tooltip("Screensize")]
    
    public IntParameter screensize = new IntParameter { value = 144 };

    [Tooltip("Threshold")]
    public FloatParameter thres = new FloatParameter { value = 0.2f };


    [Tooltip("Edge Threshold")]
    public FloatParameter edgethres = new FloatParameter { value = 0.2f };








}

public sealed class PixelateRender : PostProcessEffectRenderer<Pixelate>
{
    public override DepthTextureMode GetCameraFlags()
    {
        return DepthTextureMode.DepthNormals;
    }

    public override void Render(PostProcessRenderContext context)
    {
        var sheet = context.propertySheets.Get(Shader.Find("Hidden/Custom/PixelateShader"));
        sheet.properties.SetInt("_Height", settings.screensize);
        int screenwidth = (int)(settings.screensize * context.camera.aspect + 0.5f);
        sheet.properties.SetInt("_Width",screenwidth);
        sheet.properties.SetVector("blockc", new Vector2(screenwidth, settings.screensize));
        sheet.properties.SetVector("blocksize", new Vector2(1.0f/screenwidth, 1.0f/settings.screensize));
        sheet.properties.SetVector("halfsize", new Vector2(0.5f / screenwidth, 0.5f / settings.screensize));
        sheet.properties.SetFloat("thres", settings.thres);
        sheet.properties.SetFloat("edgethres", settings.edgethres);
        context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);

        //var part2 = context.propertySheets.Get(Shader.Find("Hidden/Custom/asciishader"));
        //part2.properties.SetTexture("_ascii", settings.ascii);
        //context.command.BlitFullscreenTriangle(context.source, context.destination, part2, 0);
    }
}
