using System;
using System.Globalization;
using System.Security;
using System.Security.Policy;
using System.Collections;

namespace PowerShell20Demo
{
    public class CompatibilityDemo
    {
        // 1. CAS Policy (throws in .NET 4.x, works in 2.0; exception is not handled)
        public string GetCasPolicy()
        {
            IEnumerator e = SecurityManager.PolicyHierarchy();
            PolicyLevel pl = null;
            if (e.MoveNext())
                pl = (PolicyLevel)e.Current;

            if (pl != null)
                return pl.Label;
            else
                return "CAS Policy Level not found";
        }

        // 2. Formats a currency value using the specified culture.
        // If the culture is invalid, falls back to en-US and emits a warning.
        public string GetCurrency(string cultureName, double value)
        {
            bool usedFallback = false;
            CultureInfo ci;
            try
            {
                // Obtain specific culture based on supplied name
                ci = CultureInfo.CreateSpecificCulture(cultureName);
            }
            catch (ArgumentException)
            {
                // Fallback to en-US if the culture is invalid
                ci = new CultureInfo("en-US");
                usedFallback = true;
            }

            string formatted = value.ToString("C", ci);

            if (usedFallback)
                Console.WriteLine($"Invalid culture '{cultureName}' specified. Falling back to 'en-US' for compatibility");
            else
                Console.WriteLine($"Using culture '{cultureName}' as requested. This is a valid culture, no fallback needed");

            return formatted;
        }

        // 3. Formats the current date using the specified culture.
        // If the culture is invalid, falls back to en-US and emits a warning.
        // If the resulting culture is not in the known list, throws an exception.
        public string GetDate(string cultureName)
        {
            bool usedFallback = false;
            CultureInfo ci;
            try
            {
                // Obtain specific culture based on supplied name
                ci = CultureInfo.CreateSpecificCulture(cultureName);
            }
            catch (ArgumentException)
            {
                // Fallback to en-US if the culture is invalid
                ci = new CultureInfo("en-US");
                usedFallback = true;
            }

            // Check if that's a valid culture
            bool found = false;
            foreach (var valid in CultureInfo.GetCultures(CultureTypes.AllCultures))
            {
                if (string.Equals(valid.Name, ci.Name, StringComparison.OrdinalIgnoreCase))
                {
                    found = true;
                    break;
                }
            }

            if (!found)
                throw new InvalidOperationException($"Culture '{ci.Name}' is not a known valid culture on this system.");

            string formatted = DateTime.Now.ToString("D", ci);

            if (usedFallback)
                Console.WriteLine($"Invalid culture '{cultureName}' specified. Falling back to 'en-US' for compatibility");
            else
                Console.WriteLine($"Using culture '{cultureName}' as requested. This is a valid culture, no fallback needed");

            return formatted;
        }
    }
}