#pragma once

using namespace System;
using namespace System::Security;
using namespace System::Security::Policy;
using namespace System::Collections;

namespace PowerShell20demo
{
    public ref class TestClass
    {
    public:
        String^ TryCasPolicy()
        {
            try
            {
                IEnumerator^ e = SecurityManager::PolicyHierarchy();
                PolicyLevel^ pl = nullptr;
                if (e->MoveNext())
                    pl = safe_cast<PolicyLevel^>(e->Current);

                if (pl != nullptr)
                    return "CAS Policy Level: " + pl->Label;
                else
                    return "CAS Policy Level: not found";
            }
            catch (Exception^ ex)
            {
                return "CAS Policy failed: " + ex->GetType()->FullName + " - " + ex->Message;
            }
        }
    };
}