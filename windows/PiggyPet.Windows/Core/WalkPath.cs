using System;
using System.Collections.Generic;
using System.Drawing;

namespace PiggyPet
{
    /// <summary>
    /// A polyline with cumulative arc lengths, evaluated by distance. Keeping
    /// this a plain class means the walk timer never has to touch the window
    /// while it interpolates.
    /// </summary>
    internal sealed class WalkPath
    {
        private readonly List<PointF> vertices = new List<PointF>();
        private readonly List<float> cumulative = new List<float>();

        public float Total { get { return cumulative.Count == 0 ? 0f : cumulative[cumulative.Count - 1]; } }
        public int VertexCount { get { return vertices.Count; } }

        public WalkPath(PointF start, IEnumerable<PointF> points)
        {
            vertices.Add(start);
            foreach (var point in points)
            {
                var last = vertices[vertices.Count - 1];
                if (Geometry.Hypot(point.X - last.X, point.Y - last.Y) > 0.5f)
                {
                    vertices.Add(point);
                }
            }

            cumulative.Add(0f);
            for (int i = 1; i < vertices.Count; i++)
            {
                var a = vertices[i - 1];
                var b = vertices[i];
                cumulative.Add(cumulative[i - 1] + Geometry.Hypot(b.X - a.X, b.Y - a.Y));
            }
        }

        public PointF PositionAt(float distance)
        {
            if (vertices.Count == 0) return PointF.Empty;
            if (vertices.Count == 1) return vertices[0];

            float clamped = Math.Min(Math.Max(distance, 0f), Total);
            int index = 1;
            while (index < cumulative.Count - 1 && cumulative[index] < clamped) index++;

            float span = cumulative[index] - cumulative[index - 1];
            float t = span > 0.0001f ? (clamped - cumulative[index - 1]) / span : 0f;
            var a = vertices[index - 1];
            var b = vertices[index];
            return new PointF(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t);
        }
    }
}
