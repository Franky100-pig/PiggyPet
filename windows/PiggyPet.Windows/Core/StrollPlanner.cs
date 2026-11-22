using System;
using System.Collections.Generic;
using System.Drawing;

namespace PiggyPet
{
    /// <summary>
    /// Builds a random outing leg by leg, the same way the macOS build does.
    ///
    /// Constraint by construction, not by clamping: a leg's heading is held
    /// within ±33° of horizontal, so nothing ever reads as a vertical lift, and
    /// the heading drifts a little each leg (turning away from the screen edges)
    /// so the route waves instead of running along a ruler line. The whole trip
    /// keeps one travel direction, which rules out hairpin retraces and circles.
    /// </summary>
    internal static class StrollPlanner
    {
        // The sprite sits 20..180 across and 64..224 down inside the 200x240
        // window, so these insets keep the pig itself on screen.
        public const float SpriteLeftInset = 20f;
        public const float SpriteRightInset = 180f;
        public const float SpriteTopInset = 64f;
        public const float SpriteBottomInset = 224f;

        public static List<PointF> Plan(PointF home, SizeF size, RectangleF work, Random rng)
        {
            float minX = work.Left - SpriteLeftInset;
            float maxX = work.Right - SpriteRightInset;
            float minY = work.Top - SpriteTopInset;
            float maxY = work.Bottom - SpriteBottomInset;

            Func<PointF, PointF> fit = p => Geometry.ClampWindowOrigin(p, size, new[] { work });

            int legs = rng.Next(3, 6);
            float roomRight = maxX - home.X;
            float roomLeft = home.X - minX;

            float direction;
            if (roomRight < 320f)
            {
                direction = -1f;
            }
            else if (roomLeft < 320f)
            {
                direction = 1f;
            }
            else
            {
                // Weighted by open space, so it heads across the screen instead
                // of hugging whichever wall it happens to stop near.
                float share = roomRight / (roomRight + roomLeft);
                direction = rng.NextDouble() < Math.Min(Math.Max(share, 0.2f), 0.8f) ? 1f : -1f;
            }

            var current = home;
            var waypoints = new List<PointF>();
            float climbSign = rng.Next(2) == 0 ? 1f : -1f;

            for (int i = 0; i < legs; i++)
            {
                float room = direction > 0 ? maxX - current.X : current.X - minX;
                float length = Math.Min(RandomRange(rng, 150f, 310f), room - 30f);
                if (length <= 90f) break;

                // Flip up/down most of the time, and steer away from the top and
                // bottom of the screen before the pig gets there.
                if (rng.Next(2) == 0) climbSign = -climbSign;
                if (current.Y - work.Top < 80f) climbSign = -1f;
                else if (work.Bottom - current.Y < 80f) climbSign = 1f;

                // Positive climb walks up the screen, i.e. towards a smaller Y.
                float climb = climbSign * RandomRange(rng, 0.12f, 0.58f);
                float nextY = current.Y - length * (float)Math.Tan(climb);
                nextY = Math.Min(Math.Max(nextY, minY), maxY);

                var next = fit(new PointF(current.X + direction * length, nextY));
                waypoints.Add(next);
                current = next;
            }

            if (waypoints.Count == 0)
            {
                // No room for a normal leg (tiny screen, or pinned against a
                // wall). One short hop is still better than a stroll that goes
                // nowhere - but it has to stay inside the sprite-safe band, not
                // just "mostly on screen".
                float targetX = Math.Min(Math.Max(home.X + 160f, minX), maxX);
                if (Math.Abs(targetX - home.X) < 40f)
                {
                    targetX = home.X > (minX + maxX) / 2f ? minX : maxX;
                }
                waypoints.Add(fit(new PointF(targetX, home.Y)));
            }

            float radius = RandomRange(rng, 40f, 85f);
            var withHome = new List<PointF> { home };
            withHome.AddRange(waypoints);
            var rounded = Geometry.RoundCorners(withHome, radius);
            var result = new List<PointF>(rounded.Count);
            // The first entry is `home`, which the walker already starts from.
            for (int i = 1; i < rounded.Count; i++) result.Add(fit(rounded[i]));
            return result;
        }

        public static float RandomRange(Random rng, float min, float max)
        {
            return min + (float)rng.NextDouble() * (max - min);
        }
    }
}
