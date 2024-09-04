using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEditor.ShaderGraph.Internal;
using UnityEngine;

namespace UnityEditor.Rendering.FCShaderGraph
{
    [CreateAssetMenu(fileName = "CustomSGSettings", 
        menuName = "Create/CustomSGSettings")]
    public class FernSG_Settings : ScriptableObject
    {
        public Object CustomLitForwardPass;
        public Object NPRLighting;
        public Object ShadowCaster;
        public Object Shadow;
        public Object Varying;
    }

}

