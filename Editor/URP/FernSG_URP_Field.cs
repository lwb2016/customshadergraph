using System.Collections;
using System.Collections.Generic;
using UnityEditor.ShaderGraph;
using UnityEditor.ShaderGraph.Internal;
using UnityEngine;
using UnityEngine.Experimental.Rendering;

namespace UnityEditor.Rendering.FCShaderGraph
{
    static class FernSG_URP_Field
    {
        [GenerateBlocks("FURP ShaderGraph")]
        public struct VertexDescription
        {
            public static string name = "VertexDescription";
            
            public static BlockFieldDescriptor ShadowDepthBias = new BlockFieldDescriptor(FernSG_URP_Field.VertexDescription.name, "ShadowDepthBias", "Shadow Depth Bias", 
                "SURFACEDESCRIPTION_SHADOWDEPTHBIAS", new FloatControl(0), ShaderStage.Vertex);
            
            public static BlockFieldDescriptor ShadowNormalBias = new BlockFieldDescriptor(FernSG_URP_Field.VertexDescription.name, "ShadowNormalBias", "Shadow Normal Bias", 
                "SURFACEDESCRIPTION_SHADOWNormalBIAS", new FloatControl(0), ShaderStage.Vertex);
        }

        [GenerateBlocks("FURP ShaderGraph")]
        public struct SurfaceDescription
        {
            private static string name = "SurfaceDescription";

            public static BlockFieldDescriptor Shininess = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "Shininess", "Shininess", "SURFACEDESCRIPTION_SHININESS",
                new FloatControl(0.5f), ShaderStage.Fragment);

            public static BlockFieldDescriptor Glossiness = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "Glossiness", "Glossiness", "SURFACEDESCRIPTION_GLOSSINESS",
                new FloatControl(0.5f), ShaderStage.Fragment);
            
            public static BlockFieldDescriptor SpecularIntensity = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "SpecularIntensity", "SpecularIntensity", 
                "SURFACEDESCRIPTION_SPECULARINTENSITY", new FloatControl(1), ShaderStage.Fragment);
            
            public static BlockFieldDescriptor CellThreshold = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "CellThreshold", "Cell Threshold", 
                "SURFACEDESCRIPTION_CELLTHRESHOLD", new FloatControl(1), ShaderStage.Fragment);
            
            public static BlockFieldDescriptor CellSmoothness = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "CellSmoothness", "Cell Smoothness", 
                "SURFACEDESCRIPTION_CELLSMOOTHNESS", new FloatControl(1), ShaderStage.Fragment);
            
            public static BlockFieldDescriptor RampColor = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "RampColor", "Ramp Color", 
                "SURFACEDESCRIPTION_RAMPCOLOR", new ColorControl(Color.white, false), ShaderStage.Fragment); 
            
            public static BlockFieldDescriptor SpecularColor = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "SpecularColor", "Specular Color Mix", 
                "SURFACEDESCRIPTION_SPECULARCOLOR", new ColorControl(Color.white, false), ShaderStage.Fragment);
            
            public static BlockFieldDescriptor StylizedSpecularSize = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "StylizedSpecularSize", "Stylized SpecularSize", 
                "SURFACEDESCRIPTION_STYLIZESPECULARSIZE", new FloatControl(0.2f), ShaderStage.Fragment);
            
            public static BlockFieldDescriptor StylizedSpecularSoftness = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "StylizedSpecularSoftness", "Stylized Specular Softness", 
                "SURFACEDESCRIPTION_STYLIZEDSPECULARSOFTNESS", new FloatControl(0.1f), ShaderStage.Fragment);
            
            public static BlockFieldDescriptor GeometryAAStrength = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "GeometryAAStrength", "Geometry AA Strength", 
                "SURFACEDESCRIPTION_GEOMETRYAASTRENGTH", new FloatControl(1f), ShaderStage.Fragment);
            
            public static BlockFieldDescriptor GeometryAAVariant = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "GeometryAAVariant", "Geometry AA Variant", 
                "SURFACEDESCRIPTION_GEOMETRYAAVARIANT", new FloatControl(1f), ShaderStage.Fragment);
            
            
            public static BlockFieldDescriptor DarkColor = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "DarkColor", "Dark Color", 
                "SURFACEDESCRIPTION_DARKCOLOR", new ColorControl(Color.black, false), ShaderStage.Fragment);
            
            public static BlockFieldDescriptor LightenColor = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "LightenColor", "Lighten Color", 
                "SURFACEDESCRIPTION_LIGHTENCOLOR", new ColorControl(Color.white, false), ShaderStage.Fragment);
            
            public static BlockFieldDescriptor EnvReflection = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "EnvReflection", "Env Reflection", 
                "SURFACEDESCRIPTION_ENVREFLECTION", new ColorRGBAControl(Color.black), ShaderStage.Fragment);
            
            public static BlockFieldDescriptor EnvRotate = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "EnvRotate", "Env Rotation", 
                "SURFACEDESCRIPTION_ENVROTATION", new FloatControl(0), ShaderStage.Fragment);
            
            public static BlockFieldDescriptor EnvSpeularcIntensity = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "EnvSpecularIntensity", "Env Specular Intensity", 
                "SURFACEDESCRIPTION_ENVSPECULARINTENSITY", new FloatControl(1), ShaderStage.Fragment);
            
            public static BlockFieldDescriptor ClearCoatNormal = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "ClearCoatNormal", "Clear Coat Normal", 
                "SURFACEDESCRIPTION_CLEARCOATNORMAL", new NormalControl(CoordinateSpace.World), ShaderStage.Fragment);
            
            public static BlockFieldDescriptor ClearCoatTint = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "ClearCoatTint", "Coat Tint", 
                "SURFACEDESCRIPTION_CLEARCOATTINT", new ColorControl(Color.white, false), ShaderStage.Fragment);
            
            public static BlockFieldDescriptor ClearCoatSpecularIntensity = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "ClearCoatSpecularIntensity", "Clear Coat Specular Intensity", 
                "SURFACEDESCRIPTION_CLEARCOATSPECULARINTENSITY", new FloatControl(1), ShaderStage.Fragment);
            
            public static BlockFieldDescriptor PlanarReflectionIntensity = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "PlanarReflectionIntensity", "Planar Reflection Intensity", 
                "SURFACEDESCRIPTION_PLANARREFLECTIONINTENSITY",  new FloatControl(1), ShaderStage.Fragment);
            
            public static BlockFieldDescriptor Refraction = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "Refraction", "Refraction", 
                "SURFACEDESCRIPTION_REFRACTION", new ColorControl(Color.black, false), ShaderStage.Fragment);
            
            // Fabric
            public static BlockFieldDescriptor SheenColor = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "SheenColor", "Sheen Color", 
                "SURFACEDESCRIPTION_SHEENCOLOR", new ColorControl(Color.white, false), ShaderStage.Fragment);
            public static BlockFieldDescriptor Anisotropy = new BlockFieldDescriptor(FernSG_URP_Field.SurfaceDescription.name, "Anisotropy", "Anisotropy", 
                "SURFACEDESCRIPTION_ANISOTROPY", new FloatControl(0), ShaderStage.Fragment);

        }
    }
}

