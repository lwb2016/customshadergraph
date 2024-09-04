using System;
using System.Linq;
using System.Collections.Generic;
using UnityEditor;
using UnityEditor.Rendering.Universal;
using UnityEditor.Rendering.Universal.ShaderGraph;
using UnityEditor.Rendering.Universal.ShaderGUI;
using UnityEngine;
using UnityEditor.ShaderGraph;
using UnityEngine.UIElements;
using UnityEditor.ShaderGraph.Legacy;
using UnityEngine.Assertions;
using static UnityEditor.Rendering.Universal.ShaderGraph.SubShaderUtils;
using UnityEngine.Rendering.Universal;
using static Unity.Rendering.Universal.ShaderUtils;

namespace UnityEditor.Rendering.FCShaderGraph
{
    sealed class FernSG_UniversalLitSubTarget : FERNSGUniversalSubTarget
    {
        struct LitSubTargetParams
        {
            public DiffusionModel diffusionModel;
            public SpecularModel specularModel;
            public EnvReflectionMode envReflectionMode;
            public bool clearCoatNormal;
            public bool depthNormal;
            public bool planarReflection;
            public bool ssgi;
            public bool _2D;
            public bool screenSpaceRim;
            public FeatureType geometryAA;
            public FeatureType clearCoat;
            public FeatureType refraction;
            public FeatureType envRotate;
            public FeatureType customShadowBias;
            
            // keyword
            public bool m_ScreenSpaceAmbientOcclusion;
            public bool m_StaticLightmap;
            public bool m_DynamicLightmap;
            public bool m_DirectionalLightmapCombined;
            public bool m_AdditionalLights;
            public bool m_AdditionalLightShadows;
            public bool m_ReflectionProbeBlending;
            public bool m_ReflectionProbeBoxProjection;
            public bool m_LightmapShadowMixing;
            public bool m_ShadowsShadowmask;
            public bool m_DBuffer;
            public bool m_LightLayers;
            public bool m_DebugDisplay;
            public bool m_LightCookies;
            public bool m_ForwardPlus;
            public bool m_Fog;
        }
        
        static readonly GUID  kSourceCodeGuid = new GUID("e4ef4696bb14c1247ba0fb6729c65607"); // FernSG_UniversalLitSubTarget.cs
        
        public override int latestVersion => 2;

        public FernSG_UniversalLitSubTarget()
        {
            displayName = "Lit Pro";
        }
        
        protected override ShaderID shaderID => ShaderID.SG_Lit;
        
        [SerializeField] DiffusionModel m_DiffusionModel = DiffusionModel.Lambert;
        public DiffusionModel diffusionModel
        {
            get => m_DiffusionModel;
            set => m_DiffusionModel = value;
        }
        [SerializeField] SpecularModel m_SpecularModel = SpecularModel.GGX;
        public SpecularModel specularModel
        {
            get => m_SpecularModel;
            set => m_SpecularModel = value;
        }

        private LitSubTargetParams m_litSubTargetParams;

        public override void Setup(ref TargetSetupContext context)
        {
            context.AddAssetDependency(kSourceCodeGuid, AssetCollection.Flags.SourceDependency);
            base.Setup(ref context);

            var universalRPType = typeof(UnityEngine.Rendering.Universal.UniversalRenderPipelineAsset);
            if (!context.HasCustomEditorForRenderPipeline(universalRPType))
            {
                var gui = typeof(FURPShaderGraphLitGUI);
#if HAS_VFX_GRAPH
                if (TargetsVFX())
                    gui = typeof(VFXShaderGraphLitGUI);
#endif
                context.AddCustomEditorForRenderPipeline(gui.FullName, universalRPType);
            }

            // setup subtargetparas
            m_litSubTargetParams.diffusionModel = diffusionModel;
            m_litSubTargetParams.specularModel = specularModel;
            m_litSubTargetParams.envReflectionMode = envReflectionMode;
            m_litSubTargetParams.geometryAA = geometryAA;
            m_litSubTargetParams.clearCoat = clearCoat;
            m_litSubTargetParams.clearCoatNormal = clearCoatNormal;
            m_litSubTargetParams.depthNormal = depthNormal;
            m_litSubTargetParams.planarReflection = planarReflection;
            m_litSubTargetParams.ssgi = ssgi;
            m_litSubTargetParams.refraction = refraction;
            m_litSubTargetParams._2D = _2D;
            m_litSubTargetParams.envRotate = envRotate;
            m_litSubTargetParams.customShadowBias = customShadowBias;

            m_litSubTargetParams.m_ScreenSpaceAmbientOcclusion = m_ScreenSpaceAmbientOcclusion;
            m_litSubTargetParams.m_StaticLightmap = m_StaticLightmap;
            m_litSubTargetParams.m_DynamicLightmap = m_DynamicLightmap;
            m_litSubTargetParams.m_DirectionalLightmapCombined = m_DirectionalLightmapCombined;
            m_litSubTargetParams.m_AdditionalLights = m_AdditionalLights;
            m_litSubTargetParams.m_AdditionalLightShadows = m_AdditionalLightShadows;
            m_litSubTargetParams.m_ReflectionProbeBlending = m_ReflectionProbeBlending;
            m_litSubTargetParams.m_ReflectionProbeBoxProjection = m_ReflectionProbeBoxProjection;
            m_litSubTargetParams.m_LightmapShadowMixing = m_LightmapShadowMixing;
            m_litSubTargetParams.m_ShadowsShadowmask = m_ShadowsShadowmask;
            m_litSubTargetParams.m_DBuffer = m_DBuffer;
            m_litSubTargetParams.m_LightLayers = m_LightLayers;
            m_litSubTargetParams.m_DebugDisplay = m_DebugDisplay;
            m_litSubTargetParams.m_LightCookies = m_LightCookies;
            m_litSubTargetParams.m_ForwardPlus = m_ForwardPlus;
            m_litSubTargetParams.m_Fog = m_Fog;

            // Process SubShaders
            context.AddSubShader(PostProcessSubShader(SubShaders.LitSubShader(target, workflowMode, m_litSubTargetParams,
                target.renderType, target.renderQueue, target.disableBatching, blendModePreserveSpecular)));
        }


        public override void GetActiveBlocks(ref TargetActiveBlockContext context)
        {
            base.GetActiveBlocks(ref context);
            
            // Fragment
            context.AddBlock(FernSG_URP_Field.SurfaceDescription.LightenColor);
            context.AddBlock(FernSG_URP_Field.SurfaceDescription.DarkColor);
            context.AddBlock(BlockFields.SurfaceDescription.CoatMask, clearCoat != FeatureType.None);
            context.AddBlock(BlockFields.SurfaceDescription.CoatSmoothness, clearCoat != FeatureType.None);
            context.AddBlock(FernSG_URP_Field.SurfaceDescription.ClearCoatNormal, clearCoatNormal);
            context.AddBlock(FernSG_URP_Field.SurfaceDescription.ClearCoatTint, clearCoat != FeatureType.None);
            context.AddBlock(FernSG_URP_Field.SurfaceDescription.ClearCoatSpecularIntensity, clearCoat != FeatureType.None);
            context.AddBlock(FernSG_URP_Field.SurfaceDescription.SpecularColor);
            context.AddBlock(FernSG_URP_Field.SurfaceDescription.Refraction, refraction != FeatureType.None);
            context.AddBlock(FernSG_URP_Field.SurfaceDescription.CellThreshold, diffusionModel == DiffusionModel.Cell);
            context.AddBlock(FernSG_URP_Field.SurfaceDescription.CellSmoothness, diffusionModel == DiffusionModel.Cell);
            context.AddBlock(FernSG_URP_Field.SurfaceDescription.RampColor, diffusionModel == DiffusionModel.Ramp);
            context.AddBlock(FernSG_URP_Field.SurfaceDescription.SpecularColor);
            context.AddBlock(FernSG_URP_Field.SurfaceDescription.Anisotropy, specularModel == SpecularModel.Aniso);
            context.AddBlock(FernSG_URP_Field.SurfaceDescription.StylizedSpecularSize,
                specularModel == SpecularModel.STYLIZED);
            context.AddBlock(FernSG_URP_Field.SurfaceDescription.StylizedSpecularSoftness,
                specularModel == SpecularModel.STYLIZED);

        }

        public override void CollectShaderProperties(PropertyCollector collector, GenerationMode generationMode)
        {
            base.CollectShaderProperties(collector, generationMode);
            if (target.allowMaterialOverride)
            {
                if(geometryAA == FeatureType.Toggle)
                    collector.AddToggleProperty(FernProperty.GeometryAA, true);
                if(clearCoat == FeatureType.Toggle)
                    collector.AddToggleProperty(FernProperty.ClearCoat, true);
                if(envRotate == FeatureType.Toggle)
                    collector.AddToggleProperty(FernProperty.EnvRotate, true);
                if(customShadowBias == FeatureType.Toggle)
                    collector.AddToggleProperty(FernProperty.CustomShadowBias, true);
            }
        }

        public override void GetPropertiesGUI(ref TargetPropertyGUIContext context, Action onChange,
            Action<String> registerUndo)
        {
            
            base.GetPropertiesGUI(ref context, onChange, registerUndo);

            if (fernControlFoldout)
            {
                context.AddProperty("Diffusion Model", 1,
                    new EnumField(DiffusionModel.Lambert) { value = diffusionModel }, (evt) =>
                    {
                        if (Equals(diffusionModel, evt.newValue))
                            return;

                        registerUndo("Change Diffusion Model");
                        diffusionModel = (DiffusionModel)evt.newValue;
                        onChange();
                    });

                context.AddProperty("Specular Model", 1, new EnumField(SpecularModel.GGX) { value = specularModel },
                    (evt) =>
                    {
                        if (Equals(specularModel, evt.newValue))
                            return;

                        registerUndo("Change Specular Model");
                        specularModel = (SpecularModel)evt.newValue;
                        onChange();
                    });
            }
        }

        public override bool TryUpgradeFromMasterNode(IMasterNode1 masterNode,
            out Dictionary<BlockFieldDescriptor, int> blockMap)
        {
            blockMap = null;
            if (!(masterNode is PBRMasterNode1 pbrMasterNode))
                return false;

            normalDropOffSpace = (NormalDropOffSpace)pbrMasterNode.m_NormalDropOffSpace;

            // Handle mapping of Normal block specifically
            BlockFieldDescriptor normalBlock;
            switch (normalDropOffSpace)
            {
                case NormalDropOffSpace.Object:
                    normalBlock = BlockFields.SurfaceDescription.NormalOS;
                    break;
                case NormalDropOffSpace.World:
                    normalBlock = BlockFields.SurfaceDescription.NormalWS;
                    break;
                default:
                    normalBlock = BlockFields.SurfaceDescription.NormalTS;
                    break;
            }

            // Set blockmap
            blockMap = new Dictionary<BlockFieldDescriptor, int>()
            {
                { BlockFields.VertexDescription.Position, 9 },
                { BlockFields.VertexDescription.Normal, 10 },
                { BlockFields.VertexDescription.Tangent, 11 },
                { BlockFields.SurfaceDescription.BaseColor, 0 },
                { normalBlock, 1 },
                { BlockFields.SurfaceDescription.Emission, 4 },
                { BlockFields.SurfaceDescription.Smoothness, 5 },
                { BlockFields.SurfaceDescription.Occlusion, 6 },
                { BlockFields.SurfaceDescription.Alpha, 7 },
                { BlockFields.SurfaceDescription.AlphaClipThreshold, 8 },
                { FernSG_URP_Field.SurfaceDescription.DarkColor, 12 },
                { FernSG_URP_Field.SurfaceDescription.LightenColor, 13 },
            };

            // PBRMasterNode adds/removes Metallic/Specular based on settings
            if (workflowMode == WorkflowMode.Specular)
                blockMap.Add(BlockFields.SurfaceDescription.Specular, 3);
            else if (workflowMode == WorkflowMode.Metallic)
                blockMap.Add(BlockFields.SurfaceDescription.Metallic, 2);

            return true;
        }

        static class SubShaders
        {
            public static readonly PragmaCollection PlanarReflectionForward = new PragmaCollection
            {
                { Pragma.Target(ShaderModel.Target20) },
                { Pragma.MultiCompileInstancing },
                { Pragma.MultiCompileFog },
                { Pragma.InstancingOptions(InstancingOptions.RenderingLayer) },
                { Pragma.Vertex("vert") },
                { Pragma.Fragment("frag_PlanarReflection") },
            };
            
            // TODO: Should be changed to common code
            public static readonly PragmaCollection SSGIForward = new PragmaCollection
            {
                { Pragma.Target(ShaderModel.Target20) },
                { Pragma.MultiCompileInstancing },
                { Pragma.InstancingOptions(InstancingOptions.RenderingLayer) },
                { Pragma.Vertex("vert") },
                { Pragma.Fragment("frag") },
            };

            public static SubShaderDescriptor LitSubShader(UniversalTarget target,WorkflowMode workflowMode,
                LitSubTargetParams litSubTargetParams, string renderType, string renderQueue, string disableBatchingTag,
                bool blendModePreserveSpecular)
            {
                SubShaderDescriptor result = new SubShaderDescriptor()
                {
                    pipelineTag = UniversalTarget.kPipelineTag,
                    customTags = UniversalTarget.kLitMaterialTypeTag,
                    renderType = renderType,
                    renderQueue = renderQueue,
                    disableBatchingTag = disableBatchingTag,
                    generatesPreview = true,
                    passes = new PassCollection()
                };

                result.passes.Add(LitPasses.Forward(target, workflowMode, litSubTargetParams, blendModePreserveSpecular,
                    null, LitKeywords.FernForward));

                // TODO: GBuffer
                result.passes.Add(LitPasses.GBuffer(target, workflowMode, blendModePreserveSpecular));

                // cull the shadowcaster pass if we know it will never be used
                if (target.castShadows || target.allowMaterialOverride)
                    result.passes.Add(PassVariant(LitPasses.ShadowCaster(target, litSubTargetParams), CorePragmas.Instanced));

                if (target.mayWriteDepth)
                    result.passes.Add(PassVariant(FernCorePasses.DepthOnly(target), CorePragmas.Instanced));

                if (litSubTargetParams.depthNormal)
                    result.passes.Add(PassVariant(LitPasses.DepthNormal(target), CorePragmas.Instanced));

                if (litSubTargetParams.planarReflection)
                    result.passes.Add(LitPasses.PlanarReflectionForward(target, workflowMode, litSubTargetParams,
                        blendModePreserveSpecular,
                        PlanarReflectionForward, LitKeywords.FernPlanarReflectionForward)); 
                
                if (litSubTargetParams.ssgi)
                    result.passes.Add(LitPasses.SSGIBaseColorForward(target, litSubTargetParams,
                        blendModePreserveSpecular,
                        SSGIForward, LitKeywords.FernSSGIKeywords));

                result.passes.Add(LitPasses.Meta(target));
                // Currently neither of these passes (selection/picking) can be last for the game view for
                // UI shaders to render correctly. Verify [1352225] before changing this order.
                result.passes.Add(PassVariant(FernCorePasses.SceneSelection(target), CorePragmas.Default));
                result.passes.Add(PassVariant(FernCorePasses.ScenePicking(target), CorePragmas.Default));

                if (litSubTargetParams._2D)
                    result.passes.Add(PassVariant(LitPasses._2D(target), CorePragmas.Default));

                return result;
            }
        }
        static class LitPasses
        {
            public static PassDescriptor Forward(
                UniversalTarget target,
                WorkflowMode workflowMode,
                LitSubTargetParams litSubTargetParams,
                bool blendModePreserveSpecular,
                PragmaCollection pragmas,
                KeywordCollection keywords)
            {
                KeywordCollection addForward = new KeywordCollection
                {
                    keywords
                };

                if (litSubTargetParams.m_ScreenSpaceAmbientOcclusion)
                {
                    addForward.Add(CoreKeywordDescriptors.ScreenSpaceAmbientOcclusion);
                }

                if (litSubTargetParams.m_StaticLightmap)
                {
                    addForward.Add(CoreKeywordDescriptors.StaticLightmap);
                }

                if (litSubTargetParams.m_DynamicLightmap)
                {
                    addForward.Add(CoreKeywordDescriptors.DynamicLightmap);
                }

                if (litSubTargetParams.m_DirectionalLightmapCombined)
                {
                    addForward.Add(CoreKeywordDescriptors.DirectionalLightmapCombined);
                }

                if (litSubTargetParams.m_AdditionalLights)
                {
                    addForward.Add(CoreKeywordDescriptors.AdditionalLights);
                }

                if (litSubTargetParams.m_AdditionalLightShadows)
                {
                    addForward.Add(CoreKeywordDescriptors.AdditionalLightShadows);
                }

                if (litSubTargetParams.m_ReflectionProbeBlending)
                {
                    addForward.Add(CoreKeywordDescriptors.ReflectionProbeBlending);
                }

                if (litSubTargetParams.m_ReflectionProbeBoxProjection)
                {
                    addForward.Add(CoreKeywordDescriptors.ReflectionProbeBoxProjection);
                }

                if (litSubTargetParams.m_LightmapShadowMixing)
                {
                    addForward.Add(CoreKeywordDescriptors.LightmapShadowMixing);
                }

                if (litSubTargetParams.m_DBuffer)
                {
                    addForward.Add(CoreKeywordDescriptors.DBuffer);
                }

                if (litSubTargetParams.m_LightLayers)
                {
                    addForward.Add(CoreKeywordDescriptors.LightLayers);
                }

                if (litSubTargetParams.m_DebugDisplay)
                {
                    addForward.Add(CoreKeywordDescriptors.DebugDisplay);
                }

                if (litSubTargetParams.m_LightCookies)
                {
                    addForward.Add(CoreKeywordDescriptors.LightCookies);
                }

                if (litSubTargetParams.m_ForwardPlus)
                {
                    addForward.Add(CoreKeywordDescriptors.ForwardPlus);
                }

                var result = new PassDescriptor()
                {
                    // Definition
                    displayName = "Universal Forward",
                    referenceName = "SHADERPASS_FORWARD",
                    lightMode = "UniversalForward",
                    useInPreview = true,

                    // Template
                    passTemplatePath = UniversalTarget.kUberTemplatePath,
                    sharedTemplateDirectories = UniversalTarget.kSharedTemplateDirectories,

                    // Port Mask
                    validVertexBlocks = CoreBlockMasks.Vertex,
                    validPixelBlocks = LitBlockMasks.FragmentLit,

                    // Fields
                    structs = CoreStructCollections.Default,
                    requiredFields = LitRequiredFields.Forward,
                    fieldDependencies = CoreFieldDependencies.Default,

                    // Conditional State
                    renderStates = CoreRenderStates.UberSwitchedRenderState(target, blendModePreserveSpecular),
                    pragmas = pragmas ?? CorePragmas.Forward, // NOTE: SM 2.0 only GL
                    defines = new DefineCollection(),
                    keywords = new KeywordCollection() { addForward },
                    includes = LitIncludes.Forward,

                    // Custom Interpolator Support
                    customInterpolators = CoreCustomInterpDescriptors.Common
                };
                
                result.pragmas = new PragmaCollection();
                result.pragmas.Add(Pragma.Target(ShaderModel.Target20));
                result.pragmas.Add(Pragma.MultiCompileInstancing);
                result.pragmas.Add(Pragma.Vertex("vert"));
                result.pragmas.Add(Pragma.Fragment("frag"));
                
                if (litSubTargetParams.m_Fog)
                {
                    result.defines.Add(CoreDefines.UseFragmentFog);
                    result.pragmas.Add(Pragma.MultiCompileFog);
                }
                
                FernCorePasses.AddWorkflowModeControlToPass(ref result, target, workflowMode);
                FernCorePasses.AddTargetSurfaceControlsToPass(ref result, target, blendModePreserveSpecular);
                FernCorePasses.AddAlphaToMaskControlToPass(ref result, target);
                FernCorePasses.AddReceiveShadowsControlToPass(ref result, target, target.receiveShadows);
                FernCorePasses.AddLODCrossFadeControlToPass(ref result, target);
                FernCorePasses.AddDiffusionModelControlToPass(ref result, target, litSubTargetParams.diffusionModel);
                FernCorePasses.AddEnvRotateControlToPass(ref result, target, litSubTargetParams.envRotate);
                FernCorePasses.AddEnvReflectionModeControlToPass(ref result, target, litSubTargetParams.envReflectionMode);
                FernCorePasses.AddSpecularModelControlToPass(ref result, target, litSubTargetParams.specularModel);
                FernCorePasses.AddGeometryAAControlToPass(ref result, target, litSubTargetParams.geometryAA);
                FernCorePasses.AddClearCoatControlToPass(ref result, target, litSubTargetParams.clearCoat, litSubTargetParams.clearCoatNormal, true);
                FernCorePasses.AddRefractionControlToPass(ref result, target, litSubTargetParams.refraction);
                return result;
            }

            public static PassDescriptor PlanarReflectionForward(
                UniversalTarget target,
                WorkflowMode workflowMode,
                LitSubTargetParams litSubTargetParams,
                bool blendModePreserveSpecular,
                PragmaCollection pragmas,
                KeywordCollection keywords)
            {
                KeywordCollection addForward = new KeywordCollection
                {
                    keywords
                };

                if (litSubTargetParams.m_ScreenSpaceAmbientOcclusion)
                {
                    addForward.Add(CoreKeywordDescriptors.ScreenSpaceAmbientOcclusion);
                }

                if (litSubTargetParams.m_StaticLightmap)
                {
                    addForward.Add(CoreKeywordDescriptors.StaticLightmap);
                }

                if (litSubTargetParams.m_DynamicLightmap)
                {
                    addForward.Add(CoreKeywordDescriptors.DynamicLightmap);
                }

                if (litSubTargetParams.m_DirectionalLightmapCombined)
                {
                    addForward.Add(CoreKeywordDescriptors.DirectionalLightmapCombined);
                }

                if (litSubTargetParams.m_AdditionalLights)
                {
                    addForward.Add(CoreKeywordDescriptors.AdditionalLights);
                }

                if (litSubTargetParams.m_AdditionalLightShadows)
                {
                    addForward.Add(CoreKeywordDescriptors.AdditionalLightShadows);
                }

                if (litSubTargetParams.m_ReflectionProbeBlending)
                {
                    addForward.Add(CoreKeywordDescriptors.ReflectionProbeBlending);
                }

                if (litSubTargetParams.m_ReflectionProbeBoxProjection)
                {
                    addForward.Add(CoreKeywordDescriptors.ReflectionProbeBoxProjection);
                }

                if (litSubTargetParams.m_LightmapShadowMixing)
                {
                    addForward.Add(CoreKeywordDescriptors.LightmapShadowMixing);
                }

                if (litSubTargetParams.m_DBuffer)
                {
                    addForward.Add(CoreKeywordDescriptors.DBuffer);
                }

                if (litSubTargetParams.m_LightLayers)
                {
                    addForward.Add(CoreKeywordDescriptors.LightLayers);
                }

                if (litSubTargetParams.m_DebugDisplay)
                {
                    addForward.Add(CoreKeywordDescriptors.DebugDisplay);
                }

                if (litSubTargetParams.m_LightCookies)
                {
                    addForward.Add(CoreKeywordDescriptors.LightCookies);
                }

                if (litSubTargetParams.m_ForwardPlus)
                {
                    addForward.Add(CoreKeywordDescriptors.ForwardPlus);
                }

                var result = new PassDescriptor()
                {
                    // Definition
                    displayName = "Universal Reflection Forward",
                    referenceName = "SHADERPASS_FORWARD",
                    lightMode = "UniversalPlanarReflectionForward",
                    useInPreview = true,

                    // Template
                    passTemplatePath = UniversalTarget.kUberTemplatePath,
                    sharedTemplateDirectories = UniversalTarget.kSharedTemplateDirectories,

                    // Port Mask
                    validVertexBlocks = CoreBlockMasks.Vertex,
                    validPixelBlocks = LitBlockMasks.FragmentLit,

                    // Fields
                    structs = CoreStructCollections.Default,
                    requiredFields = LitRequiredFields.Forward,
                    fieldDependencies = CoreFieldDependencies.Default,

                    // Conditional State
                    renderStates = CoreRenderStates.UberSwitchedRenderState(target, blendModePreserveSpecular),
                    pragmas = pragmas ?? CorePragmas.Forward, // NOTE: SM 2.0 only GL
                    defines = new DefineCollection() { CoreDefines.UseFragmentFog },
                    keywords = new KeywordCollection() { addForward },
                    includes = LitIncludes.Forward,

                    // Custom Interpolator Support
                    customInterpolators = CoreCustomInterpDescriptors.Common
                };

                FernCorePasses.AddWorkflowModeControlToPass(ref result, target, workflowMode);
                FernCorePasses.AddTargetSurfaceControlsToPass(ref result, target, blendModePreserveSpecular);
                FernCorePasses.AddAlphaToMaskControlToPass(ref result, target);
                //AddReceiveShadowsControlToPass(ref result, target, target.receiveShadows);
                FernCorePasses.AddLODCrossFadeControlToPass(ref result, target);
                FernCorePasses.AddDiffusionModelControlToPass(ref result, target, litSubTargetParams.diffusionModel);
                FernCorePasses.AddEnvRotateControlToPass(ref result, target, litSubTargetParams.envRotate);
                FernCorePasses.AddEnvReflectionModeControlToPass(ref result, target, litSubTargetParams.envReflectionMode);
                //FernCorePasses.AddSpecularModelControlToPass(ref result, target, litSubTargetParams.specularModel);
                //FernCorePasses.AddGeometryAAControlToPass(ref result, target, litSubTargetParams.geometryAA);
                //AddClearCoatControlToPass(ref result, target, litSubTargetParams);

                return result;
            }
            
            public static PassDescriptor SSGIBaseColorForward(
                UniversalTarget target,
                LitSubTargetParams litSubTargetParams,
                bool blendModePreserveSpecular,
                PragmaCollection pragmas,
                KeywordCollection keywords)
            {
                KeywordCollection addForward = new KeywordCollection
                {
                    keywords
                };

                if (litSubTargetParams.m_DBuffer)
                {
                    addForward.Add(CoreKeywordDescriptors.DBuffer);
                }

                var result = new PassDescriptor()
                {
                    // Definition
                    displayName = "Universal SSGI BaseColor Forward",
                    referenceName = "SHADERPASS_FORWARD",
                    lightMode = "UniversalSSGIBASECOLORFORWARD",
                    useInPreview = true,

                    // Template
                    passTemplatePath = UniversalTarget.kUberTemplatePath,
                    sharedTemplateDirectories = UniversalTarget.kSharedTemplateDirectories,

                    // Port Mask
                    validVertexBlocks = CoreBlockMasks.Vertex,
                    validPixelBlocks = LitBlockMasks.FragmentLit,

                    // Fields
                    structs = CoreStructCollections.Default,
                    requiredFields = LitRequiredFields.Forward,
                    fieldDependencies = CoreFieldDependencies.Default,

                    // Conditional State
                    renderStates = CoreRenderStates.UberSwitchedRenderState(target, blendModePreserveSpecular),
                    pragmas = pragmas ?? CorePragmas.Forward, // NOTE: SM 2.0 only GL
                    defines = new DefineCollection() { CoreDefines.UseFragmentFog },
                    keywords = new KeywordCollection() { addForward },
                    includes = LitIncludes.SSGIBaseColorForward,

                    // Custom Interpolator Support
                    customInterpolators = CoreCustomInterpDescriptors.Common
                };

                FernCorePasses.AddTargetSurfaceControlsToPass(ref result, target, blendModePreserveSpecular);
                FernCorePasses.AddAlphaToMaskControlToPass(ref result, target);
                FernCorePasses.AddLODCrossFadeControlToPass(ref result, target);

                return result;
            }
            
                   
            // used by lit/unlit targets
            public static PassDescriptor ShadowCaster(UniversalTarget target, LitSubTargetParams litSubTargetParams)
            {
                var result = new PassDescriptor()
                {
                    // Definition
                    displayName = "ShadowCaster",
                    referenceName = "SHADERPASS_SHADOWCASTER",
                    lightMode = "ShadowCaster",

                    // Template
                    passTemplatePath = UniversalTarget.kUberTemplatePath,
                    sharedTemplateDirectories = UniversalTarget.kSharedTemplateDirectories,

                    // Port Mask
                    validVertexBlocks = LitBlockMasks.Vertex,
                    validPixelBlocks = CoreBlockMasks.FragmentAlphaOnly,

                    // Fields
                    structs = CoreStructCollections.Default,
                    requiredFields = CoreRequiredFields.ShadowCaster,
                    fieldDependencies = CoreFieldDependencies.Default,

                    // Conditional State
                    renderStates = CoreRenderStates.ShadowCaster(target),
                    pragmas = CorePragmas.Instanced,
                    defines = new DefineCollection(),
                    keywords = new KeywordCollection { CoreKeywords.ShadowCaster },
                    includes = new IncludeCollection { FernInclude.ShadowCaster },

                    // Custom Interpolator Support
                    customInterpolators = CoreCustomInterpDescriptors.Common
                };

                FernCorePasses.AddAlphaClipControlToPass(ref result, target);
                //AddTransparentShadowCasterControlToPass(ref result, target);
                FernCorePasses.AddLODCrossFadeControlToPass(ref result, target);
                FernCorePasses.AddCustomShadowBiasToPass(ref result, target, litSubTargetParams.customShadowBias);
                return result;
            }
            

            public static PassDescriptor ForwardOnly(
                UniversalTarget target,
                bool complexLit,
                bool blendModePreserveSpecular,
                BlockFieldDescriptor[] vertexBlocks,
                BlockFieldDescriptor[] pixelBlocks,
                PragmaCollection pragmas,
                KeywordCollection keywords)
            {
                var result = new PassDescriptor
                {
                    // Definition
                    displayName = "Universal Forward Only",
                    referenceName = "SHADERPASS_FORWARDONLY",
                    lightMode = "UniversalForwardOnly",
                    useInPreview = true,

                    // Template
                    passTemplatePath = UniversalTarget.kUberTemplatePath,
                    sharedTemplateDirectories = UniversalTarget.kSharedTemplateDirectories,

                    // Port Mask
                    validVertexBlocks = vertexBlocks,
                    validPixelBlocks = pixelBlocks,

                    // Fields
                    structs = CoreStructCollections.Default,
                    requiredFields = LitRequiredFields.Forward,
                    fieldDependencies = CoreFieldDependencies.Default,

                    // Conditional State
                    renderStates = CoreRenderStates.UberSwitchedRenderState(target, blendModePreserveSpecular),
                    pragmas = pragmas,
                    defines = new DefineCollection { CoreDefines.UseFragmentFog },
                    keywords = new KeywordCollection { keywords },
                    includes = new IncludeCollection { LitIncludes.Forward },

                    // Custom Interpolator Support
                    customInterpolators = CoreCustomInterpDescriptors.Common
                };

                if (complexLit)
                    result.defines.Add(LitDefines.ClearCoat, 1);

                FernCorePasses.AddTargetSurfaceControlsToPass(ref result, target, blendModePreserveSpecular);
                FernCorePasses.AddAlphaToMaskControlToPass(ref result, target);
                FernCorePasses.AddReceiveShadowsControlToPass(ref result, target, target.receiveShadows);
                FernCorePasses.AddLODCrossFadeControlToPass(ref result, target);

                return result;
            }

            // Deferred only in SM4.5, MRT not supported in GLES2
            public static PassDescriptor GBuffer(UniversalTarget target, WorkflowMode workflowMode, bool blendModePreserveSpecular)
            {
                var result = new PassDescriptor
                {
                    // Definition
                    displayName = "GBuffer",
                    referenceName = "SHADERPASS_GBUFFER",
                    lightMode = "UniversalGBuffer",
                    useInPreview = true,

                    // Template
                    passTemplatePath = UniversalTarget.kUberTemplatePath,
                    sharedTemplateDirectories = UniversalTarget.kSharedTemplateDirectories,

                    // Port Mask
                    validVertexBlocks = CoreBlockMasks.Vertex,
                    validPixelBlocks = LitBlockMasks.FragmentLit,

                    // Fields
                    structs = CoreStructCollections.Default,
                    requiredFields = LitRequiredFields.GBuffer,
                    fieldDependencies = CoreFieldDependencies.Default,

                    // Conditional State
                    renderStates = CoreRenderStates.UberSwitchedRenderState(target, blendModePreserveSpecular),
                    pragmas = CorePragmas.GBuffer,
                    defines = new DefineCollection { CoreDefines.UseFragmentFog },
                    keywords = new KeywordCollection { LitKeywords.GBuffer },
                    includes = new IncludeCollection { LitIncludes.GBuffer },

                    // Custom Interpolator Support
                    customInterpolators = CoreCustomInterpDescriptors.Common
                };

                FernCorePasses.AddTargetSurfaceControlsToPass(ref result, target, blendModePreserveSpecular);
                FernCorePasses.AddWorkflowModeControlToPass(ref result, target, workflowMode);
                FernCorePasses.AddReceiveShadowsControlToPass(ref result, target, target.receiveShadows);
                FernCorePasses.AddLODCrossFadeControlToPass(ref result, target);

                return result;
            }

            public static PassDescriptor Meta(UniversalTarget target)
            {
                var result = new PassDescriptor()
                {
                    // Definition
                    displayName = "Meta",
                    referenceName = "SHADERPASS_META",
                    lightMode = "Meta",

                    // Template
                    passTemplatePath = UniversalTarget.kUberTemplatePath,
                    sharedTemplateDirectories = UniversalTarget.kSharedTemplateDirectories,

                    // Port Mask
                    validVertexBlocks = CoreBlockMasks.Vertex,
                    validPixelBlocks = LitBlockMasks.FragmentMeta,

                    // Fields
                    structs = CoreStructCollections.Default,
                    requiredFields = LitRequiredFields.Meta,
                    fieldDependencies = CoreFieldDependencies.Default,

                    // Conditional State
                    renderStates = CoreRenderStates.Meta,
                    pragmas = CorePragmas.Default,
                    defines = new DefineCollection() { CoreDefines.UseFragmentFog },
                    keywords = new KeywordCollection() { CoreKeywordDescriptors.EditorVisualization },
                    includes = LitIncludes.Meta,

                    // Custom Interpolator Support
                    customInterpolators = CoreCustomInterpDescriptors.Common
                };

                FernCorePasses.AddAlphaClipControlToPass(ref result, target);

                return result;
            }

            public static PassDescriptor _2D(UniversalTarget target)
            {
                var result = new PassDescriptor()
                {
                    // Definition
                    referenceName = "SHADERPASS_2D",
                    lightMode = "Universal2D",

                    // Template
                    passTemplatePath = UniversalTarget.kUberTemplatePath,
                    sharedTemplateDirectories = UniversalTarget.kSharedTemplateDirectories,

                    // Port Mask
                    validVertexBlocks = CoreBlockMasks.Vertex,
                    validPixelBlocks = CoreBlockMasks.FragmentColorAlpha,

                    // Fields
                    structs = CoreStructCollections.Default,
                    fieldDependencies = CoreFieldDependencies.Default,

                    // Conditional State
                    renderStates = CoreRenderStates.UberSwitchedRenderState(target),
                    pragmas = CorePragmas.Instanced,
                    defines = new DefineCollection(),
                    keywords = new KeywordCollection(),
                    includes = LitIncludes._2D,

                    // Custom Interpolator Support
                    customInterpolators = CoreCustomInterpDescriptors.Common
                };

                FernCorePasses.AddAlphaClipControlToPass(ref result, target);

                return result;
            }
     

            public static PassDescriptor DepthNormal(UniversalTarget target)
            {
                var result = new PassDescriptor()
                {
                    // Definition
                    displayName = "DepthNormals",
                    referenceName = "SHADERPASS_DEPTHNORMALS",
                    lightMode = "DepthNormals",
                    useInPreview = false,

                    // Template
                    passTemplatePath = UniversalTarget.kUberTemplatePath,
                    sharedTemplateDirectories = UniversalTarget.kSharedTemplateDirectories,

                    // Port Mask
                    validVertexBlocks = CoreBlockMasks.Vertex,
                    validPixelBlocks = CoreBlockMasks.FragmentDepthNormals,

                    // Fields
                    structs = CoreStructCollections.Default,
                    requiredFields = CoreRequiredFields.DepthNormals,
                    fieldDependencies = CoreFieldDependencies.Default,

                    // Conditional State
                    renderStates = CoreRenderStates.DepthNormalsOnly(target),
                    pragmas = CorePragmas.Instanced,
                    defines = new DefineCollection(),
                    keywords = new KeywordCollection(),
                    includes = new IncludeCollection { FernInclude.DepthNormalsOnly },

                    // Custom Interpolator Support
                    customInterpolators = CoreCustomInterpDescriptors.Common
                };

                FernCorePasses.AddAlphaClipControlToPass(ref result, target);
                FernCorePasses.AddLODCrossFadeControlToPass(ref result, target);

                return result;
            }

            public static PassDescriptor DepthNormalOnly(UniversalTarget target)
            {
                var result = new PassDescriptor()
                {
                    // Definition
                    displayName = "DepthNormalsOnly",
                    referenceName = "SHADERPASS_DEPTHNORMALSONLY",
                    lightMode = "DepthNormalsOnly",
                    useInPreview = false,

                    // Template
                    passTemplatePath = UniversalTarget.kUberTemplatePath,
                    sharedTemplateDirectories = UniversalTarget.kSharedTemplateDirectories,

                    // Port Mask
                    validVertexBlocks = CoreBlockMasks.Vertex,
                    validPixelBlocks = CoreBlockMasks.FragmentDepthNormals,

                    // Fields
                    structs = CoreStructCollections.Default,
                    requiredFields = CoreRequiredFields.DepthNormals,
                    fieldDependencies = CoreFieldDependencies.Default,

                    // Conditional State
                    renderStates = CoreRenderStates.DepthNormalsOnly(target),
                    pragmas = CorePragmas.Instanced,
                    defines = new DefineCollection(),
                    keywords = new KeywordCollection(),
                    includes = new IncludeCollection { FernInclude.DepthNormalsOnly },

                    // Custom Interpolator Support
                    customInterpolators = CoreCustomInterpDescriptors.Common
                };

                FernCorePasses.AddAlphaClipControlToPass(ref result, target);
                FernCorePasses.AddLODCrossFadeControlToPass(ref result, target);

                return result;
            }
        }

        static class LitBlockMasks
        {
            public static readonly BlockFieldDescriptor[] Vertex = new BlockFieldDescriptor[]
            {
                BlockFields.VertexDescription.Position,
                BlockFields.VertexDescription.Normal,
                BlockFields.VertexDescription.Tangent,
                FernSG_URP_Field.VertexDescription.ShadowDepthBias,
                FernSG_URP_Field.VertexDescription.ShadowNormalBias,
            };
            
            public static readonly BlockFieldDescriptor[] FragmentLit = new BlockFieldDescriptor[]
            {
                BlockFields.SurfaceDescription.BaseColor,
                BlockFields.SurfaceDescription.NormalOS,
                BlockFields.SurfaceDescription.NormalTS,
                BlockFields.SurfaceDescription.NormalWS,
                BlockFields.SurfaceDescription.Emission,
                BlockFields.SurfaceDescription.Metallic,
                BlockFields.SurfaceDescription.Specular,
                BlockFields.SurfaceDescription.Smoothness,
                BlockFields.SurfaceDescription.Occlusion,
                BlockFields.SurfaceDescription.Alpha,
                BlockFields.SurfaceDescription.AlphaClipThreshold,
                BlockFields.SurfaceDescription.CoatMask,
                BlockFields.SurfaceDescription.CoatSmoothness,
                FernSG_URP_Field.SurfaceDescription.ClearCoatNormal,
                FernSG_URP_Field.SurfaceDescription.ClearCoatTint,
                FernSG_URP_Field.SurfaceDescription.ClearCoatSpecularIntensity,
                FernSG_URP_Field.SurfaceDescription.RampColor,
                FernSG_URP_Field.SurfaceDescription.SpecularColor,
                FernSG_URP_Field.SurfaceDescription.Anisotropy,
                FernSG_URP_Field.SurfaceDescription.StylizedSpecularSize,
                FernSG_URP_Field.SurfaceDescription.StylizedSpecularSoftness,
                FernSG_URP_Field.SurfaceDescription.CellThreshold,
                FernSG_URP_Field.SurfaceDescription.CellSmoothness,
                FernSG_URP_Field.SurfaceDescription.Refraction,
                FernSG_URP_Field.SurfaceDescription.GeometryAAVariant,
                FernSG_URP_Field.SurfaceDescription.GeometryAAStrength,
                FernSG_URP_Field.SurfaceDescription.DarkColor,
                FernSG_URP_Field.SurfaceDescription.LightenColor,
                FernSG_URP_Field.SurfaceDescription.EnvReflection,
                FernSG_URP_Field.SurfaceDescription.EnvRotate,
                FernSG_URP_Field.SurfaceDescription.EnvSpeularcIntensity,
                FernSG_URP_Field.SurfaceDescription.PlanarReflectionIntensity,
            };

            public static readonly BlockFieldDescriptor[] FragmentMeta = new BlockFieldDescriptor[]
            {
                BlockFields.SurfaceDescription.BaseColor,
                BlockFields.SurfaceDescription.Emission,
                BlockFields.SurfaceDescription.Alpha,
                BlockFields.SurfaceDescription.AlphaClipThreshold,
            };
        }

        static class LitRequiredFields
        {
            public static readonly FieldCollection Forward = new FieldCollection()
            {
                StructFields.Attributes.uv1,
                StructFields.Attributes.uv2,
                StructFields.Varyings.positionWS,
                StructFields.Varyings.normalWS,
                StructFields.Varyings.tangentWS, // needed for vertex lighting
                UniversalStructFields.Varyings.staticLightmapUV,
                UniversalStructFields.Varyings.dynamicLightmapUV,
                UniversalStructFields.Varyings.sh,
                UniversalStructFields.Varyings
                    .fogFactorAndVertexLight, // fog and vertex lighting, vert input is dependency
                UniversalStructFields.Varyings.shadowCoord, // shadow coord, vert input is dependency
            };

            public static readonly FieldCollection GBuffer = new FieldCollection()
            {
                StructFields.Attributes.uv1,
                StructFields.Attributes.uv2,
                StructFields.Varyings.positionWS,
                StructFields.Varyings.normalWS,
                StructFields.Varyings.tangentWS, // needed for vertex lighting
                UniversalStructFields.Varyings.staticLightmapUV,
                UniversalStructFields.Varyings.dynamicLightmapUV,
                UniversalStructFields.Varyings.sh,
                UniversalStructFields.Varyings
                    .fogFactorAndVertexLight, // fog and vertex lighting, vert input is dependency
                UniversalStructFields.Varyings.shadowCoord, // shadow coord, vert input is dependency
            };

            public static readonly FieldCollection Meta = new FieldCollection()
            {
                StructFields.Attributes.positionOS,
                StructFields.Attributes.normalOS,
                StructFields.Attributes.uv0, //
                StructFields.Attributes.uv1, // needed for meta vertex position
                StructFields.Attributes.uv2, // needed for meta UVs
                StructFields.Attributes.instanceID, // needed for rendering instanced terrain
                StructFields.Varyings.positionCS,
                StructFields.Varyings.texCoord0, // needed for meta UVs
                StructFields.Varyings.texCoord1, // VizUV
                StructFields.Varyings.texCoord2, // LightCoord
            };
        }

        static class LitIncludes
        {

            public static readonly IncludeCollection Forward = new IncludeCollection
            {
                // Pre-graph
                { FernInclude.DOTSPregraph },
                { FernInclude.WriteRenderLayersPregraph },
                { FernInclude.CorePregraph },
                { FernInclude.kShadows, IncludeLocation.Pregraph },
                { FernInclude.ShaderGraphPregraph },
                { FernInclude.DBufferPregraph },

                // Post-graph
                { FernInclude.CorePostgraph },
                { FernInclude.kLitProForwardPass, IncludeLocation.Postgraph },
            };
            
            public static readonly IncludeCollection SSGIBaseColorForward = new IncludeCollection
            {
                // Pre-graph
                { FernInclude.CorePregraph },
                { FernInclude.kShadows, IncludeLocation.Pregraph },
                { FernInclude.ShaderGraphPregraph },
                { FernInclude.DBufferPregraph },

                // Post-graph
                { FernInclude.CorePostgraph },
                { FernInclude.kSSGIBaseColorForwardPass, IncludeLocation.Postgraph },
            };

            public static readonly IncludeCollection GBuffer = new IncludeCollection
            {
                // Pre-graph
                { FernInclude.DOTSPregraph },
                { FernInclude.WriteRenderLayersPregraph },
                { FernInclude.CorePregraph },
                { FernInclude.kShadows, IncludeLocation.Pregraph },
                { FernInclude.ShaderGraphPregraph },
                { FernInclude.DBufferPregraph },

                // Post-graph
                { FernInclude.CorePostgraph },
                { FernInclude.kGBuffer, IncludeLocation.Postgraph },
                { FernInclude.kPBRGBufferPass, IncludeLocation.Postgraph },
            };

            public static readonly IncludeCollection Meta = new IncludeCollection
            {
                // Pre-graph
                { FernInclude.CorePregraph },
                { FernInclude.ShaderGraphPregraph },
                { FernInclude.kMetaInput, IncludeLocation.Pregraph },

                // Post-graph
                { FernInclude.CorePostgraph },
                { FernInclude.kLightingMetaPass, IncludeLocation.Postgraph },
            };

            public static readonly IncludeCollection _2D = new IncludeCollection
            {
                // Pre-graph
                { FernInclude.CorePregraph },
                { FernInclude.ShaderGraphPregraph },

                // Post-graph
                { FernInclude.CorePostgraph },
                { FernInclude.k2DPass, IncludeLocation.Postgraph },
            };
        }
    }
}