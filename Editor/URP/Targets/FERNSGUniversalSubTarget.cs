using System;
using System.Linq;
using System.Collections.Generic;
using UnityEditor;
using UnityEditor.Rendering.Universal;
using UnityEditor.Rendering.Universal.ShaderGraph;
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
    abstract class FERNSGUniversalSubTarget : UniversalSubTarget, ILegacyTarget
    {
        internal enum FeatureType
        {
            Toggle = 2,
            Always = 1,
            None = 0
        }
        
        internal enum DiffusionModel
        {
            Disney = 3,
            Cell = 2,
            Ramp = 1,
            Lambert = 0
        }

        internal enum SpecularModel
        {
            None = 4,
            Aniso = 3,
            BLINNPHONG = 2,
            STYLIZED = 1,
            GGX = 0
        }

        internal enum FabricType
        {
            Cotton = 0,
            Silk = 1,
        }

        internal enum EnvReflectionMode
        {
            None = 2,
            Custom = 1,
            Default = 0
        }
        
        static readonly GUID kSourceCodeGuid = new GUID("43fb03da56c94c538fb22458386ae467");
        
        [SerializeField]
        WorkflowMode m_WorkflowMode = WorkflowMode.Metallic;
        public WorkflowMode workflowMode
        {
            get => m_WorkflowMode;
            set => m_WorkflowMode = value;
        }

        [SerializeField] NormalDropOffSpace m_NormalDropOffSpace = NormalDropOffSpace.Tangent;
        public NormalDropOffSpace normalDropOffSpace
        {
            get => m_NormalDropOffSpace;
            set => m_NormalDropOffSpace = value;
        }

        [SerializeField] EnvReflectionMode m_EnvReflection = EnvReflectionMode.Default;
        public EnvReflectionMode envReflectionMode
        {
            get => m_EnvReflection;
            set => m_EnvReflection = value;
        }
        [SerializeField] FeatureType m_Refraction = FeatureType.None;
        public FeatureType refraction
        {
            get => m_Refraction;
            set => m_Refraction = value;
        }
        [SerializeField] bool m_BlendModePreserveSpecular = true;
        public bool blendModePreserveSpecular
        {
            get => m_BlendModePreserveSpecular;
            set => m_BlendModePreserveSpecular = value;
        }

        #region Feature Control

        [SerializeField] bool m_ClearCoatNormal = false;
        public bool clearCoatNormal
        {
            get => m_ClearCoatNormal;
            set => m_ClearCoatNormal = value;
        }
        [SerializeField] bool m_TransparentShadow = false;
        public bool transparentShadow
        {
            get => m_TransparentShadow;
            set => m_TransparentShadow = value;
        }
        [SerializeField] bool m_depthNormal = false;
        public bool depthNormal
        {
            get => m_depthNormal;
            set => m_depthNormal = value;
        }
        [SerializeField] bool m_planarReflection = false;
        public bool planarReflection
        {
            get => m_planarReflection;
            set => m_planarReflection = value;
        }
        [SerializeField] bool m_ssgi = false;
        public bool ssgi
        {
            get => m_ssgi;
            set => m_ssgi = value;
        }
        [SerializeField] private bool m_2D;
        public bool _2D
        {
            get => m_2D;
            set => m_2D = value;
        }
        [SerializeField] FeatureType m_ClearCoat = FeatureType.Always;
        public FeatureType clearCoat
        {
            get => m_ClearCoat;
            set => m_ClearCoat = value;
        }
        [SerializeField] FeatureType m_GeometryAA = FeatureType.Always;
        public FeatureType geometryAA
        {
            get => m_GeometryAA;
            set => m_GeometryAA = value;
        }
        [SerializeField] FeatureType m_EnvRotate = FeatureType.Always;
        public FeatureType envRotate
        {
            get => m_EnvRotate;
            set => m_EnvRotate = value;
        }
        [SerializeField] FeatureType m_CustomShadowBias = FeatureType.Always;
        public FeatureType customShadowBias
        {
            get => m_CustomShadowBias;
            set => m_CustomShadowBias = value;
        }
        #endregion

        #region Keyword Check

        [SerializeField] public bool m_ScreenSpaceAmbientOcclusion = true;
        [SerializeField] public bool m_StaticLightmap = true;
        [SerializeField] public bool m_DynamicLightmap = true;
        [SerializeField] public bool m_DirectionalLightmapCombined = true;
        [SerializeField] public bool m_AdditionalLights = true;
        [SerializeField] public bool m_AdditionalLightShadows = true;
        [SerializeField] public bool m_ReflectionProbeBlending = true;
        [SerializeField] public bool m_ReflectionProbeBoxProjection = true;
        [SerializeField] public bool m_LightmapShadowMixing = true;
        [SerializeField] public bool m_ShadowsShadowmask = true;
        [SerializeField] public bool m_DBuffer = true;
        [SerializeField] public bool m_LightLayers = true;
        [SerializeField] public bool m_DebugDisplay = true;
        [SerializeField] public bool m_LightCookies = true;
        [SerializeField] public bool m_ForwardPlus = true;
        [SerializeField] public bool m_Fog = true;

        #endregion

        public override bool IsActive() => true;
        public TargetPropertyGUIFoldout foldoutFernControl;

        public override void ProcessPreviewMaterial(Material material)
        {
            if (target.allowMaterialOverride)
            {
                // copy our target's default settings into the material
                // (technically not necessary since we are always recreating the material from the shader each time,
                // which will pull over the defaults from the shader definition)
                // but if that ever changes, this will ensure the defaults are set
                material.SetFloat(Property.SpecularWorkflowMode, (float)workflowMode);
                material.SetFloat(Property.CastShadows, target.castShadows ? 1.0f : 0.0f);
                material.SetFloat(Property.ReceiveShadows, target.receiveShadows ? 1.0f : 0.0f);
                material.SetFloat(Property.SurfaceType, (float)target.surfaceType);
                material.SetFloat(Property.BlendMode, (float)target.alphaMode);
                material.SetFloat(Property.AlphaClip, target.alphaClip ? 1.0f : 0.0f);
                material.SetFloat(Property.CullMode, (int)target.renderFace);
                material.SetFloat(Property.ZWriteControl, (float)target.zWriteControl);
                material.SetFloat(Property.ZTest, (float)target.zTestMode);
            }

            // We always need these properties regardless of whether the material is allowed to override
            // Queue control & offset enable correct automatic render queue behavior
            // Control == 0 is automatic, 1 is user-specified render queue
            material.SetFloat(Property.QueueOffset, 0.0f);
            material.SetFloat(Property.QueueControl, (float)BaseShaderGUI.QueueControl.Auto);

            // call the full unlit material setup function
            FURPShaderGraphLitGUI.UpdateMaterial(material, MaterialUpdateType.CreatedNewMaterial);
        }

        public override void GetFields(ref TargetFieldContext context)
        {
            base.GetFields(ref context);

            var descs = context.blocks.Select(x => x.descriptor);

            // Lit -- always controlled by subtarget
            context.AddField(UniversalFields.NormalDropOffOS, normalDropOffSpace == NormalDropOffSpace.Object);
            context.AddField(UniversalFields.NormalDropOffTS, normalDropOffSpace == NormalDropOffSpace.Tangent);
            context.AddField(UniversalFields.NormalDropOffWS, normalDropOffSpace == NormalDropOffSpace.World);
            context.AddField(UniversalFields.Normal, descs.Contains(BlockFields.SurfaceDescription.NormalOS) ||
                                                     descs.Contains(BlockFields.SurfaceDescription.NormalTS) ||
                                                     descs.Contains(BlockFields.SurfaceDescription.NormalWS));
            // Complex Lit

            // Template Predicates
            // context.AddField(UniversalFields.PredicateClearCoat, clearCoat);
        }

        public override void GetActiveBlocks(ref TargetActiveBlockContext context)
        {
            // Vertex
            context.AddBlock(FernSG_URP_Field.VertexDescription.ShadowDepthBias, customShadowBias != FeatureType.None);
            context.AddBlock(FernSG_URP_Field.VertexDescription.ShadowNormalBias, customShadowBias != FeatureType.None);

            // Fragment
            context.AddBlock(BlockFields.SurfaceDescription.Smoothness);
            context.AddBlock(BlockFields.SurfaceDescription.NormalOS, normalDropOffSpace == NormalDropOffSpace.Object);
            context.AddBlock(BlockFields.SurfaceDescription.NormalTS, normalDropOffSpace == NormalDropOffSpace.Tangent);
            context.AddBlock(BlockFields.SurfaceDescription.NormalWS, normalDropOffSpace == NormalDropOffSpace.World);
            context.AddBlock(BlockFields.SurfaceDescription.Emission);
            context.AddBlock(BlockFields.SurfaceDescription.Occlusion);

            // when the surface options are material controlled, we must show all of these blocks
            // when target controlled, we can cull the unnecessary blocks
            context.AddBlock(BlockFields.SurfaceDescription.Specular, (workflowMode == WorkflowMode.Specular) || target.allowMaterialOverride);
            context.AddBlock(BlockFields.SurfaceDescription.Metallic, (workflowMode == WorkflowMode.Metallic) || target.allowMaterialOverride);
            context.AddBlock(BlockFields.SurfaceDescription.Alpha,
                (target.surfaceType == SurfaceType.Transparent || target.alphaClip) || target.allowMaterialOverride);
            context.AddBlock(BlockFields.SurfaceDescription.AlphaClipThreshold,
                (target.alphaClip) || target.allowMaterialOverride);

            context.AddBlock(FernSG_URP_Field.SurfaceDescription.GeometryAAStrength, geometryAA != FeatureType.None);
            context.AddBlock(FernSG_URP_Field.SurfaceDescription.GeometryAAVariant, geometryAA != FeatureType.None);

            context.AddBlock(FernSG_URP_Field.SurfaceDescription.EnvReflection,
                envReflectionMode == EnvReflectionMode.Custom);
            context.AddBlock(FernSG_URP_Field.SurfaceDescription.EnvRotate, envRotate != FeatureType.None && envReflectionMode == default);

            context.AddBlock(FernSG_URP_Field.SurfaceDescription.PlanarReflectionIntensity);
            context.AddBlock(FernSG_URP_Field.SurfaceDescription.EnvSpeularcIntensity, envReflectionMode != EnvReflectionMode.None);
        }

        public override void CollectShaderProperties(PropertyCollector collector, GenerationMode generationMode)
        {
            // if using material control, add the material property to control workflow mode
            if (target.allowMaterialOverride)
            {
                collector.AddFloatProperty(Property.SpecularWorkflowMode, (float)workflowMode);
                collector.AddFloatProperty(Property.CastShadows, target.castShadows ? 1.0f : 0.0f);
                collector.AddFloatProperty(Property.ReceiveShadows, target.receiveShadows ? 1.0f : 0.0f);

                // setup properties using the defaults
                collector.AddFloatProperty(Property.SurfaceType, (float)target.surfaceType);
                collector.AddFloatProperty(Property.BlendMode, (float)target.alphaMode);
                collector.AddFloatProperty(Property.AlphaClip, target.alphaClip ? 1.0f : 0.0f);
                collector.AddFloatProperty(Property.BlendModePreserveSpecular, blendModePreserveSpecular ? 1.0f : 0.0f);
                collector.AddFloatProperty(Property.SrcBlend,
                    1.0f); // always set by material inspector, ok to have incorrect values here
                collector.AddFloatProperty(Property.DstBlend,
                    0.0f); // always set by material inspector, ok to have incorrect values here
                collector.AddToggleProperty(Property.ZWrite, (target.surfaceType == SurfaceType.Opaque));
                collector.AddFloatProperty(Property.ZWriteControl, (float)target.zWriteControl);
                collector.AddFloatProperty(Property.ZTest,
                    (float)target.zTestMode); // ztest mode is designed to directly pass as ztest
                collector.AddFloatProperty(Property.CullMode,
                    (float)target.renderFace); // render face enum is designed to directly pass as a cull mode

                bool enableAlphaToMask = (target.alphaClip && (target.surfaceType == SurfaceType.Opaque));
                collector.AddFloatProperty(Property.AlphaToMask, enableAlphaToMask ? 1.0f : 0.0f);
                collector.AddToggleProperty(FernProperty.Refraction, target.surfaceType == SurfaceType.Transparent && refraction != FeatureType.None);
            }

            // We always need these properties regardless of whether the material is allowed to override other shader properties.
            // Queue control & offset enable correct automatic render queue behavior.  Control == 0 is automatic, 1 is user-specified.
            // We initialize queue control to -1 to indicate to UpdateMaterial that it needs to initialize it properly on the material.
            collector.AddFloatProperty(Property.QueueOffset, 0.0f);
            collector.AddFloatProperty(Property.QueueControl, -1.0f);
        }

        public Color fernFoldoutColor = new Color(0.55f, 0.6f, 1f);
        public Color keywordFoldoutColor = new Color(0.9f, 0.7f, 0.6f);
        public TargetPropertyGUIFoldout foldout;
        public bool fernControlFoldout = false;
        public bool keyworldFoldout = false;

        public override void GetPropertiesGUI(ref TargetPropertyGUIContext context, Action onChange,
            Action<string> registerUndo)
        {
            var universalTarget = (target as UniversalTarget);
            universalTarget.AddDefaultMaterialOverrideGUI(ref context, onChange, registerUndo);

            context.AddProperty("Workflow Mode", new EnumField(WorkflowMode.Metallic) { value = workflowMode }, (evt) =>
            {
                if (Equals(workflowMode, evt.newValue))
                    return;

                registerUndo("Change Workflow");
                workflowMode = (WorkflowMode)evt.newValue;
                onChange();
            });
            
            context.AddProperty("Fragment Normal Space",
                new EnumField(NormalDropOffSpace.Tangent) { value = normalDropOffSpace }, (evt) =>
                {
                    if (Equals(normalDropOffSpace, evt.newValue))
                        return;

                    registerUndo("Change Fragment Normal Space");
                    normalDropOffSpace = (NormalDropOffSpace)evt.newValue;
                    onChange();
                });

            if (target.surfaceType == SurfaceType.Transparent)
            {
                if (target.alphaMode == AlphaMode.Alpha || target.alphaMode == AlphaMode.Additive)
                    context.AddProperty("Preserve Specular Lighting",
                        new Toggle() { value = blendModePreserveSpecular }, (evt) =>
                        {
                            if (Equals(blendModePreserveSpecular, evt.newValue))
                                return;

                            registerUndo("Change Preserve Specular");
                            blendModePreserveSpecular = evt.newValue;
                            onChange();
                        });
            }

            universalTarget.AddDefaultSurfacePropertiesGUI(ref context, onChange, registerUndo,
                showReceiveShadows: true);

            // TODO:
            // context.AddProperty("Transparent Shadows Caster", new Toggle() { value = transparentShadow }, (evt) =>
            // {
            //     if (Equals(transparentShadow, evt.newValue))
            //         return;
            //
            //     registerUndo("Change Transparent Shadows");
            //     transparentShadow = evt.newValue;
            //     onChange();
            // });

            foldout = new TargetPropertyGUIFoldout()
            {
                text = "Keyword Check", value = keyworldFoldout, style = { color = keywordFoldoutColor },
                name = "Keyword Control"
            };
            foldout.RegisterCallback<ChangeEvent<bool>>(evt =>
            {
                keyworldFoldout = !keyworldFoldout;
                onChange();
            });

            context.Add(foldout);

            if (keyworldFoldout)
            {
                context.AddProperty("SSAO", 1,
                    new Toggle() { value = m_ScreenSpaceAmbientOcclusion }, (evt) =>
                    {
                        if (Equals(m_ScreenSpaceAmbientOcclusion, evt.newValue))
                            return;

                        registerUndo("Change SSAO");
                        m_ScreenSpaceAmbientOcclusion = evt.newValue;
                        onChange();
                    });
                context.AddProperty("Static Lightmap", 1, new Toggle() { value = m_StaticLightmap }, (evt) =>
                {
                    if (Equals(m_StaticLightmap, evt.newValue))
                        return;

                    registerUndo("Change Static Lightmap");
                    m_StaticLightmap = evt.newValue;
                    onChange();
                });
                context.AddProperty("Dynamic Lightmap", 1, new Toggle() { value = m_DynamicLightmap }, (evt) =>
                {
                    if (Equals(m_DynamicLightmap, evt.newValue))
                        return;

                    registerUndo("Change Dynamic Lightmap");
                    m_DynamicLightmap = evt.newValue;
                    onChange();
                });
                context.AddProperty("Directional Lightmap Combined", 1,
                    new Toggle() { value = m_DirectionalLightmapCombined }, (evt) =>
                    {
                        if (Equals(m_DirectionalLightmapCombined, evt.newValue))
                            return;

                        registerUndo("Change Directional Lightmap Combined");
                        m_DirectionalLightmapCombined = evt.newValue;
                        onChange();
                    });
                context.AddProperty("Additional Lights", 1, new Toggle() { value = m_AdditionalLights }, (evt) =>
                {
                    if (Equals(m_AdditionalLights, evt.newValue))
                        return;

                    registerUndo("Change Additional Lights");
                    m_AdditionalLights = evt.newValue;
                    onChange();
                });
                context.AddProperty("AdditionalLight Shadows", 1, new Toggle() { value = m_AdditionalLightShadows },
                    (evt) =>
                    {
                        if (Equals(m_AdditionalLightShadows, evt.newValue))
                            return;

                        registerUndo("Change AdditionalLight Shadows");
                        m_AdditionalLightShadows = evt.newValue;
                        onChange();
                    });
                context.AddProperty("ReflectionProbe Blending", 1, new Toggle() { value = m_ReflectionProbeBlending },
                    (evt) =>
                    {
                        if (Equals(m_ReflectionProbeBlending, evt.newValue))
                            return;

                        registerUndo("Change ReflectionProbe Blending");
                        m_ReflectionProbeBlending = evt.newValue;
                        onChange();
                    });
                context.AddProperty("ReflectionProbeBox Projection", 1,
                    new Toggle() { value = m_ReflectionProbeBoxProjection }, (evt) =>
                    {
                        if (Equals(m_ReflectionProbeBoxProjection, evt.newValue))
                            return;

                        registerUndo("Change ReflectionProbeBox Projection");
                        m_ReflectionProbeBoxProjection = evt.newValue;
                        onChange();
                    });
                context.AddProperty("LightmapShadow Mixing", 1, new Toggle() { value = m_LightmapShadowMixing },
                    (evt) =>
                    {
                        if (Equals(m_LightmapShadowMixing, evt.newValue))
                            return;

                        registerUndo("Change LightmapShadow Mixing");
                        m_LightmapShadowMixing = evt.newValue;
                        onChange();
                    });
                context.AddProperty("ShadowsShadowmask", 1, new Toggle() { value = m_ShadowsShadowmask }, (evt) =>
                {
                    if (Equals(m_ShadowsShadowmask, evt.newValue))
                        return;

                    registerUndo("Change ShadowsShadowmask");
                    m_ShadowsShadowmask = evt.newValue;
                    onChange();
                });
                context.AddProperty("DBuffer", 1, new Toggle() { value = m_DBuffer }, (evt) =>
                {
                    if (Equals(m_DBuffer, evt.newValue))
                        return;

                    registerUndo("Change DBuffer");
                    m_DBuffer = evt.newValue;
                    onChange();
                });
                context.AddProperty("LightLayers", 1, new Toggle() { value = m_LightLayers }, (evt) =>
                {
                    if (Equals(m_LightLayers, evt.newValue))
                        return;

                    registerUndo("Change LightLayers");
                    m_LightLayers = evt.newValue;
                    onChange();
                });
                context.AddProperty("DebugDisplay", 1, new Toggle() { value = m_DebugDisplay }, (evt) =>
                {
                    if (Equals(m_DebugDisplay, evt.newValue))
                        return;

                    registerUndo("Change DebugDisplay");
                    m_DebugDisplay = evt.newValue;
                    onChange();
                });
                context.AddProperty("LightCookies", 1, new Toggle() { value = m_LightCookies }, (evt) =>
                {
                    if (Equals(m_LightCookies, evt.newValue))
                        return;

                    registerUndo("Change LightCookies");
                    m_LightCookies = evt.newValue;
                    onChange();
                });
                context.AddProperty("ForwardPlus", 1, new Toggle() { value = m_ForwardPlus }, (evt) =>
                {
                    if (Equals(m_ForwardPlus, evt.newValue))
                        return;

                    registerUndo("Change ForwardPlus");
                    m_ForwardPlus = evt.newValue;
                    onChange();
                });
                
                context.AddProperty("Fog", 1, new Toggle() { value = m_Fog }, (evt) =>
                {
                    if (Equals(m_Fog, evt.newValue))
                        return;

                    registerUndo("Change Fog");
                    m_Fog = evt.newValue;
                    onChange();
                });
            }

            foldoutFernControl = new TargetPropertyGUIFoldout()
            {
                text = "Pass Control", value = fernControlFoldout, style = { color = fernFoldoutColor },
                name = "Pass foldout"
            };
            foldoutFernControl.RegisterCallback<ChangeEvent<bool>>(evt =>
            {
                fernControlFoldout = !fernControlFoldout;
                onChange();
            });

            context.Add(foldoutFernControl);

            if (fernControlFoldout)
            {
                context.AddProperty("Depth Normal", 1, new Toggle() { value = depthNormal }, (evt) =>
                {
                    if (Equals(depthNormal, evt.newValue))
                        return;

                    registerUndo("Change Depth Normal");
                    depthNormal = evt.newValue;
                    onChange();
                });

                context.AddProperty("Planar Reflection", 1, new Toggle() { value = planarReflection }, (evt) =>
                {
                    if (Equals(planarReflection, evt.newValue))
                        return;

                    registerUndo("Change Planar Reflection");
                    planarReflection = evt.newValue;
                    onChange();
                });

                context.AddProperty("SSGI", 1, new Toggle() { value = ssgi }, (evt) =>
                {
                    if (Equals(ssgi, evt.newValue))
                        return;

                    registerUndo("Change SSGI");
                    ssgi = evt.newValue;
                    onChange();
                });

                context.AddProperty("Universal 2D", 1, new Toggle() { value = _2D }, (evt) =>
                {
                    if (Equals(_2D, evt.newValue))
                        return;

                    registerUndo("Change Universal 2D");
                    _2D = evt.newValue;
                    onChange();
                });

                context.AddProperty("Geometry AA", 1, new EnumField(FeatureType.Always) { value = geometryAA }, (evt) =>
                {
                    if (Equals(geometryAA, evt.newValue))
                        return;

                    registerUndo("Change Geometry AA");
                    geometryAA = (FeatureType)evt.newValue;
                    onChange();
                });

                context.AddProperty("Clear Coat", 1, new EnumField(FeatureType.Always) { value = clearCoat }, (evt) =>
                {
                    if (Equals(clearCoat, evt.newValue))
                        return;

                    registerUndo("Change Clear Coat");
                    clearCoat = (FeatureType)evt.newValue;
                    onChange();
                });

                context.AddProperty("Clear Coat Normal", 1, new Toggle() { value = clearCoatNormal }, (evt) =>
                {
                    if (Equals(clearCoatNormal, evt.newValue))
                        return;

                    registerUndo("Change Clear Coat Normal");
                    clearCoatNormal = evt.newValue;
                    onChange();
                });

                context.AddProperty("Env Reflection Mode", 1,
                    new EnumField(EnvReflectionMode.Default) { value = envReflectionMode }, (evt) =>
                    {
                        if (Equals(envReflectionMode, evt.newValue))
                            return;

                        registerUndo("Change Env Reflection Mode");
                        envReflectionMode = (EnvReflectionMode)evt.newValue;
                        onChange();
                    });

                context.AddProperty("Env Rotate", 1, new EnumField(FeatureType.Always) { value = envRotate }, (evt) =>
                {
                    if (Equals(envRotate, evt.newValue))
                        return;

                    registerUndo("Change Env Rotate");
                    envRotate = (FeatureType)evt.newValue;
                    onChange();
                });
                
                context.AddProperty("Refraction", 1, new EnumField(FeatureType.Always) { value = refraction }, (evt) =>
                {
                    if (Equals(refraction, evt.newValue))
                        return;

                    registerUndo("Change Refraction");
                    refraction = (FeatureType)evt.newValue;
                    onChange();
                });

                context.AddProperty("Custom Shadow Bias", 1, new EnumField(FeatureType.Always) { value = customShadowBias }, (evt) =>
                {
                    if (Equals(customShadowBias, evt.newValue))
                        return;

                    registerUndo("Change Custom Shadow Bias");
                    customShadowBias = (FeatureType)evt.newValue;
                    onChange();
                });
            }
        }

        protected override int ComputeMaterialNeedsUpdateHash()
        {
            int hash = base.ComputeMaterialNeedsUpdateHash();
            hash = hash * 23 + target.allowMaterialOverride.GetHashCode();
            return hash;
        }

        internal override void OnAfterParentTargetDeserialized()
        {
            Assert.IsNotNull(target);

            if (this.sgVersion < latestVersion)
            {
                // Upgrade old incorrect Premultiplied blend into
                // equivalent Alpha + Preserve Specular blend mode.
                if (this.sgVersion < 1)
                {
                    if (target.alphaMode == AlphaMode.Premultiply)
                    {
                        target.alphaMode = AlphaMode.Alpha;
                        blendModePreserveSpecular = true;
                    }
                    else
                        blendModePreserveSpecular = false;
                }

                ChangeVersion(latestVersion);
            }
        }

        public virtual bool TryUpgradeFromMasterNode(IMasterNode1 masterNode,
            out Dictionary<BlockFieldDescriptor, int> blockMap)
        {
            blockMap = null;
            if (!(masterNode is PBRMasterNode1 pbrMasterNode))
                return false;

            m_WorkflowMode = (WorkflowMode)pbrMasterNode.m_Model;
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
            if (m_WorkflowMode == WorkflowMode.Specular)
                blockMap.Add(BlockFields.SurfaceDescription.Specular, 3);
            else if (m_WorkflowMode == WorkflowMode.Metallic)
                blockMap.Add(BlockFields.SurfaceDescription.Metallic, 2);

            return true;
        }

        internal static class CoreKeywordDescriptors_Fern
        {
            public static readonly KeywordDescriptor WriteRenderingLayers = new KeywordDescriptor()
            {
                displayName = "Write Rendering Layers",
                referenceName = "_WRITE_RENDERING_LAYERS",
                type = KeywordType.Boolean,
                definition = KeywordDefinition.MultiCompile,
                scope = KeywordScope.Global,
                stages = KeywordShaderStage.Fragment,
            };

            public static readonly KeywordDescriptor UseEnvRotate = new KeywordDescriptor()
            {
                displayName = "Env Rotate",
                referenceName = "_ENVROTATE",
                type = KeywordType.Boolean,
                definition = KeywordDefinition.ShaderFeature,
                scope = KeywordScope.Local,
            };

            public static readonly KeywordDescriptor DiffuseModel = new KeywordDescriptor()
            {
                displayName = "Diffusion Model",
                referenceName = "",
                type = KeywordType.Enum,
                definition = KeywordDefinition.Predefined,
                scope = KeywordScope.Local,
                entries = new KeywordEntry[]
                {
                    new KeywordEntry() { displayName = "Lambert", referenceName = "LAMBERTIAN 1" },
                    new KeywordEntry() { displayName = "Cell Shading", referenceName = "CELLSHADING 1" },
                    new KeywordEntry() { displayName = "Ramp Shading", referenceName = "RAMPSHADING 1" },
                    new KeywordEntry() { displayName = "Disney", referenceName = "DISNEY 1" },
                }
            };

            public static readonly KeywordDescriptor FabricType = new KeywordDescriptor()
            {
                displayName = "Fabric Type",
                referenceName = "",
                type = KeywordType.Enum,
                definition = KeywordDefinition.Predefined,
                scope = KeywordScope.Local,
                entries = new KeywordEntry[]
                {
                    new KeywordEntry() { displayName = "COTTON", referenceName = "FABRIC_COTTON_WOOL 1" },
                    new KeywordEntry() { displayName = "SILK", referenceName = "FABRIC_SILK 1" },
                }
            };

            public static readonly KeywordDescriptor EnvReflectionMode = new KeywordDescriptor()
            {
                displayName = "Env Reflection Mode",
                referenceName = "",
                type = KeywordType.Enum,
                definition = KeywordDefinition.Predefined,
                scope = KeywordScope.Local,
                entries = new KeywordEntry[]
                {
                    new KeywordEntry() { displayName = "Default", referenceName = "ENVDEFAULT 1" },
                    new KeywordEntry() { displayName = "CUSTOM", referenceName = "ENVCUSTOM 1" },
                }
            };

            public static readonly KeywordDescriptor SpecularModel = new KeywordDescriptor()
            {
                displayName = "Specular Model",
                referenceName = "",
                type = KeywordType.Enum,
                definition = KeywordDefinition.Predefined,
                scope = KeywordScope.Local,
                entries = new KeywordEntry[]
                {
                    new KeywordEntry() { displayName = "GGX", referenceName = "GGX 1" },
                    new KeywordEntry() { displayName = "STYLIZED", referenceName = "STYLIZED 1" },
                    new KeywordEntry() { displayName = "BLINNPHONG", referenceName = "BLINNPHONG 1" },
                    new KeywordEntry() { displayName = "Anisotropy", referenceName = "ANISO 1" },
                }
            };

            public static readonly KeywordDescriptor UseGeometryAA = new KeywordDescriptor()
            {
                displayName = "Geometry AA",
                referenceName = "_SPECULARAA",
                type = KeywordType.Boolean,
                definition = KeywordDefinition.ShaderFeature,
                scope = KeywordScope.Local,
            };

            public static readonly KeywordDescriptor Refraction = new KeywordDescriptor()
            {
                displayName = "Refraction",
                referenceName = "_REFRACTION",
                type = KeywordType.Boolean,
                definition = KeywordDefinition.ShaderFeature,
                scope = KeywordScope.Local,
            };
            
            public static readonly KeywordDescriptor CustomShadowBias = new KeywordDescriptor()
            {
                displayName = "Custom Shadow",
                referenceName = "_CUSTOMSHADOWBIAS",
                type = KeywordType.Boolean,
                definition = KeywordDefinition.ShaderFeature,
                scope = KeywordScope.Local,
            };

            public static readonly KeywordDescriptor TransparentShadowCaster = new KeywordDescriptor()
            {
                displayName = "Transparent Shadow Caster",
                referenceName = "_TRANSPARENTSHADOWCASTER",
                type = KeywordType.Boolean,
                definition = KeywordDefinition.ShaderFeature,
                scope = KeywordScope.Local,
                stages = KeywordShaderStage.Fragment,
            };
        }

        internal static class FernCorePasses
        {
            internal static void AddLODCrossFadeControlToPass(ref PassDescriptor pass, UniversalTarget target)
            {
                if (target.supportsLodCrossFade)
                {
                    pass.includes.Add(FernInclude.LODCrossFade);
                    pass.keywords.Add(CoreKeywordDescriptors.LODFadeCrossFade);
                    pass.defines.Add(CoreKeywordDescriptors.UseUnityCrossFade, 1);
                }
            }
            
            internal static void AddTransparentShadowCasterControlToPass(ref PassDescriptor pass, UniversalTarget target)
            {
                if (target.allowMaterialOverride)
                    pass.keywords.Add(CoreKeywordDescriptors_Fern.TransparentShadowCaster);
                else if (target.surfaceType == SurfaceType.Transparent)
                    pass.defines.Add(CoreKeywordDescriptors_Fern.TransparentShadowCaster, 1);
            }
            
            internal static void AddAlphaClipControlToPass(ref PassDescriptor pass, UniversalTarget target)
            {
                if (target.allowMaterialOverride)
                    pass.keywords.Add(CoreKeywordDescriptors.AlphaTestOn);
                else if (target.alphaClip)
                    pass.defines.Add(CoreKeywordDescriptors.AlphaTestOn, 1);
            }
            
            public static void AddReceiveShadowsControlToPass(ref PassDescriptor pass, UniversalTarget target,
                bool receiveShadows)
            {
                if (target.allowMaterialOverride)
                    pass.keywords.Add(LitKeywords.ReceiveShadowsOff);
                else if (!receiveShadows)
                    pass.defines.Add(LitKeywords.ReceiveShadowsOff, 1);
            }

            public static void AddEnvRotateControlToPass(ref PassDescriptor pass, UniversalTarget target,
                FeatureType featureType)
            {
                switch (featureType)
                {
                    case FeatureType.Always:
                        pass.defines.Add(CoreKeywordDescriptors_Fern.UseEnvRotate, 1);
                        break;
                    case FeatureType.Toggle:
                        pass.keywords.Add(CoreKeywordDescriptors_Fern.UseEnvRotate);
                        break;
                    default:
                        break;
                }
            }
            
            public static void AddRefractionControlToPass(ref PassDescriptor pass, UniversalTarget target,
                FeatureType featureType)
            {
                switch (featureType)
                {
                    case FeatureType.Always:
                        pass.defines.Add(CoreKeywordDescriptors_Fern.Refraction, 0);
                        break;
                    case FeatureType.Toggle:
                        pass.keywords.Add(CoreKeywordDescriptors_Fern.Refraction);
                        break;
                }
            }

            public static void AddEnvReflectionModeControlToPass(ref PassDescriptor pass, UniversalTarget target,
                EnvReflectionMode reflectionMode)
            {
                switch (reflectionMode)
                {
                    case EnvReflectionMode.Default:
                        pass.defines.Add(CoreKeywordDescriptors_Fern.EnvReflectionMode, 0);
                        break;
                    case EnvReflectionMode.Custom:
                        pass.defines.Add(CoreKeywordDescriptors_Fern.EnvReflectionMode, 1);
                        break;
                }
            }
            
            public static void AddDiffusionModelControlToPass(ref PassDescriptor pass, UniversalTarget target,
                DiffusionModel diffusionModel)
            {
                switch (diffusionModel)
                {
                    case DiffusionModel.Lambert:
                        pass.defines.Add(CoreKeywordDescriptors_Fern.DiffuseModel, 0);
                        break;
                    case DiffusionModel.Cell:
                        pass.defines.Add(CoreKeywordDescriptors_Fern.DiffuseModel, 1);

                        break;
                    case DiffusionModel.Ramp:
                        pass.defines.Add(CoreKeywordDescriptors_Fern.DiffuseModel, 2);
                        break;
                    case DiffusionModel.Disney:
                        pass.defines.Add(CoreKeywordDescriptors_Fern.DiffuseModel, 3);
                        break;
                }
            }
            
            public static void AddSpecularModelControlToPass(ref PassDescriptor pass, UniversalTarget target,
                SpecularModel specularModel)
            {
                switch (specularModel)
                {
                    case SpecularModel.Aniso:
                        pass.defines.Add(CoreKeywordDescriptors_Fern.SpecularModel, 3);
                        break;
                    case SpecularModel.GGX:
                        pass.defines.Add(CoreKeywordDescriptors_Fern.SpecularModel, 0);
                        break;
                    case SpecularModel.STYLIZED:
                        pass.defines.Add(CoreKeywordDescriptors_Fern.SpecularModel, 1);

                        break;
                    case SpecularModel.BLINNPHONG
                        :
                        pass.defines.Add(CoreKeywordDescriptors_Fern.SpecularModel, 2);
                        break;
                }
            }
            
            public static void AddFabricModeControlToPass(ref PassDescriptor pass, UniversalTarget target,
                FabricType fabricType)
            {
                switch (fabricType)
                {
                    case FabricType.Cotton:
                        pass.defines.Add(CoreKeywordDescriptors_Fern.FabricType, 0);
                        break;
                    case FabricType.Silk:
                        pass.defines.Add(CoreKeywordDescriptors_Fern.FabricType, 1);
                        break;
                }
            }

            public static void AddGeometryAAControlToPass(ref PassDescriptor pass, UniversalTarget target,
                FeatureType featureType)
            {
                switch (featureType)
                {
                    case FeatureType.Always:
                        pass.defines.Add(CoreKeywordDescriptors_Fern.UseGeometryAA, 1);
                        break;
                    case FeatureType.Toggle:
                        pass.keywords.Add(CoreKeywordDescriptors_Fern.UseGeometryAA);
                        break;
                    default:
                        break;
                }
            }
            
            internal static void AddClearCoatControlToPass(ref PassDescriptor pass, UniversalTarget target,
                FeatureType clearCoatFeatureType, bool clearCoatNormal, bool isKeyword = false)
            {

                switch (clearCoatFeatureType)
                {
                    case FeatureType.Always:
                        pass.defines.Add(LitDefines.ClearCoat, 1);
                        break;
                    case FeatureType.Toggle:
                        pass.keywords.Add(LitDefines.ClearCoat);
                        break;
                    default:
                        break;
                }
                if (clearCoatNormal)
                {
                    pass.defines.Add(LitDefines.ClearCoatNormal, 1);
                }
            }

            public static void AddCustomShadowBiasToPass(ref PassDescriptor pass, UniversalTarget target,
                FeatureType featureType)
            {
                switch (featureType)
                {
                    case FeatureType.Always:
                        pass.defines.Add(CoreKeywordDescriptors_Fern.CustomShadowBias, 1);
                        break;
                    case FeatureType.Toggle:
                        pass.keywords.Add(CoreKeywordDescriptors_Fern.CustomShadowBias);
                        break;
                    default:
                        break;
                }
            }
            
            /// <summary>
            ///  Automatically enables Alpha-To-Coverage in the provided opaque pass targets using alpha clipping
            /// </summary>
            /// <param name="pass">The pass to modify</param>
            /// <param name="target">The target to query</param>
            internal static void AddAlphaToMaskControlToPass(ref PassDescriptor pass, UniversalTarget target)
            {
                if (target.allowMaterialOverride)
                {
                    // When material overrides are allowed, we have to rely on the _AlphaToMask material property since we can't be
                    // sure of the surface type and alpha clip state based on the target alone.
                    pass.renderStates.Add(RenderState.AlphaToMask("[_AlphaToMask]"));
                }
                else if (target.alphaClip && (target.surfaceType == SurfaceType.Opaque))
                {
                    pass.renderStates.Add(RenderState.AlphaToMask("On"));
                }
            }
            
            internal static void AddWorkflowModeControlToPass(ref PassDescriptor pass, UniversalTarget target, WorkflowMode workflowMode)
            {
                if (target.allowMaterialOverride)
                    pass.keywords.Add(LitDefines.SpecularSetup);
                else if (workflowMode == WorkflowMode.Specular)
                    pass.defines.Add(LitDefines.SpecularSetup, 1);
            }

            internal static void AddTargetSurfaceControlsToPass(ref PassDescriptor pass, UniversalTarget target,
                bool blendModePreserveSpecular = false)
            {
                // the surface settings can either be material controlled or target controlled
                if (target.allowMaterialOverride)
                {
                    // setup material control of via keyword
                    pass.keywords.Add(CoreKeywordDescriptors.SurfaceTypeTransparent);
                    pass.keywords.Add(CoreKeywordDescriptors.AlphaPremultiplyOn);
                    pass.keywords.Add(CoreKeywordDescriptors.AlphaModulateOn);
                }
                else
                {
                    // setup target control via define
                    if (target.surfaceType == SurfaceType.Transparent)
                    {
                        pass.defines.Add(CoreKeywordDescriptors.SurfaceTypeTransparent, 1);

                        // alpha premultiply in shader only needed when alpha is different for diffuse & specular
                        if ((target.alphaMode == AlphaMode.Alpha || target.alphaMode == AlphaMode.Additive) &&
                            blendModePreserveSpecular)
                            pass.defines.Add(CoreKeywordDescriptors.AlphaPremultiplyOn, 1);
                        else if (target.alphaMode == AlphaMode.Multiply)
                            pass.defines.Add(CoreKeywordDescriptors.AlphaModulateOn, 1);
                    }
                }

                AddAlphaClipControlToPass(ref pass, target);
            }

            // used by lit/unlit subtargets
            public static PassDescriptor DepthOnly(UniversalTarget target)
            {
                var result = new PassDescriptor()
                {
                    // Definition
                    displayName = "DepthOnly",
                    referenceName = "SHADERPASS_DEPTHONLY",
                    lightMode = "DepthOnly",
                    useInPreview = true,

                    // Template
                    passTemplatePath = UniversalTarget.kUberTemplatePath,
                    sharedTemplateDirectories = UniversalTarget.kSharedTemplateDirectories,

                    // Port Mask
                    validVertexBlocks = CoreBlockMasks.Vertex,
                    validPixelBlocks = CoreBlockMasks.FragmentAlphaOnly,

                    // Fields
                    structs = CoreStructCollections.Default,
                    fieldDependencies = CoreFieldDependencies.Default,

                    // Conditional State
                    renderStates = CoreRenderStates.DepthOnly(target),
                    pragmas = CorePragmas.Instanced,
                    defines = new DefineCollection(),
                    keywords = new KeywordCollection(),
                    includes = new IncludeCollection { CoreIncludes.DepthOnly },

                    // Custom Interpolator Support
                    customInterpolators = CoreCustomInterpDescriptors.Common
                };

                AddAlphaClipControlToPass(ref result, target);
                AddLODCrossFadeControlToPass(ref result, target);

                return result;
            }

            // used by lit/unlit subtargets
            public static PassDescriptor DepthNormal(UniversalTarget target)
            {
                var result = new PassDescriptor()
                {
                    // Definition
                    displayName = "DepthNormals",
                    referenceName = "SHADERPASS_DEPTHNORMALS",
                    lightMode = "DepthNormals",
                    useInPreview = true,

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
                    includes = new IncludeCollection { CoreIncludes.DepthNormalsOnly },

                    // Custom Interpolator Support
                    customInterpolators = CoreCustomInterpDescriptors.Common
                };

                AddAlphaClipControlToPass(ref result, target);
                AddLODCrossFadeControlToPass(ref result, target);

                return result;
            }

            // used by lit/unlit subtargets
            public static PassDescriptor DepthNormalOnly(UniversalTarget target)
            {
                var result = new PassDescriptor()
                {
                    // Definition
                    displayName = "DepthNormalsOnly",
                    referenceName = "SHADERPASS_DEPTHNORMALSONLY",
                    lightMode = "DepthNormalsOnly",
                    useInPreview = true,

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
                    keywords = new KeywordCollection { CoreKeywordDescriptors.GBufferNormalsOct },
                    includes = new IncludeCollection { CoreIncludes.DepthNormalsOnly },

                    // Custom Interpolator Support
                    customInterpolators = CoreCustomInterpDescriptors.Common
                };

                AddAlphaClipControlToPass(ref result, target);
                AddLODCrossFadeControlToPass(ref result, target);

                return result;
            }

            // used by lit/unlit targets
            public static PassDescriptor ShadowCaster(UniversalTarget target)
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
                    validVertexBlocks = CoreBlockMasks.Vertex,
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
                    includes = new IncludeCollection { CoreIncludes.ShadowCaster },

                    // Custom Interpolator Support
                    customInterpolators = CoreCustomInterpDescriptors.Common
                };

                AddAlphaClipControlToPass(ref result, target);
                AddLODCrossFadeControlToPass(ref result, target);

                return result;
            }

            public static PassDescriptor SceneSelection(UniversalTarget target)
            {
                var result = new PassDescriptor()
                {
                    // Definition
                    displayName = "SceneSelectionPass",
                    referenceName = "SHADERPASS_DEPTHONLY",
                    lightMode = "SceneSelectionPass",
                    useInPreview = false,

                    // Template
                    passTemplatePath = UniversalTarget.kUberTemplatePath,
                    sharedTemplateDirectories = UniversalTarget.kSharedTemplateDirectories,

                    // Port Mask
                    validVertexBlocks = CoreBlockMasks.Vertex,
                    validPixelBlocks = CoreBlockMasks.FragmentAlphaOnly,

                    // Fields
                    structs = CoreStructCollections.Default,
                    fieldDependencies = CoreFieldDependencies.Default,

                    // Conditional State
                    renderStates = CoreRenderStates.SceneSelection(target),
                    pragmas = CorePragmas.Instanced,
                    defines = new DefineCollection
                        { CoreDefines.SceneSelection, { CoreKeywordDescriptors.AlphaClipThreshold, 1 } },
                    keywords = new KeywordCollection(),
                    includes = CoreIncludes.SceneSelection,

                    // Custom Interpolator Support
                    customInterpolators = CoreCustomInterpDescriptors.Common
                };

                AddAlphaClipControlToPass(ref result, target);

                return result;
            }

            public static PassDescriptor ScenePicking(UniversalTarget target)
            {
                var result = new PassDescriptor()
                {
                    // Definition
                    displayName = "ScenePickingPass",
                    referenceName = "SHADERPASS_DEPTHONLY",
                    lightMode = "Picking",
                    useInPreview = false,

                    // Template
                    passTemplatePath = UniversalTarget.kUberTemplatePath,
                    sharedTemplateDirectories = UniversalTarget.kSharedTemplateDirectories,

                    // Port Mask
                    validVertexBlocks = CoreBlockMasks.Vertex,
                    validPixelBlocks = CoreBlockMasks.FragmentAlphaOnly,

                    // Fields
                    structs = CoreStructCollections.Default,
                    fieldDependencies = CoreFieldDependencies.Default,

                    // Conditional State
                    renderStates = CoreRenderStates.ScenePicking(target),
                    pragmas = CorePragmas.Instanced,
                    defines = new DefineCollection
                        { CoreDefines.ScenePicking, { CoreKeywordDescriptors.AlphaClipThreshold, 1 } },
                    keywords = new KeywordCollection(),
                    includes = CoreIncludes.ScenePicking,

                    // Custom Interpolator Support
                    customInterpolators = CoreCustomInterpDescriptors.Common
                };

                AddAlphaClipControlToPass(ref result, target);

                return result;
            }

            public static PassDescriptor _2DSceneSelection(UniversalTarget target)
            {
                var result = new PassDescriptor()
                {
                    // Definition
                    displayName = "SceneSelectionPass",
                    referenceName = "SHADERPASS_DEPTHONLY",
                    lightMode = "SceneSelectionPass",
                    useInPreview = false,

                    // Template
                    passTemplatePath = UniversalTarget.kUberTemplatePath,
                    sharedTemplateDirectories = UniversalTarget.kSharedTemplateDirectories,

                    // Port Mask
                    validVertexBlocks = CoreBlockMasks.Vertex,
                    validPixelBlocks = CoreBlockMasks.FragmentAlphaOnly,

                    // Fields
                    structs = CoreStructCollections.Default,
                    fieldDependencies = CoreFieldDependencies.Default,

                    // Conditional State
                    renderStates = CoreRenderStates.SceneSelection(target),
                    pragmas = CorePragmas._2DDefault,
                    defines = new DefineCollection
                        { CoreDefines.SceneSelection, { CoreKeywordDescriptors.AlphaClipThreshold, 0 } },
                    keywords = new KeywordCollection(),
                    includes = CoreIncludes.ScenePicking,

                    // Custom Interpolator Support
                    customInterpolators = CoreCustomInterpDescriptors.Common
                };

                AddAlphaClipControlToPass(ref result, target);

                return result;
            }

            public static PassDescriptor _2DScenePicking(UniversalTarget target)
            {
                var result = new PassDescriptor()
                {
                    // Definition
                    displayName = "ScenePickingPass",
                    referenceName = "SHADERPASS_DEPTHONLY",
                    lightMode = "Picking",
                    useInPreview = false,

                    // Template
                    passTemplatePath = UniversalTarget.kUberTemplatePath,
                    sharedTemplateDirectories = UniversalTarget.kSharedTemplateDirectories,

                    // Port Mask
                    validVertexBlocks = CoreBlockMasks.Vertex,
                    validPixelBlocks = CoreBlockMasks.FragmentAlphaOnly,

                    // Fields
                    structs = CoreStructCollections.Default,
                    fieldDependencies = CoreFieldDependencies.Default,

                    // Conditional State
                    renderStates = CoreRenderStates.ScenePicking(target),
                    pragmas = CorePragmas._2DDefault,
                    defines = new DefineCollection
                        { CoreDefines.ScenePicking, { CoreKeywordDescriptors.AlphaClipThreshold, 0 } },
                    keywords = new KeywordCollection(),
                    includes = CoreIncludes.SceneSelection,

                    // Custom Interpolator Support
                    customInterpolators = CoreCustomInterpDescriptors.Common
                };

                AddAlphaClipControlToPass(ref result, target);

                return result;
            }
        }

        internal static class LitDefines
        {
            public static readonly KeywordDescriptor ClearCoat = new KeywordDescriptor()
            {
                displayName = "Clear Coat",
                referenceName = "_CLEARCOAT",
                type = KeywordType.Boolean,
                definition = KeywordDefinition.ShaderFeature,
                scope = KeywordScope.Local,
                stages = KeywordShaderStage.Fragment
            };

            public static readonly KeywordDescriptor ClearCoatNormal = new KeywordDescriptor()
            {
                displayName = "Clear Coat Normal",
                referenceName = "_CLEARCOATNORMAL",
                type = KeywordType.Boolean,
                definition = KeywordDefinition.ShaderFeature,
                scope = KeywordScope.Local,
                stages = KeywordShaderStage.Fragment
            };

            public static readonly KeywordDescriptor SpecularSetup = new KeywordDescriptor()
            {
                displayName = "Specular Setup",
                referenceName = "_SPECULAR_SETUP",
                type = KeywordType.Boolean,
                definition = KeywordDefinition.ShaderFeature,
                scope = KeywordScope.Local,
                stages = KeywordShaderStage.Fragment
            };
        }

        internal static class LitKeywords
        {
            public static readonly KeywordDescriptor ReceiveShadowsOff = new KeywordDescriptor()
            {
                displayName = "Receive Shadows Off",
                referenceName = ShaderKeywordStrings._RECEIVE_SHADOWS_OFF,
                type = KeywordType.Boolean,
                definition = KeywordDefinition.ShaderFeature,
                scope = KeywordScope.Local,
            };

            public static readonly KeywordCollection Forward = new KeywordCollection
            {
                { CoreKeywordDescriptors.ScreenSpaceAmbientOcclusion },
                { CoreKeywordDescriptors.StaticLightmap },
                { CoreKeywordDescriptors.DynamicLightmap },
                { CoreKeywordDescriptors.DirectionalLightmapCombined },
                { CoreKeywordDescriptors.MainLightShadows },
                { CoreKeywordDescriptors.AdditionalLights },
                { CoreKeywordDescriptors.AdditionalLightShadows },
                { CoreKeywordDescriptors.ReflectionProbeBlending },
                { CoreKeywordDescriptors.ReflectionProbeBoxProjection },
                { CoreKeywordDescriptors.ShadowsSoft },
                { CoreKeywordDescriptors.LightmapShadowMixing },
                { CoreKeywordDescriptors.ShadowsShadowmask },
                { CoreKeywordDescriptors.DBuffer },
                { CoreKeywordDescriptors.LightLayers },
                { CoreKeywordDescriptors.DebugDisplay },
                { CoreKeywordDescriptors.LightCookies },
                { CoreKeywordDescriptors.ForwardPlus },
            };

            public static readonly KeywordCollection FernForward = new KeywordCollection
            {
                //{ CoreKeywordDescriptors.ScreenSpaceAmbientOcclusion },
                //{ CoreKeywordDescriptors.StaticLightmap },
                //{ CoreKeywordDescriptors.DynamicLightmap },
                //{ CoreKeywordDescriptors.DirectionalLightmapCombined },
                { CoreKeywordDescriptors.MainLightShadows },
                //{ CoreKeywordDescriptors.AdditionalLights },
                //{ CoreKeywordDescriptors.AdditionalLightShadows },
                //{ CoreKeywordDescriptors.ReflectionProbeBlending },
                //{ CoreKeywordDescriptors.ReflectionProbeBoxProjection },
                { CoreKeywordDescriptors.ShadowsSoft },
                //{ CoreKeywordDescriptors.LightmapShadowMixing },
                //{ CoreKeywordDescriptors.ShadowsShadowmask },
                //{ CoreKeywordDescriptors.DBuffer },
                // { CoreKeywordDescriptors.LightLayers },
                //{ CoreKeywordDescriptors.DebugDisplay },
                //{ CoreKeywordDescriptors.LightCookies },
                //{ CoreKeywordDescriptors.ForwardPlus },
            };

            public static readonly KeywordCollection FernPlanarReflectionForward = new KeywordCollection
            {
                { CoreKeywordDescriptors.MainLightShadows },
            };

            public static readonly KeywordCollection FernSSGIKeywords = new KeywordCollection
            {
                // TODO:
            };

            public static readonly KeywordCollection DOTSForward = new KeywordCollection
            {
                { FernForward },
                { CoreKeywordDescriptors_Fern.WriteRenderingLayers },
            };

            public static readonly KeywordCollection GBuffer = new KeywordCollection
            {
                { CoreKeywordDescriptors.StaticLightmap },
                { CoreKeywordDescriptors.DynamicLightmap },
                { CoreKeywordDescriptors.DirectionalLightmapCombined },
                { CoreKeywordDescriptors.MainLightShadows },
                { CoreKeywordDescriptors.ReflectionProbeBlending },
                { CoreKeywordDescriptors.ReflectionProbeBoxProjection },
                { CoreKeywordDescriptors.ShadowsSoft },
                { CoreKeywordDescriptors.LightmapShadowMixing },
                { CoreKeywordDescriptors.ShadowsShadowmask },
                { CoreKeywordDescriptors.MixedLightingSubtractive },
                { CoreKeywordDescriptors.DBuffer },
                { CoreKeywordDescriptors.GBufferNormalsOct },
                { CoreKeywordDescriptors.RenderPassEnabled },
                { CoreKeywordDescriptors.DebugDisplay },
            };
        }
        
        internal static class FernInclude
        {
            public const string kColor = "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl";
            public const string kTexture = "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl";
            public const string kCore = "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl";
            public const string kInput = "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl";
            public const string kLighting = "Packages/com.tateam.shadergraph/ShaderLibrary/FernSGNPRLighting.hlsl";
            public const string kVaryings = "Packages/com.tateam.shadergraph/ShaderLibrary/Varyings.hlsl";

            public const string kGraphFunctions =
                "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl";

            public const string kShaderPass =
                "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl";

            public const string kDepthOnlyPass =
                "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/DepthOnlyPass.hlsl";

            public const string kDepthNormalsOnlyPass =
                "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/DepthNormalsOnlyPass.hlsl";

            public const string kShadowCasterPass =
                "Packages/com.tateam.shadergraph/ShaderLibrary/ShadowCasterPass.hlsl";

            public const string kTextureStack =
                "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl";

            public const string kDBuffer = "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl";

            public const string kSelectionPickingPass =
                "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/SelectionPickingPass.hlsl";

            public const string kLODCrossFade =
                "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl";

            // Files that are included with #include_with_pragmas
            public const string kDOTS = "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl";

            public const string kRenderingLayers =
                "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl";

            public const string kProbeVolumes =
                "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ProbeVolumeVariants.hlsl";

            // Lit
            public const string kShadows = "Packages/com.tateam.shadergraph/ShaderLibrary/Shadows.hlsl";

            public const string kMetaInput =
                "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl";

            public const string kLitProForwardPass =
                "Packages/com.tateam.shadergraph/ShaderLibrary/FernSGForwardPass.hlsl";

            public const string kLitFabricForwardPass =
                "Packages/com.tateam.shadergraph/ShaderLibrary/FernSGFabricForwardPass.hlsl";

            public const string kSSGIBaseColorForwardPass =
                "Packages/com.tateam.shadergraph/ShaderLibrary/FernSGBaseColorPass.hlsl";

            public const string kGBuffer =
                "Packages/com.tateam.shadergraph/ShaderLibrary/FernGBuffer.hlsl";

            public const string kPBRGBufferPass =
                "Packages/com.tateam.shadergraph/ShaderLibrary/FernGBufferPass.hlsl";

            public const string kLightingMetaPass =
                "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/LightingMetaPass.hlsl";

            public const string k2DPass =
                "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/PBR2DPass.hlsl";

            public static readonly IncludeCollection DOTSPregraph = new IncludeCollection
            {
                { FernInclude.kDOTS, IncludeLocation.Pregraph, true },
            };

            public static readonly IncludeCollection WriteRenderLayersPregraph = new IncludeCollection
            {
                { FernInclude.kRenderingLayers, IncludeLocation.Pregraph, true },
            };

            public static readonly IncludeCollection CorePregraph = new IncludeCollection
            {
                { kColor, IncludeLocation.Pregraph },
                { kTexture, IncludeLocation.Pregraph },
                { kCore, IncludeLocation.Pregraph },
                { kLighting, IncludeLocation.Pregraph },
                { kInput, IncludeLocation.Pregraph },
                { kTextureStack, IncludeLocation.Pregraph }, // TODO: put this on a conditional
            };

            public static readonly IncludeCollection ShaderGraphPregraph = new IncludeCollection
            {
                { kGraphFunctions, IncludeLocation.Pregraph },
            };

            public static readonly IncludeCollection CorePostgraph = new IncludeCollection
            {
                { kShaderPass, IncludeLocation.Pregraph },
                { kVaryings, IncludeLocation.Postgraph },
            };

            public static readonly IncludeCollection DepthOnly = new IncludeCollection
            {
                // Pre-graph
                { CorePregraph },
                { ShaderGraphPregraph },

                // Post-graph
                { CorePostgraph },
                { kDepthOnlyPass, IncludeLocation.Postgraph },
            };

            public static readonly IncludeCollection DepthNormalsOnly = new IncludeCollection
            {
                // Pre-graph
                { CorePregraph },
                { ShaderGraphPregraph },

                // Post-graph
                { CorePostgraph },
                { kDepthNormalsOnlyPass, IncludeLocation.Postgraph },
            };

            public static readonly IncludeCollection ShadowCaster = new IncludeCollection
            {
                // Pre-graph
                { CorePregraph },
                { ShaderGraphPregraph },

                // Post-graph
                { CorePostgraph },
                { kShadowCasterPass, IncludeLocation.Postgraph },
            };

            public static readonly IncludeCollection DBufferPregraph = new IncludeCollection
            {
                { kDBuffer, IncludeLocation.Pregraph },
            };

            public static readonly IncludeCollection SceneSelection = new IncludeCollection
            {
                // Pre-graph
                { CorePregraph },
                { ShaderGraphPregraph },

                // Post-graph
                { CorePostgraph },
                { kSelectionPickingPass, IncludeLocation.Postgraph },
            };

            public static readonly IncludeCollection ScenePicking = new IncludeCollection
            {
                // Pre-graph
                { CorePregraph },
                { ShaderGraphPregraph },

                // Post-graph
                { CorePostgraph },
                { kSelectionPickingPass, IncludeLocation.Postgraph },
            };

            public static readonly IncludeCollection LODCrossFade = new IncludeCollection
            {
                { kLODCrossFade, IncludeLocation.Pregraph }
            };
        }
    }
}