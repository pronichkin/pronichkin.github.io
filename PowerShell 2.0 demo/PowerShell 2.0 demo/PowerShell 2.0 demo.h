#pragma once

using namespace System;
using namespace System::Globalization;
using namespace System::Security;
using namespace System::Security::Policy;
using namespace System::Collections;

namespace PowerShell20demo
{
    public ref class CompatibilityDemo
    {
    public:
        // 1. CAS Policy (throws in .NET 4.x, works in 2.0; exception is not handled)
        String^ GetCasPolicy()
        {
            IEnumerator^ e = SecurityManager::PolicyHierarchy();
            PolicyLevel^ pl = nullptr;
            if (e->MoveNext())
                pl = safe_cast<PolicyLevel^>(e->Current);

            if (pl != nullptr)
                return pl->Label;
            else
                return "CAS Policy Level not found";
        }

        // 2. Formats a currency value using the specified culture.
        // If the culture is invalid, falls back to en-US and emits a warning.
        String^ FormatCurrencyWithCulture(String^ cultureName, double value)
        {
            bool usedFallback = false;
            CultureInfo^ ci;
            try
            {
                ci = CultureInfo::CreateSpecificCulture(cultureName);
            }
            catch (ArgumentException^)
            {
                ci = gcnew CultureInfo("en-US");
                usedFallback = true;
            }

            String^ formatted = value.ToString("C", ci);

            if (usedFallback)
            {
                Console::WriteLine("Invalid culture specified: '{0}'. Falling back to 'en-US' for compatibility", cultureName);
            }
            else
            {
                Console::WriteLine("Using culture '{0}' as requested. This is a valid culture, no fallback needed", cultureName);
            }
            return formatted;
        }

        // 3. Formats the current date using the specified culture.
        // If the culture is invalid, falls back to en-US and emits a warning.
        // If the resulting culture is not in the known list, throws an exception.
        String^ FormatCurrentDateWithCultureChecked(String^ cultureName)
        {
            bool usedFallback = false;
            CultureInfo^ ci;
            try
            {
                ci = CultureInfo::CreateSpecificCulture(cultureName);
            }
            catch (ArgumentException^)
            {
                ci = gcnew CultureInfo("en-US");
                usedFallback = true;
            }

            // Get all valid culture names
            array<CultureInfo^>^ allCultures = CultureInfo::GetCultures(CultureTypes::AllCultures);
            bool found = false;
            for each (CultureInfo^ valid in allCultures)
            {
                if (String::Compare(valid->Name, ci->Name, true) == 0)
                {
                    found = true;
                    break;
                }
            }

            if (!found)
            {
                throw gcnew InvalidOperationException(
                    String::Format("Culture '{0}' is not a known valid culture on this system.", ci->Name));
            }

            String^ formatted = DateTime::Now.ToString("D", ci);

            if (usedFallback)
            {
                Console::WriteLine("Invalid culture specified: '{0}'. Falling back to 'en-US' for compatibility", cultureName);
            }
            else
            {
                Console::WriteLine("Using culture '{0}' as requested. This is a valid culture, no fallback needed", cultureName);
            }
            return formatted;
        }
    };
}