using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;

namespace PiggyPet
{
    internal enum Excitement { Low, Medium, High }

    internal enum NudgeFrequency { Never, Occasionally, Often }

    internal enum WalkPace { Slow, Normal, Fast }

    /// <summary>
    /// Settings live in %APPDATA%\PiggyPet\settings.json. Raw values are ASCII
    /// so the file survives any locale, exactly like the Mac defaults.
    /// </summary>
    internal sealed class Settings
    {
        public bool HasOrigin;
        public float OriginX;
        public float OriginY;

        public bool TantrumEnabled;
        public bool BubbleEnabled = true;
        public bool LoginItemAsked;
        public bool HintShown;

        public Excitement Excitement = Excitement.Medium;
        public NudgeFrequency NudgeFrequency = NudgeFrequency.Occasionally;
        public WalkPace WalkPace = WalkPace.Normal;

        public static string Directory
        {
            get
            {
                return Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                    "PiggyPet");
            }
        }

        private static string FilePath { get { return Path.Combine(Directory, "settings.json"); } }

        public static Settings Load()
        {
            var settings = new Settings();
            try
            {
                if (!File.Exists(FilePath)) return settings;
                var root = Json.AsObject(Json.Parse(File.ReadAllText(FilePath)));
                if (root == null) return settings;

                if (root.ContainsKey("originX") && root.ContainsKey("originY"))
                {
                    settings.HasOrigin = true;
                    settings.OriginX = (float)(double)root["originX"];
                    settings.OriginY = (float)(double)root["originY"];
                }
                settings.TantrumEnabled = Bool(root, "tantrumEnabled", false);
                settings.BubbleEnabled = Bool(root, "bubbleEnabled", true);
                settings.LoginItemAsked = Bool(root, "loginItemAsked", false);
                settings.HintShown = Bool(root, "hintShown", false);
                settings.Excitement = ParseEnum(Json.String(root, "excitement", "medium"), Excitement.Medium);
                settings.NudgeFrequency = ParseEnum(Json.String(root, "nudgeFrequency", "occasionally"), NudgeFrequency.Occasionally);
                settings.WalkPace = ParseEnum(Json.String(root, "walkPace", "normal"), WalkPace.Normal);
            }
            catch (Exception error)
            {
                // A corrupt settings file must never stop the pig from starting.
                Log.Write("settings read failed: " + error.Message);
            }
            return settings;
        }

        public void Save()
        {
            try
            {
                System.IO.Directory.CreateDirectory(Directory);
                var json = new StringBuilder();
                json.Append("{\n");
                if (HasOrigin)
                {
                    json.Append("  \"originX\": ").Append(Number(OriginX)).Append(",\n");
                    json.Append("  \"originY\": ").Append(Number(OriginY)).Append(",\n");
                }
                json.Append("  \"tantrumEnabled\": ").Append(TantrumEnabled ? "true" : "false").Append(",\n");
                json.Append("  \"bubbleEnabled\": ").Append(BubbleEnabled ? "true" : "false").Append(",\n");
                json.Append("  \"loginItemAsked\": ").Append(LoginItemAsked ? "true" : "false").Append(",\n");
                json.Append("  \"hintShown\": ").Append(HintShown ? "true" : "false").Append(",\n");
                json.Append("  \"excitement\": \"").Append(Lower(Excitement.ToString())).Append("\",\n");
                json.Append("  \"nudgeFrequency\": \"").Append(Lower(NudgeFrequency.ToString())).Append("\",\n");
                json.Append("  \"walkPace\": \"").Append(Lower(WalkPace.ToString())).Append("\"\n");
                json.Append("}\n");
                File.WriteAllText(FilePath, json.ToString(), new UTF8Encoding(false));
            }
            catch (Exception error)
            {
                Log.Write("settings write failed: " + error.Message);
            }
        }

        private static bool Bool(Dictionary<string, object> root, string key, bool fallback)
        {
            if (!root.ContainsKey(key)) return fallback;
            var value = root[key];
            return value is bool ? (bool)value : fallback;
        }

        private static T ParseEnum<T>(string raw, T fallback) where T : struct
        {
            foreach (var name in Enum.GetNames(typeof(T)))
            {
                if (string.Equals(name, raw, StringComparison.OrdinalIgnoreCase))
                {
                    return (T)Enum.Parse(typeof(T), name);
                }
            }
            return fallback;
        }

        private static string Lower(string value)
        {
            return value.ToLowerInvariant();
        }

        private static string Number(float value)
        {
            return ((int)Math.Round(value)).ToString(CultureInfo.InvariantCulture);
        }
    }

    /// <summary>
    /// Tiny logger for --debug runs. The app is a windowless exe, so stderr has
    /// nowhere to go; write a file in %TEMP% instead.
    /// </summary>
    internal static class Log
    {
        public static bool Enabled;

        private static readonly string Path = System.IO.Path.Combine(
            System.IO.Path.GetTempPath(), "piggy-debug.log");

        public static void Write(string message)
        {
            if (!Enabled) return;
            try
            {
                System.IO.File.AppendAllText(Path,
                    DateTime.Now.ToString("HH:mm:ss.fff") + " " + message + Environment.NewLine);
            }
            catch
            {
                // Logging must never take the app down.
            }
        }

        /// <summary>
        /// Always-on crash log. If the Windows build misbehaves on someone
        /// else's machine, %TEMP%\piggy-error.log is the first thing to ask for.
        /// </summary>
        public static void Error(string message)
        {
            try
            {
                var path = System.IO.Path.Combine(
                    System.IO.Path.GetTempPath(), "piggy-error.log");
                System.IO.File.AppendAllText(path,
                    DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " " + message + Environment.NewLine);
            }
            catch
            {
            }
        }
    }
}
