using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

namespace UnityEditor.Rendering.FCShaderGraph
{
    public static class FERNSG_Resources
    {
        private static FernSG_Settings settings = Resources.Load<FernSG_Settings>("FernSGSettings");

        public static FernSG_Settings Settings
        {
            get
            {
                if (settings == null)
                {
                    settings = Resources.Load<FernSG_Settings>("FernSGSettings");
                }

                return settings;
            }
        }
        
        private static string kForwardPass;
        public static string KForwardPass
        {
            get
            {
                if (string.IsNullOrEmpty(kForwardPass))
                {
                   
                    if (Settings != null)
                    {
                        kForwardPass = AssetDatabase.GetAssetPath(Settings.CustomLitForwardPass);
                    }
                    else
                    {
                        kForwardPass = "Assets/FernNPRCore/FernShaderGraph/ShaderLibrary/CustomLitForwardPass.hlsl";
                    }
                }

                return kForwardPass;
            }
        
        }
        
        private static string kNPRLightingHLSL;
        public static string KNPRLightingHLSL
        {
            get
            {
                if (string.IsNullOrEmpty(kNPRLightingHLSL))
                {
                   
                    if (Settings != null)
                    {
                        kNPRLightingHLSL = AssetDatabase.GetAssetPath(Settings.NPRLighting);
                    }
                    else
                    {
                        kNPRLightingHLSL = "Assets/FernNPRCore/FernShaderGraph/ShaderLibrary/FernNPRLighting.hlsl";
                    }
                }
                return kNPRLightingHLSL;
            }
        
        }
        
        private static string kVaryings;
        public static string KVARYINGS
        {
            get
            {
                if (string.IsNullOrEmpty(kVaryings))
                {
                   
                    if (Settings != null)
                    {
                        kVaryings = AssetDatabase.GetAssetPath(Settings.Varying);
                    }
                    else
                    {
                        kVaryings = "Assets/FernNPRCore/FernShaderGraph/ShaderLibrary/kVaryings.hlsl";
                    }
                }
                return kVaryings;
            }
        
        }
        
        private static string kShadowCaster;
        public static string KSHADOWCASTER
        {
            get
            {
                if (string.IsNullOrEmpty(kShadowCaster))
                {
                   
                    if (Settings != null)
                    {
                        kShadowCaster = AssetDatabase.GetAssetPath(Settings.ShadowCaster);
                    }
                    else
                    {
                        kShadowCaster = "Assets/FernNPRCore/FernShaderGraph/ShaderLibrary/ShadowCasterPass.hlsl";
                    }
                }
                return kShadowCaster;
            }
        
        }
        
        private static string kShadow;
        public static string KSHADOW
        {
            get
            {
                if (string.IsNullOrEmpty(kShadow))
                {
                   
                    if (Settings != null)
                    {
                        kShadow = AssetDatabase.GetAssetPath(Settings.Shadow);
                    }
                    else
                    {
                        kShadow = "Assets/FernNPRCore/FernShaderGraph/ShaderLibrary/Shadows.hlsl";
                    }
                }
                return kShadow;
            }
        
        }
          
        // private static string kPBRGBufferPass;
        //
        // public static string KPBRGBufferPass
        // {
        //     get
        //     {
        //         if (string.IsNullOrEmpty(kForwardPass))
        //         {
        //            
        //             if (Settings != null)
        //             {
        //                 kPBRGBufferPass = AssetDatabase.GetAssetPath(Settings.CustomLitGBufferPass);
        //             }
        //             else
        //             {
        //                 kPBRGBufferPass = "Assets/Plugins/CustomShaderGraph/Shaders/CustomLitGBufferPass.hlsl";
        //             }
        //         }
        //
        //         Debug.Log(kPBRGBufferPass);
        //
        //         return kPBRGBufferPass;
        //     }
        // }
        //
        // private static string kCustomLitInternal;
        // public static string KCustomLitInternal
        // {
        //     get
        //     {
        //         if (string.IsNullOrEmpty(kForwardPass))
        //         {
        //            
        //             if (Settings != null)
        //             {
        //                 kCustomLitInternal = AssetDatabase.GetAssetPath(Settings.CustomSG_CustomLightingInternalFull);
        //             }
        //             else
        //             {
        //                 kCustomLitInternal = "Assets/Plugins/CustomShaderGraph/Shaders/CustomSG_CustomLightingInternalFull.hlsl";
        //             }
        //         }
        //         Debug.Log(kCustomLitInternal);
        //
        //         return kCustomLitInternal;
        //     }
        // }
        //
        // private static string customLitShader;
        // public static string CustomLitShader
        // {
        //     get
        //     {
        //         if (string.IsNullOrEmpty(kForwardPass))
        //         {
        //            
        //             if (Settings != null)
        //             {
        //                 customLitShader = AssetDatabase.GetAssetPath(Settings.customLitShader);
        //             }
        //             else
        //             {
        //                 customLitShader = "Assets/Plugins/CustomShaderGraph/Shaders/CustomSG_DefaultCustomLightingGraph.shadergraph";
        //             }
        //         }
        //         Debug.Log(customLitShader);
        //
        //         return customLitShader;
        //     }
        // }
    }

}

