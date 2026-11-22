using System;
using System.Collections.Generic;
using System.Drawing;

namespace PiggyPet
{
    /// <summary>
    /// Window placement maths shared by the pet window and the stroll planner.
    /// Everything here speaks Windows' top-left coordinate space: Y grows
    /// downwards, so "climbing" means a smaller Y.
    /// </summary>
    internal static class Geometry
    {
        public static float Hypot(float x, float y)
        {
            return (float)Math.Sqrt(x * x + y * y);
        }

        /// <summary>
        /// Keeps at least part of the window on a visible screen. The first
        /// zone that contains the origin wins, otherwise the point is pulled
        /// fully inside the primary work area.
        /// </summary>
        public static PointF ClampWindowOrigin(PointF origin, SizeF size, IList<RectangleF> areas)
        {
            if (areas == null || areas.Count == 0) return origin;

            foreach (var area in areas)
            {
                float minX = area.Left - size.Width + 60f;
                float maxX = area.Right - 60f;
                float minY = area.Top - size.Height + 60f;
                float maxY = area.Bottom - 60f;
                if (origin.X >= minX && origin.X <= maxX &&
                    origin.Y >= minY && origin.Y <= maxY)
                {
                    return origin;
                }
            }

            var first = areas[0];
            return new PointF(
                Math.Min(Math.Max(origin.X, first.Left), first.Right - size.Width),
                Math.Min(Math.Max(origin.Y, first.Top), first.Bottom - size.Height));
        }

        /// <summary>
        /// Replaces every interior corner of a polyline with a quadratic
        /// fillet, so a turn is always a bend rather than a pivot. Tangents
        /// stay continuous with both legs and the cut never eats more than 45%
        /// of a leg, so short hops keep their straight sections.
        /// </summary>
        public static List<PointF> RoundCorners(IList<PointF> points, float radius, int samplesPerCorner = 12)
        {
            var result = new List<PointF>();
            if (points == null || points.Count == 0) return result;
            if (points.Count <= 2)
            {
                result.AddRange(points);
                return result;
            }

            result.Add(points[0]);
            for (int index = 1; index < points.Count - 1; index++)
            {
                PointF previous = points[index - 1];
                PointF corner = points[index];
                PointF next = points[index + 1];

                float inX = corner.X - previous.X;
                float inY = corner.Y - previous.Y;
                float outX = next.X - corner.X;
                float outY = next.Y - corner.Y;
                float inLength = Hypot(inX, inY);
                float outLength = Hypot(outX, outY);
                if (inLength <= 0.5f || outLength <= 0.5f) continue;

                float cut = Math.Min(radius, Math.Min(inLength * 0.45f, outLength * 0.45f));
                var start = new PointF(
                    corner.X - inX / inLength * cut,
                    corner.Y - inY / inLength * cut);
                var end = new PointF(
                    corner.X + outX / outLength * cut,
                    corner.Y + outY / outLength * cut);

                result.Add(start);
                for (int step = 1; step <= samplesPerCorner; step++)
                {
                    float t = (float)step / (samplesPerCorner + 1);
                    float inv = 1f - t;
                    result.Add(new PointF(
                        inv * inv * start.X + 2f * inv * t * corner.X + t * t * end.X,
                        inv * inv * start.Y + 2f * inv * t * corner.Y + t * t * end.Y));
                }
                result.Add(end);
            }
            result.Add(points[points.Count - 1]);
            return result;
        }
    }
}
