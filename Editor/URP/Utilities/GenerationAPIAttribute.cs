using System;
using System.Runtime.InteropServices;

namespace UnityEditor.Rendering.FCShaderGraph
{
    [AttributeUsage(AttributeTargets.Class | AttributeTargets.Struct | AttributeTargets.Enum | AttributeTargets.Interface, Inherited = true, AllowMultiple = false)]
    internal class FernSG_GenerationAPIAttribute : Attribute
    {
        public FernSG_GenerationAPIAttribute() { }
    }
}
