using System;
using UnityEditor;
using UnityEditor.Rendering.Universal;
using UnityEditor.Rendering.Universal.ShaderGUI;
using UnityEngine;
using static Unity.Rendering.Universal.ShaderUtils;

namespace UnityEditor.Rendering.FCShaderGraph
{
    // Used for ShaderGraph Lit shaders
    class FURPShaderGraphLitGUI : BaseShaderGUI
    {
        public MaterialProperty workflowMode;
        protected MaterialProperty geometryAA { get; set; }
        protected MaterialProperty clearCoatProp { get; set; }
        protected MaterialProperty envRotate { get; set; }
        protected MaterialProperty customShadowBias { get; set; }
        protected MaterialProperty refreaction { get; set; }

        MaterialProperty[] properties;

        // collect properties from the material properties
        public override void FindProperties(MaterialProperty[] properties)
        {
            // save off the list of all properties for shadergraph
            this.properties = properties;

            var material = materialEditor?.target as Material;
            if (material == null)
                return;

            base.FindProperties(properties);
            workflowMode = BaseShaderGUI.FindProperty(Property.SpecularWorkflowMode, properties, false);
            
            // Additional
            geometryAA =  FindProperty(FernProperty.GeometryAA, properties, false);
            clearCoatProp =  FindProperty(FernProperty.ClearCoat, properties, false);
            envRotate =  FindProperty(FernProperty.EnvRotate, properties, false);
            customShadowBias =  FindProperty(FernProperty.CustomShadowBias, properties, false);
            refreaction =  FindProperty(FernProperty.Refraction, properties, false);
        }

        public static void UpdateMaterial(Material material, MaterialUpdateType updateType)
        {
            // newly created materials should initialize the globalIlluminationFlags (default is off)
            if (updateType == MaterialUpdateType.CreatedNewMaterial)
                material.globalIlluminationFlags = MaterialGlobalIlluminationFlags.BakedEmissive;

            bool automaticRenderQueue = GetAutomaticQueueControlSetting(material);
            BaseShaderGUI.UpdateMaterialSurfaceOptions(material, automaticRenderQueue);
            UpdateSubMaterialSurfaceOptions(material, automaticRenderQueue);
            LitGUI.SetupSpecularWorkflowKeyword(material, out bool isSpecularWorkflow);
        }

        public static void UpdateSubMaterialSurfaceOptions(Material material, bool automaticRenderQueue)
        {
            // Cast Shadows
            bool clearCoat = true;
            if (material.HasProperty(FernProperty.ClearCoat))
            {
                clearCoat = (material.GetFloat(FernProperty.ClearCoat) != 0.0f);
            }
            if(clearCoat) material.EnableKeyword("_CLEARCOAT");
            else material.DisableKeyword("_CLEARCOAT");
            
            // GeometryAA
            bool geometryAA = true;
            if (material.HasProperty(FernProperty.GeometryAA))
            {
                clearCoat = (material.GetFloat(FernProperty.GeometryAA) != 0.0f);
            }
            if(clearCoat) material.EnableKeyword("_SPECULARAA");
            else material.DisableKeyword("_SPECULARAA");
            
            // EnvRotate
            bool envRotate = true;
            if (material.HasProperty(FernProperty.EnvRotate))
            {
                clearCoat = (material.GetFloat(FernProperty.EnvRotate) != 0.0f);
            }
            if(clearCoat) material.EnableKeyword("_ENVROTATE");
            else material.DisableKeyword("_ENVROTATE");
            
            // CustomShadowBias
            bool customShadowBias = true;
            if (material.HasProperty(FernProperty.CustomShadowBias))
            {
                clearCoat = (material.GetFloat(FernProperty.CustomShadowBias) != 0.0f);
            }
            if(clearCoat) material.EnableKeyword("_CUSTOMSHADOWBIAS");
            else material.DisableKeyword("_CUSTOMSHADOWBIAS");
            
            // Refraction
            bool refraction = true;
            if (material.HasProperty(FernProperty.Refraction)) 
            {
                refraction = (material.GetFloat(FernProperty.Refraction) != 0.0f);
            }
            if(refraction) material.EnableKeyword("_REFRACTION");
            else material.DisableKeyword("_REFRACTION");
        }

        public override void ValidateMaterial(Material material)
        {
            if (material == null)
                throw new ArgumentNullException("material");

            UpdateMaterial(material, MaterialUpdateType.ModifiedMaterial);
        }

        public override void DrawSurfaceOptions(Material material)
        {
            if (material == null)
                throw new ArgumentNullException("material");

            // Use default labelWidth
            EditorGUIUtility.labelWidth = 0f;

            // Detect any changes to the material
            if (workflowMode != null)
                DoPopup(LitGUI.Styles.workflowModeText, workflowMode, Enum.GetNames(typeof(LitGUI.WorkflowMode)));
            base.DrawSurfaceOptions(material);
            
            // Additional
            DrawFloatToggleProperty(SubStyles.geometryAA, geometryAA);
            DrawFloatToggleProperty(SubStyles.clearCoatTex, clearCoatProp);
            DrawFloatToggleProperty(SubStyles.envRotate, envRotate);
            DrawFloatToggleProperty(SubStyles.customShadowBias, customShadowBias);
            if ((surfaceTypeProp != null) && ((SurfaceType)surfaceTypeProp.floatValue == SurfaceType.Transparent))
            { 
                DrawFloatToggleProperty(SubStyles.refreaction, refreaction);
            }
        }

        // material main surface inputs
        public override void DrawSurfaceInputs(Material material)
        {
            DrawShaderGraphProperties(material, properties);
        }

        public override void DrawAdvancedOptions(Material material)
        {
            // Always show the queue control field.  Only show the render queue field if queue control is set to user override
            DoPopup(Styles.queueControl, queueControlProp, Styles.queueControlNames);
            if (material.HasProperty(Property.QueueControl) && material.GetFloat(Property.QueueControl) == (float)QueueControl.UserOverride)
                materialEditor.RenderQueueField();
            base.DrawAdvancedOptions(material);

            // ignore emission color for shadergraphs, because shadergraphs don't have a hard-coded emission property, it's up to the user
            materialEditor.DoubleSidedGIField();
            materialEditor.LightmapEmissionFlagsProperty(0, enabled: true, ignoreEmissionColor: true);
        }

        class SubStyles
        {
            /// <summary>
            /// The text and tooltip for the render face GUI.
            /// </summary>
            public static readonly GUIContent clearCoatTex = EditorGUIUtility.TrTextContent("Clear Coat");
            public static readonly GUIContent envRotate = EditorGUIUtility.TrTextContent("EnvRotate");
            public static readonly GUIContent geometryAA = EditorGUIUtility.TrTextContent("Geometry AA");
            public static readonly GUIContent customShadowBias = EditorGUIUtility.TrTextContent("Custom Shadow Bias");
            public static readonly GUIContent refreaction = EditorGUIUtility.TrTextContent("Refraction");
        }
    }
} // namespace UnityEditor
