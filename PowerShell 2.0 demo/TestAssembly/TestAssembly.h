#pragma once

using namespace System;

namespace TestAssembly
{
    public ref class Plugin
    {
    public:
        String^ Hello()
        {
            return "Hello from plugin!";
        }
    };
}