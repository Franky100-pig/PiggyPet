using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace PiggyPet
{
    /// <summary>
    /// A borderless, transparent, always-on-top panel that draws the pig with
    /// per-pixel alpha (UpdateLayeredWindow) and lets clicks through wherever
    /// the canvas is transparent, mirroring the AppKit panel on macOS.
    /// </summary>
    internal sealed class PetWindow : Form
    {
        public const int DesignWidth = 200;
        public const int DesignHeight = 240;
        public const int DesignSprite = 160;

        private const int WS_EX_LAYERED = 0x00080000;
        private const int WS_EX_TOOLWINDOW = 0x00000080;
        private const int WS_EX_NOACTIVATE = 0x08000000;
        private const int WM_NCHITTEST = 0x0084;
        private const int WM_LBUTTONDOWN = 0x0201;
        private const int WM_LBUTTONUP = 0x0202;
        private const int WM_MOUSEMOVE = 0x0200;
        private const int WM_RBUTTONUP = 0x0205;
        private const int HTTRANSPARENT = -1;
        private const int HTCLIENT = 1;
        private const int ULW_ALPHA = 0x00000002;
        private const byte AC_SRC_OVER = 0x00;
        private const byte AC_SRC_ALPHA = 0x01;

        private readonly Assets assets;
        private readonly float scale;
        private readonly int width;
        private readonly int height;
        private readonly Bitmap canvas;
        private readonly Graphics canvasGraphics;

        private PointF position;
        private SpriteInfo current;
        private Image currentImage;
        private string bubbleText;
        private float zzzAlpha = 1f;
        private float shakeOffset;

        private bool walking;
        private IList<Image> frames = new List<Image>();
        private int frameIndex;
        private bool facingRight;
        private WalkStyle walkStyle = WalkStyle.Trot;

        private bool dragging;
        private Point dragStartCursor;
        private PointF dragStartPosition;

        public event Action DragBegan;
        public event Action<bool> DragEnded;
        public event Action<Point> MenuRequested;

        public PetWindow(Assets assets, float scale, PointF origin)
        {
            this.assets = assets;
            this.scale = scale;
            width = (int)Math.Round(DesignWidth * scale);
            height = (int)Math.Round(DesignHeight * scale);
            position = origin;

            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            StartPosition = FormStartPosition.Manual;
            AutoScaleMode = AutoScaleMode.None;
            TopMost = true;
            Bounds = new Rectangle((int)origin.X, (int)origin.Y, width, height);

            canvas = new Bitmap(width, height, PixelFormat.Format32bppArgb);
            canvasGraphics = Graphics.FromImage(canvas);
            canvasGraphics.SmoothingMode = SmoothingMode.AntiAlias;
            canvasGraphics.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;

            ShowSprite(assets.Sleep);
        }

        protected override bool ShowWithoutActivation
        {
            get { return true; }
        }

        protected override CreateParams CreateParams
        {
            get
            {
                var parameters = base.CreateParams;
                parameters.ExStyle |= WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE;
                return parameters;
            }
        }

        public PointF Position { get { return position; } }
        public SizeF WindowSize { get { return new SizeF(width, height); } }
        public SpriteInfo CurrentSprite { get { return current; } }
        public bool IsWalking { get { return walking; } }
        public bool IsDragging { get { return dragging; } }

        /// <summary>Body centre in screen pixels: the snout target when chasing.</summary>
        public PointF BodyCenter
        {
            get { return new PointF(position.X + 100f * scale, position.Y + 144f * scale); }
        }

        public void ShowSprite(SpriteInfo sprite)
        {
            if (sprite == null) return;
            current = sprite;
            currentImage = assets.ImageFor(sprite);
            Render();
        }

        public void SetBubble(string text)
        {
            bubbleText = string.IsNullOrEmpty(text) ? null : text;
            Render();
        }

        public void SetZzz(float alpha)
        {
            zzzAlpha = alpha;
            Render();
        }

        public void Shake()
        {
            var steps = new[]
            {
                new { Delay = -1, Offset = -4f },
                new { Delay = 80, Offset = 4f },
                new { Delay = 160, Offset = -3f },
                new { Delay = 240, Offset = 0f }
            };
            foreach (var step in steps)
            {
                var captured = step.Offset;
                if (step.Delay < 0)
                {
                    // Interval 0 would never tick; apply the first frame now.
                    shakeOffset = captured;
                    Render();
                    continue;
                }
                var timer = new Timer { Interval = step.Delay };
                timer.Tick += (s, e) =>
                {
                    timer.Stop();
                    timer.Dispose();
                    shakeOffset = captured;
                    Render();
                };
                timer.Start();
            }
        }

        // MARK: - Walking animation

        public void StartWalking(bool faceRight, WalkStyle style)
        {
            // A curved path is walked in one pass, but a turn swaps the frame
            // set. Keeping the index across that swap is what stops the legs
            // from restarting at pose 0 every time the pig turns around.
            if (walking && walkStyle == style && frames.Count > 0)
            {
                if (facingRight != faceRight)
                {
                    frames = assets.Frames(style, faceRight);
                    facingRight = faceRight;
                    Render();
                }
                return;
            }

            var set = assets.Frames(style, faceRight);
            if (set == null || set.Count == 0) return;
            frames = set;
            frameIndex = 0;
            facingRight = faceRight;
            walkStyle = style;
            walking = true;
            zzzAlpha = 0f;
            bubbleText = null;
            Render();
        }

        public void AdvanceWalkFrame()
        {
            if (!walking || frames.Count == 0) return;
            frameIndex = (frameIndex + 1) % frames.Count;
            if (frameIndex == 0) Log.Write("walkCycle done frames=" + frames.Count);
            Render();
        }

        public void StopWalking()
        {
            if (!walking) return;
            walking = false;
            frames = new List<Image>();
            frameIndex = 0;
            Render();
        }

        public void MoveTo(PointF target)
        {
            position = target;
            Render();
        }

        public void MoveTo(PointF target, bool render)
        {
            position = target;
            if (render) Render();
        }

        // MARK: - Input

        protected override void WndProc(ref Message message)
        {
            switch (message.Msg)
            {
                case WM_NCHITTEST:
                {
                    long packed = message.LParam.ToInt64();
                    int screenX = (short)(packed & 0xFFFF);
                    int screenY = (short)((packed >> 16) & 0xFFFF);
                    var client = new Point(
                        (int)Math.Round(screenX - position.X),
                        (int)Math.Round(screenY - position.Y));
                    message.Result = (IntPtr)(HitTestCanvas(client) ? HTCLIENT : HTTRANSPARENT);
                    return;
                }
                case WM_LBUTTONDOWN:
                    BeginDrag();
                    return;
                case WM_MOUSEMOVE:
                    if (dragging) UpdateDrag();
                    return;
                case WM_LBUTTONUP:
                    EndDrag();
                    return;
                case WM_RBUTTONUP:
                    if (MenuRequested != null) MenuRequested(Cursor.Position);
                    return;
            }
            base.WndProc(ref message);
        }

        private void BeginDrag()
        {
            dragging = true;
            dragStartCursor = Cursor.Position;
            dragStartPosition = position;
            Capture = true;
            if (DragBegan != null) DragBegan();
        }

        private void UpdateDrag()
        {
            var now = Cursor.Position;
            var target = new PointF(
                dragStartPosition.X + (now.X - dragStartCursor.X),
                dragStartPosition.Y + (now.Y - dragStartCursor.Y));
            MoveTo(Geometry.ClampWindowOrigin(target, WindowSize, ScreenAreas()));
        }

        private void EndDrag()
        {
            if (!dragging) return;
            dragging = false;
            Capture = false;
            var now = Cursor.Position;
            bool wasTap = Geometry.Hypot(now.X - dragStartCursor.X, now.Y - dragStartCursor.Y) <= 10f * scale;
            if (DragEnded != null) DragEnded(wasTap);
        }

        public static IList<RectangleF> ScreenAreas()
        {
            var areas = new List<RectangleF>();
            foreach (var screen in Screen.AllScreens)
            {
                areas.Add(screen.WorkingArea);
            }
            if (areas.Count == 0) areas.Add(SystemInformation.WorkingArea);
            return areas;
        }

        // MARK: - Hit testing

        private RectangleF SpriteRect()
        {
            return new RectangleF(
                20f * scale + shakeOffset * scale,
                64f * scale,
                DesignSprite * scale,
                DesignSprite * scale);
        }

        private RectangleF BubbleRect()
        {
            return new RectangleF(14f * scale, 12f * scale, 172f * scale, 44f * scale);
        }

        private bool HitTestCanvas(Point client)
        {
            if (client.X < 0 || client.Y < 0 || client.X >= width || client.Y >= height) return false;
            if (bubbleText != null && BubbleRect().Contains(client)) return true;

            var rect = SpriteRect();
            if (!rect.Contains(client)) return false;

            // The torso core is always clickable: a few memes have transparent
            // pixels in the middle, and without this the pig would ignore clicks
            // and the menu could not be opened to escape that sprite.
            var core = new RectangleF(
                rect.X + 40f * scale, rect.Y + 40f * scale,
                rect.Width - 80f * scale, rect.Height - 80f * scale);
            if (core.Contains(client)) return true;

            int centerX = (int)Math.Round(client.X - rect.X);
            int centerY = (int)Math.Round(client.Y - rect.Y);
            int step = (int)Math.Round(3f * scale);
            foreach (int dx in new[] { -step, 0, step })
            {
                foreach (int dy in new[] { -step, 0, step })
                {
                    int x = centerX + dx;
                    int y = centerY + dy;
                    if (x < 0 || y < 0 || x >= canvas.Width || y >= canvas.Height) continue;
                    if (canvas.GetPixel(x, y).A > 38) return true;
                }
            }
            return false;
        }

        // MARK: - Drawing

        private void Render()
        {
            var g = canvasGraphics;
            g.Clear(Color.Transparent);

            if (zzzAlpha > 0f && !walking) DrawZzz(g);

            var rect = SpriteRect();
            var image = walking && frameIndex < frames.Count ? frames[frameIndex] : currentImage;
            if (image != null) g.DrawImage(image, rect);

            if (bubbleText != null) DrawBubble(g);

            UpdateLayered();
        }

        private void DrawZzz(Graphics g)
        {
            using (var family = Assets.PickFamily())
            using (var font = new Font(family, 22f * scale, FontStyle.Bold, GraphicsUnit.Pixel))
            using (var brush = new SolidBrush(Color.FromArgb((int)(255 * zzzAlpha), 255, 92, 128)))
            {
                g.DrawString("Zzz", font, brush, 128f * scale, 30f * scale);
            }
        }

        private void DrawBubble(Graphics g)
        {
            var rect = BubbleRect();
            float radius = 12f * scale;
            using (var path = RoundedRect(rect, radius))
            using (var fill = new SolidBrush(Color.FromArgb(246, 252, 252, 252)))
            using (var stroke = new Pen(Color.FromArgb(255, 198, 198, 198), Math.Max(1f, scale)))
            {
                g.FillPath(fill, path);
                g.DrawPath(stroke, path);
            }

            var tail = new[]
            {
                new PointF(rect.X + rect.Width / 2 - 7 * scale, rect.Bottom - 1),
                new PointF(rect.X + rect.Width / 2, rect.Bottom + 9 * scale),
                new PointF(rect.X + rect.Width / 2 + 7 * scale, rect.Bottom - 1)
            };
            using (var fill = new SolidBrush(Color.FromArgb(246, 252, 252, 252)))
            {
                g.FillPolygon(fill, tail);
            }

            var textRect = new RectangleF(
                rect.X + 8 * scale, rect.Y + 6 * scale,
                rect.Width - 16 * scale, rect.Height - 12 * scale);
            using (var family = Assets.PickFamily())
            using (var font = new Font(family, 14f * scale, FontStyle.Regular, GraphicsUnit.Pixel))
            using (var brush = new SolidBrush(Color.FromArgb(255, 32, 32, 32)))
            using (var format = new StringFormat
            {
                Alignment = StringAlignment.Center,
                LineAlignment = StringAlignment.Center
            })
            {
                g.DrawString(bubbleText, font, brush, textRect, format);
            }
        }

        private static GraphicsPath RoundedRect(RectangleF rect, float radius)
        {
            var path = new GraphicsPath();
            float d = Math.Min(radius * 2, Math.Min(rect.Width, rect.Height));
            path.AddArc(rect.X, rect.Y, d, d, 180, 90);
            path.AddArc(rect.Right - d, rect.Y, d, d, 270, 90);
            path.AddArc(rect.Right - d, rect.Bottom - d, d, d, 0, 90);
            path.AddArc(rect.X, rect.Bottom - d, d, d, 90, 90);
            path.CloseFigure();
            return path;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct POINT { public int X; public int Y; }

        [StructLayout(LayoutKind.Sequential)]
        private struct SIZE { public int cx; public int cy; }

        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        private struct BLENDFUNCTION
        {
            public byte BlendOp;
            public byte BlendFlags;
            public byte SourceConstantAlpha;
            public byte AlphaFormat;
        }

        [DllImport("user32.dll")]
        private static extern bool UpdateLayeredWindow(
            IntPtr hwnd, IntPtr hdcDst, ref POINT pptDst, ref SIZE psize,
            IntPtr hdcSrc, ref POINT pptSrc, int crKey, ref BLENDFUNCTION pblend, int flags);

        [DllImport("user32.dll")]
        private static extern IntPtr GetDC(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);

        [DllImport("gdi32.dll")]
        private static extern IntPtr CreateCompatibleDC(IntPtr hdc);

        [DllImport("gdi32.dll")]
        private static extern bool DeleteDC(IntPtr hdc);

        [DllImport("gdi32.dll")]
        private static extern IntPtr SelectObject(IntPtr hdc, IntPtr obj);

        [DllImport("gdi32.dll")]
        private static extern bool DeleteObject(IntPtr obj);

        private void UpdateLayered()
        {
            IntPtr screenDc = GetDC(IntPtr.Zero);
            IntPtr memoryDc = CreateCompatibleDC(screenDc);
            IntPtr bitmap = IntPtr.Zero;
            IntPtr previous = IntPtr.Zero;
            try
            {
                bitmap = canvas.GetHbitmap(Color.FromArgb(0));
                previous = SelectObject(memoryDc, bitmap);

                var destination = new POINT
                {
                    X = (int)Math.Round(position.X),
                    Y = (int)Math.Round(position.Y)
                };
                var size = new SIZE { cx = width, cy = height };
                var source = new POINT { X = 0, Y = 0 };
                var blend = new BLENDFUNCTION
                {
                    BlendOp = AC_SRC_OVER,
                    BlendFlags = 0,
                    SourceConstantAlpha = 255,
                    AlphaFormat = AC_SRC_ALPHA
                };
                UpdateLayeredWindow(
                    Handle, screenDc, ref destination, ref size,
                    memoryDc, ref source, 0, ref blend, ULW_ALPHA);
            }
            finally
            {
                if (previous != IntPtr.Zero) SelectObject(memoryDc, previous);
                if (bitmap != IntPtr.Zero) DeleteObject(bitmap);
                DeleteDC(memoryDc);
                ReleaseDC(IntPtr.Zero, screenDc);
            }
        }
    }
}
