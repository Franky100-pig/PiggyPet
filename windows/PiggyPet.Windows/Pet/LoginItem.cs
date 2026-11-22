using System;
using System.Windows.Forms;
using Microsoft.Win32;

namespace PiggyPet
{
    /// <summary>
    /// Launch at login through HKCU\...\Run - the Windows equivalent of the
    /// SMAppService login item. No elevation, and the user can turn it off from
    /// the menu or from Task Manager's Startup tab at any time.
    /// </summary>
    internal static class LoginItem
    {
        private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
        private const string ValueName = "PiggyPet";

        public static bool IsEnabled
        {
            get
            {
                try
                {
                    using (var key = Registry.CurrentUser.OpenSubKey(RunKey))
                    {
                        return key != null && key.GetValue(ValueName) != null;
                    }
                }
                catch (Exception error)
                {
                    Log.Write("login item read failed: " + error.Message);
                    return false;
                }
            }
        }

        /// <summary>Returns whether the login item is enabled afterwards.</summary>
        public static bool SetEnabled(bool enabled)
        {
            try
            {
                using (var key = Registry.CurrentUser.OpenSubKey(RunKey, true))
                {
                    if (key == null) return false;
                    if (enabled)
                    {
                        key.SetValue(ValueName, "\"" + Application.ExecutablePath + "\"");
                    }
                    else
                    {
                        key.DeleteValue(ValueName, false);
                    }
                }
                return enabled ? IsEnabled : !IsEnabled;
            }
            catch (Exception error)
            {
                Log.Write("login item write failed: " + error.Message);
                return false;
            }
        }
    }
}
