using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using PiggyPet;

namespace PiggyPet.LogicTests
{
    /// <summary>
    /// Native checks for the Windows port's pure maths. These run on the build
    /// machine (macOS here) because they never touch Win32 - which means the
    /// stroll rules can be verified even though the UI itself needs Windows.
    /// </summary>
    internal static class Program
    {
        private static int failures;

        private static int Main()
        {
            Log.Enabled = false;
            string root = FindRepoRoot();
            Console.WriteLine("repo: " + root);
            Console.WriteLine();

            TestManifest(root);
            TestRoundCorners();
            TestWalkPath();
            TestPlanner();

            Console.WriteLine();
            if (failures == 0)
            {
                Console.WriteLine("ALL CHECKS PASSED");
                return 0;
            }
            Console.WriteLine(failures + " CHECK(S) FAILED");
            return 1;
        }

        private static void TestManifest(string root)
        {
            Console.WriteLine("-- manifest --");
            var manifest = Manifest.Load(Path.Combine(root, "Resources", "manifest.json"));
            Check(manifest.Sprites.Count == 35, "35 sprites in the pool", manifest.Sprites.Count.ToString());

            int images = 0, texts = 0, missing = 0;
            foreach (var sprite in manifest.Sprites)
            {
                if (sprite.IsImage)
                {
                    images++;
                    var path = Path.Combine(root, "Resources", sprite.File.Replace('/', Path.DirectorySeparatorChar));
                    if (!File.Exists(path))
                    {
                        missing++;
                        Console.WriteLine("   missing file: " + sprite.File);
                    }
                }
                else
                {
                    texts++;
                    if (sprite.Text.Length == 0) Console.WriteLine("   text sprite without text: " + sprite.Id);
                }
            }
            Check(images == 30, "30 image sprites", images.ToString());
            Check(texts == 5, "5 text sprites", texts.ToString());
            Check(missing == 0, "every image file exists", missing + " missing");
            Check(manifest.Sleep != null && manifest.Sleep.Id == manifest.SleepId, "sleep sprite resolves");
            Check(manifest.Chase != null, "chase sprite resolves");

            var random = new Random(1);
            string current = manifest.Sprites[0].Id;
            bool repeated = false;
            for (int i = 0; i < 500; i++)
            {
                var pick = manifest.RandomExcept(current, random);
                if (pick == null || pick.Id == current) { repeated = true; break; }
                current = pick.Id;
            }
            Check(!repeated, "random face never repeats the current one");

            var walk = Directory.GetFiles(Path.Combine(root, "Resources", "walk"), "*.png").Length;
            var run = Directory.GetFiles(Path.Combine(root, "Resources", "run"), "*.png").Length;
            Check(walk == 19, "19 walk frames", walk.ToString());
            Check(run == 20, "20 run frames", run.ToString());
        }

        private static void TestRoundCorners()
        {
            Console.WriteLine("-- round corners --");
            var square = new List<PointF>
            {
                new PointF(0, 0), new PointF(100, 0), new PointF(100, 100)
            };
            var rounded = Geometry.RoundCorners(square, 20f);
            Check(rounded.Count > square.Count, "corner is replaced by a curve", rounded.Count.ToString());
            Check(Same(rounded[0], square[0]), "first point kept");
            Check(Same(rounded[rounded.Count - 1], square[2]), "last point kept");
            bool finite = true;
            foreach (var point in rounded)
            {
                if (float.IsNaN(point.X) || float.IsNaN(point.Y)) finite = false;
            }
            Check(finite, "no NaN in the fillet");
        }

        private static void TestWalkPath()
        {
            Console.WriteLine("-- walk path --");
            var path = new WalkPath(new PointF(0, 0), new[]
            {
                new PointF(100, 0), new PointF(100, 100)
            });
            Check(Math.Abs(path.Total - 200f) < 0.01f, "total arc length is 200", path.Total.ToString("0.00"));
            Check(Same(path.PositionAt(0), new PointF(0, 0)), "distance 0 is the start");
            Check(Same(path.PositionAt(50), new PointF(50, 0)), "distance 50 is halfway along leg one");
            Check(Same(path.PositionAt(150), new PointF(100, 50)), "distance 150 is halfway along leg two");
            Check(Same(path.PositionAt(999), new PointF(100, 100)), "past the end clamps to the end");
        }

        private static void TestPlanner()
        {
            Console.WriteLine("-- stroll planner --");
            var work = new RectangleF(0, 0, 1440, 860);
            var size = new SizeF(200, 240);
            var random = new Random(20261122);

            float maxSlope = 0, maxTurn = 0, minHorizontal = float.MaxValue;
            float minEndpointDistance = float.MaxValue;
            int verticalLegs = 0, outOfBounds = 0, plans = 400;
            int minPoints = int.MaxValue, maxPoints = 0;

            for (int i = 0; i < plans; i++)
            {
                var home = new PointF(
                    StrollPlanner.RandomRange(random, 60, work.Right - 280),
                    StrollPlanner.RandomRange(random, work.Top + 120, work.Bottom - 300));

                var points = StrollPlanner.Plan(home, size, work, random);
                if (points.Count == 0) { outOfBounds++; continue; }
                minPoints = Math.Min(minPoints, points.Count);
                maxPoints = Math.Max(maxPoints, points.Count);

                var all = new List<PointF> { home };
                all.AddRange(points);

                float horizontal = 0;
                var headings = new List<float>();
                for (int index = 1; index < all.Count; index++)
                {
                    var a = all[index - 1];
                    var b = all[index];
                    float dx = b.X - a.X;
                    float dy = b.Y - a.Y;
                    float length = Geometry.Hypot(dx, dy);
                    if (length < 0.3f) continue;
                    horizontal += Math.Abs(dx);

                    if (Math.Abs(dx) < 0.5f && Math.Abs(dy) > 1f) verticalLegs++;
                    float slope = Math.Abs(dy) / Math.Max(Math.Abs(dx), 0.001f);
                    if (slope > maxSlope) maxSlope = slope;
                    headings.Add((float)Math.Atan2(dy, dx));
                }

                for (int index = 1; index < headings.Count; index++)
                {
                    float turn = Math.Abs(Normalize(headings[index] - headings[index - 1]));
                    if (turn > maxTurn) maxTurn = turn;
                }

                var end = points[points.Count - 1];
                float travelled = Geometry.Hypot(end.X - home.X, end.Y - home.Y);
                if (travelled < minEndpointDistance) minEndpointDistance = travelled;

                // The pig itself must stay on screen: x 20..180, y 64..224.
                foreach (var point in points)
                {
                    if (point.X < work.Left - 20.5f || point.X > work.Right - 180f + 0.5f ||
                        point.Y < work.Top - 64.5f || point.Y > work.Bottom - 224f + 0.5f)
                    {
                        outOfBounds++;
                        break;
                    }
                }

                if (horizontal < minHorizontal) minHorizontal = horizontal;
            }

            Console.WriteLine(string.Format(
                "   plans={0} points={1}..{2} maxSlope={3:0.00} maxTurn={4:0.0}° minHorizontal={5:0} minEndpoint={6:0}",
                plans, minPoints, maxPoints, maxSlope, maxTurn * 180 / Math.PI, minHorizontal, minEndpointDistance));

            Check(outOfBounds == 0, "every route keeps the sprite on screen", outOfBounds + " violations");
            Check(verticalLegs == 0, "no vertical legs", verticalLegs + " found");
            Check(maxSlope <= (float)Math.Tan(33 * Math.PI / 180) + 0.02f, "legs stay within ±33°",
                (maxSlope * 180 / Math.PI).ToString("0.0") + "° worst");
            Check(maxTurn <= 25 * Math.PI / 180, "no sharp turns between samples",
                (maxTurn * 180 / Math.PI).ToString("0.0") + "° worst");
            Check(minHorizontal >= 150, "every trip actually travels sideways", minHorizontal.ToString("0"));
            Check(minEndpointDistance >= 60, "every trip ends somewhere new", minEndpointDistance.ToString("0"));

            // Starting near the right wall must push the whole trip leftwards.
            var edgeHome = new PointF(work.Right - 250, 400);
            bool allLeft = true;
            for (int i = 0; i < 60; i++)
            {
                var points = StrollPlanner.Plan(edgeHome, size, work, random);
                float previousX = edgeHome.X;
                foreach (var point in points)
                {
                    if (point.X > previousX + 1f) allLeft = false;
                    previousX = point.X;
                }
            }
            Check(allLeft, "near the right edge it walks left, never into the wall");

            // Tiny screen: still a usable route, nothing escapes the area.
            var tiny = new RectangleF(0, 0, 420, 320);
            bool tinyOk = true;
            for (int i = 0; i < 60; i++)
            {
                var points = StrollPlanner.Plan(new PointF(100, 120), size, tiny, random);
                if (points.Count == 0) { tinyOk = false; break; }
                foreach (var point in points)
                {
                    if (point.X < tiny.Left - 20.5f || point.X > tiny.Right - 180f + 0.5f) tinyOk = false;
                }
            }
            Check(tinyOk, "a 420x320 screen still gets a valid stroll");
        }

        private static float Normalize(float radians)
        {
            while (radians > Math.PI) radians -= (float)(Math.PI * 2);
            while (radians < -Math.PI) radians += (float)(Math.PI * 2);
            return radians;
        }

        private static bool Same(PointF a, PointF b)
        {
            return Math.Abs(a.X - b.X) < 0.01f && Math.Abs(a.Y - b.Y) < 0.01f;
        }

        private static void Check(bool ok, string label, string detail = "")
        {
            if (ok)
            {
                Console.WriteLine("   ok   " + label + (detail.Length > 0 ? "  (" + detail + ")" : ""));
                return;
            }
            failures++;
            Console.WriteLine("   FAIL " + label + (detail.Length > 0 ? "  (" + detail + ")" : ""));
        }

        private static string FindRepoRoot()
        {
            var dir = new DirectoryInfo(AppContext.BaseDirectory);
            while (dir != null && !File.Exists(Path.Combine(dir.FullName, "Resources", "manifest.json")))
            {
                dir = dir.Parent;
            }
            return dir == null ? Directory.GetCurrentDirectory() : dir.FullName;
        }
    }
}
