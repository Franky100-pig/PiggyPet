using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.IO;

namespace PiggyPet
{
    internal enum WalkStyle { Trot, Dash }

    /// <summary>
    /// Loads the PNGs and the manifest that ship next to the exe, and renders
    /// the text "faces" the same way the Mac build does.
    /// </summary>
    internal sealed class Assets
    {
        private readonly Dictionary<string, Image> cache = new Dictionary<string, Image>();
        private readonly List<Image> walkLeft = new List<Image>();
        private readonly List<Image> walkRight = new List<Image>();
        private readonly List<Image> runLeft = new List<Image>();
        private readonly List<Image> runRight = new List<Image>();
        private readonly string root;
        private readonly float scale;

        public readonly Manifest Manifest;

        public Assets(string baseDirectory, float scale)
        {
            root = baseDirectory;
            this.scale = scale;
            Manifest = Manifest.Load(Path.Combine(root, "manifest.json"));
            LoadFrames("walk", walkLeft, walkRight);
            LoadFrames("run", runLeft, runRight);
        }

        public bool WalkAvailable { get { return walkLeft.Count > 0; } }
        public bool RunAvailable { get { return runLeft.Count > 0; } }
        public SpriteInfo Sleep { get { return Manifest.Sleep; } }
        public SpriteInfo Chase { get { return Manifest.Chase ?? Manifest.Sleep; } }

        public IList<Image> Frames(WalkStyle style, bool facingRight)
        {
            if (style == WalkStyle.Dash)
            {
                var dash = facingRight ? runRight : runLeft;
                return dash.Count > 0 ? dash : (facingRight ? walkRight : walkLeft);
            }
            return facingRight ? walkRight : walkLeft;
        }

        public Image ImageFor(SpriteInfo sprite)
        {
            if (sprite == null) return null;
            Image cached;
            if (cache.TryGetValue(sprite.Id, out cached)) return cached;

            Image image = null;
            if (sprite.IsImage && sprite.File.Length > 0)
            {
                var path = Path.Combine(root, sprite.File.Replace('/', Path.DirectorySeparatorChar));
                if (File.Exists(path))
                {
                    // Copy through a stream so the PNG is never locked on disk.
                    using (var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                    {
                        image = Image.FromStream(stream);
                    }
                }
            }
            if (image == null) image = RenderText(sprite.Text.Length > 0 ? sprite.Text : "猪");

            cache[sprite.Id] = image;
            return image;
        }

        private void LoadFrames(string folder, List<Image> left, List<Image> right)
        {
            var dir = Path.Combine(root, folder);
            if (!Directory.Exists(dir)) return;

            var files = new List<string>(Directory.GetFiles(dir, "*.png"));
            files.Sort(StringComparer.OrdinalIgnoreCase);
            foreach (var file in files)
            {
                Image frame;
                using (var stream = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                {
                    frame = Image.FromStream(stream);
                }
                left.Add(frame);

                // Both source GIFs face left; the right-facing set is a mirror
                // generated once at load time.
                var flipped = new Bitmap(frame);
                flipped.RotateFlip(RotateFlipType.RotateNoneFlipX);
                right.Add(flipped);
            }
            Log.Write(string.Format("{0}: {1} frames", folder, left.Count));
        }

        private Image RenderText(string text)
        {
            int size = (int)Math.Round(160 * scale);
            var bitmap = new Bitmap(size, size);
            using (var g = Graphics.FromImage(bitmap))
            {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
                g.Clear(Color.Transparent);

                using (var family = PickFamily())
                using (var font = new Font(family, 34f * scale, FontStyle.Bold, GraphicsUnit.Pixel))
                using (var format = new StringFormat
                {
                    Alignment = StringAlignment.Center,
                    LineAlignment = StringAlignment.Center
                })
                using (var path = new GraphicsPath())
                {
                    var box = new RectangleF(2 * scale, 42 * scale, 156 * scale, 76 * scale);
                    path.AddString(text, family, (int)FontStyle.Bold, 34f * scale, box, format);

                    using (var outline = new Pen(Color.FromArgb(255, 46, 46, 46), 6f * scale))
                    using (var fill = new SolidBrush(Color.FromArgb(255, 255, 105, 140)))
                    {
                        outline.LineJoin = LineJoin.Round;
                        g.DrawPath(outline, path);
                        g.FillPath(fill, path);
                    }
                }
            }
            return bitmap;
        }

        public static FontFamily PickFamily()
        {
            foreach (var name in new[] { "Microsoft YaHei UI", "Microsoft YaHei", "SimHei", "Segoe UI" })
            {
                foreach (var family in FontFamily.Families)
                {
                    if (string.Equals(family.Name, name, StringComparison.OrdinalIgnoreCase))
                    {
                        return family;
                    }
                }
            }
            return FontFamily.GenericSansSerif;
        }
    }
}
