using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;

namespace PiggyPet
{
    internal sealed class SpriteInfo
    {
        public string Id = "";
        public string Kind = "image";
        public string File = "";
        public string Text = "";
        public string Mood = "neutral";
        public string Bubble = "";

        public bool IsImage { get { return Kind == "image"; } }
    }

    /// <summary>Reads Resources/manifest.json, the same file the Mac build uses.</summary>
    internal sealed class Manifest
    {
        public int SpriteSize = 160;
        public string SleepId = "sleep";
        public readonly List<SpriteInfo> Sprites = new List<SpriteInfo>();

        public static Manifest Load(string path)
        {
            var manifest = new Manifest();
            var root = Json.AsObject(Json.Parse(System.IO.File.ReadAllText(path)));
            if (root == null) return manifest;

            if (root.ContainsKey("spriteSize")) manifest.SpriteSize = (int)(double)root["spriteSize"];
            manifest.SleepId = Json.String(root, "sleepId", "sleep");

            var list = Json.AsArray(root.ContainsKey("sprites") ? root["sprites"] : null);
            if (list != null)
            {
                foreach (var entry in list)
                {
                    var sprite = new SpriteInfo
                    {
                        Id = Json.String(entry, "id"),
                        Kind = Json.String(entry, "kind", "image"),
                        File = Json.String(entry, "file"),
                        Text = Json.String(entry, "text"),
                        Mood = Json.String(entry, "mood", "neutral"),
                        Bubble = Json.String(entry, "bubble")
                    };
                    if (sprite.Id.Length > 0) manifest.Sprites.Add(sprite);
                }
            }
            return manifest;
        }

        public SpriteInfo Sleep
        {
            get { return ById(SleepId) ?? (Sprites.Count > 0 ? Sprites[0] : null); }
        }

        public SpriteInfo Chase
        {
            get { return ById("chase"); }
        }

        public SpriteInfo ById(string id)
        {
            foreach (var sprite in Sprites)
            {
                if (sprite.Id == id) return sprite;
            }
            return null;
        }

        /// <summary>A random face, never the one already showing.</summary>
        public SpriteInfo RandomExcept(string currentId, Random rng)
        {
            var pool = new List<SpriteInfo>();
            foreach (var sprite in Sprites)
            {
                if (sprite.Id != currentId) pool.Add(sprite);
            }
            if (pool.Count == 0) return Sleep;
            return pool[rng.Next(pool.Count)];
        }
    }
}
