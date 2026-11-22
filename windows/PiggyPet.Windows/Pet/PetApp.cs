using System;
using System.Collections.Generic;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace PiggyPet
{
    /// <summary>
    /// The pet's behaviour: sleep, tap to change face, drag to move, generated
    /// strolls, and the occasional cursor nudge. Ported from the macOS state
    /// machine, keeping the same timings and rules.
    /// </summary>
    internal sealed class PetApp : ApplicationContext
    {
        private enum State { Sleep, Idle, Switching, Tantrum, Drag, Walking }

        private sealed class WalkSession
        {
            public WalkPath Path;
            public float Speed;
            public DateTime Started;
            public Action Done;
            public WalkStyle Style;
            public float FrameInterval;
            public float FrameAccumulator;
            public bool FacingRight;
            public int Token;
        }

        private const float StrollBaseSpeed = 80f;
        private const float ChaseSpeed = 170f;
        private const float BaseFrameInterval = 0.06f;

        private readonly Assets assets;
        private readonly Settings settings;
        private readonly PetWindow window;
        private readonly Random random = new Random();
        private readonly float scale;

        private State state = State.Sleep;
        private int interactionToken;

        private Timer awakeTimer;
        private Timer strollTimer;
        private Timer tantrumTimer;
        private Timer zzzTimer;
        private Timer flashTimer;
        private Timer walkTimer;
        private int zzzPhase;
        private WalkSession session;

        public PetApp(Assets assets, Settings settings, float scale)
        {
            this.assets = assets;
            this.settings = settings;
            this.scale = scale;

            var work = Screen.PrimaryScreen.WorkingArea;
            PointF origin;
            if (settings.HasOrigin)
            {
                origin = new PointF(settings.OriginX, settings.OriginY);
            }
            else
            {
                origin = BottomLeftOrigin(work);
            }
            origin = Geometry.ClampWindowOrigin(origin, new SizeF(200 * scale, 240 * scale), PetWindow.ScreenAreas());

            window = new PetWindow(assets, scale, origin);
            window.DragBegan += BeginDrag;
            window.DragEnded += EndDrag;
            window.MenuRequested += point => new PetMenu(this).Show(point);
            window.FormClosed += (s, e) => ExitThread();
        }

        // MARK: - Lifecycle

        public void Start()
        {
            window.Show();
            EnterSleep();
            RescheduleTantrum();
            RescheduleStroll();

            Log.Write(string.Format(
                "start scale={0:0.##} origin=({1:0},{2:0}) sprites={3} walk={4}",
                scale, window.Position.X, window.Position.Y,
                assets.Manifest.Sprites.Count, assets.WalkAvailable));

            // Fresh install: nothing hints that the pig has a menu.
            if (!settings.HasOrigin && !settings.HintShown)
            {
                settings.HintShown = true;
                Persist();
                FlashBubble("点我换表情，右键设置");
            }

            // Register once. A manual choice from the menu is final because the
            // flag is then set and this block never runs again.
            if (!settings.LoginItemAsked)
            {
                if (LoginItem.SetEnabled(true))
                {
                    settings.LoginItemAsked = true;
                    Persist();
                    Log.Write("login item bootstrap=enabled");
                }
                else
                {
                    Log.Write("login item bootstrap=failed");
                    FlashBubble("开机自启没设上，稍后可在菜单里再试");
                }
            }
        }

        public Settings Settings { get { return settings; } }
        public Assets Assets { get { return assets; } }
        public PetWindow Window { get { return window; } }

        // MARK: - Interaction

        public void HandleTap()
        {
            interactionToken++;
            StopWalk(true);
            var sprite = assets.Manifest.RandomExcept(window.CurrentSprite == null ? null : window.CurrentSprite.Id, random);
            window.ShowSprite(sprite);
            window.SetBubble(settings.BubbleEnabled ? sprite.Bubble : null);
            window.SetZzz(0f);
            state = State.Switching;
            ScheduleAwake(RandomRange(10f, 15f));
        }

        private void BeginDrag()
        {
            interactionToken++;
            StopTimers();
            StopWalk(true);
            window.SetZzz(0f);
            window.SetBubble(null);
            state = State.Drag;
        }

        private void EndDrag(bool wasTap)
        {
            if (wasTap)
            {
                HandleTap();
            }
            else
            {
                settings.HasOrigin = true;
                settings.OriginX = window.Position.X;
                settings.OriginY = window.Position.Y;
                Persist();
                EnterIdle();
            }
            RescheduleTantrum();
            RescheduleStroll();
        }

        public void ClearBubble()
        {
            window.SetBubble(null);
        }

        /// <summary>Short-lived bubble used for menu feedback.</summary>
        public void FlashBubble(string text)
        {
            if (flashTimer != null) { flashTimer.Stop(); flashTimer.Dispose(); }
            window.SetBubble(text);
            flashTimer = OneShot(3500, () => window.SetBubble(null));
        }

        // MARK: - Automatic activity

        private void PerformAutomaticActivity()
        {
            bool chase = random.NextDouble() < ChaseProbability(settings.NudgeFrequency);
            Log.Write(string.Format("autoActivity={0} freq={1} p={2:0.00}",
                chase ? "chase" : "stroll",
                settings.NudgeFrequency.ToString().ToLowerInvariant(),
                ChaseProbability(settings.NudgeFrequency)));

            if (chase)
            {
                StartChase(false);
            }
            else
            {
                StartStroll();
                RescheduleTantrum();
            }
        }

        private static double ChaseProbability(NudgeFrequency frequency)
        {
            switch (frequency)
            {
                case NudgeFrequency.Never: return 0;
                case NudgeFrequency.Often: return 0.6;
                default: return 0.2;
            }
        }

        private static float PaceSpeed(WalkPace pace)
        {
            switch (pace)
            {
                case WalkPace.Slow: return 48f;
                case WalkPace.Fast: return 120f;
                default: return StrollBaseSpeed;
            }
        }

        public void StartStroll()
        {
            if (!assets.WalkAvailable) return;
            StopTimers();

            var home = window.Position;
            var work = Screen.FromPoint(Point.Round(window.BodyCenter)).WorkingArea;
            var waypoints = StrollPlanner.Plan(home, window.WindowSize, work, random);
            state = State.Walking;

            int token = interactionToken;
            WalkWaypoints(waypoints, PaceSpeed(settings.WalkPace) * scale, WalkStyle.Trot, () =>
            {
                if (interactionToken != token) return;
                settings.HasOrigin = true;
                settings.OriginX = window.Position.X;
                settings.OriginY = window.Position.Y;
                Persist();
                EnterSleep();
                RescheduleStroll();
            });
        }

        public void StartChase(bool force)
        {
            if (!assets.WalkAvailable)
            {
                RescheduleTantrum();
                return;
            }
            StopTimers();

            var home = window.Position;
            var cursor = Cursor.Position;
            var goal = new PointF(
                cursor.X - 100f * scale + 26f * scale,
                cursor.Y - 144f * scale - 4f * scale);
            goal = Geometry.ClampWindowOrigin(goal, window.WindowSize, PetWindow.ScreenAreas());

            state = State.Walking;
            int token = interactionToken;
            WalkWaypoints(new[] { goal }, ChaseSpeed * scale, WalkStyle.Dash, () =>
            {
                if (interactionToken != token) return;
                EnterTantrum(force);
                OneShot(1600, () =>
                {
                    if (interactionToken != token) return;
                    WalkHome(home);
                });
            });
        }

        private void WalkHome(PointF home)
        {
            if (!assets.WalkAvailable)
            {
                EnterSleep();
                RescheduleTantrum();
                RescheduleStroll();
                return;
            }
            state = State.Walking;
            int token = interactionToken;
            WalkWaypoints(new[] { home }, ChaseSpeed * scale, WalkStyle.Dash, () =>
            {
                if (interactionToken != token) return;
                EnterSleep();
                RescheduleTantrum();
                RescheduleStroll();
            });
        }

        private void EnterTantrum(bool force)
        {
            state = State.Tantrum;
            StopZzz();
            window.SetZzz(0f);
            window.ShowSprite(assets.Chase);
            window.SetBubble(settings.BubbleEnabled ? "别跑！" : null);
            window.Shake();
            NudgeRepeatedly(force);
        }

        public void CancelTantrum()
        {
            if (tantrumTimer != null) { tantrumTimer.Stop(); tantrumTimer.Dispose(); tantrumTimer = null; }
            if (state == State.Tantrum || state == State.Walking)
            {
                StopWalk(true);
                EnterIdle();
            }
        }

        // MARK: - Walking

        private void WalkWaypoints(IList<PointF> points, float speed, WalkStyle style, Action done)
        {
            StopWalk(false);
            var path = new WalkPath(window.Position, points);
            if (path.Total <= 1f)
            {
                if (done != null) done();
                return;
            }

            float actualSpeed = Math.Max(speed, 1f);
            var newSession = new WalkSession
            {
                Path = path,
                Speed = actualSpeed,
                Started = DateTime.UtcNow,
                Done = done,
                Style = style,
                FrameInterval = Math.Min(0.14f, Math.Max(0.035f, BaseFrameInterval * 110f / actualSpeed)),
                FacingRight = path.PositionAt(Math.Min(26f * scale, path.Total)).X - window.Position.X >= 0,
                Token = interactionToken
            };

            window.StartWalking(newSession.FacingRight, style);
            session = newSession;
            state = State.Walking;

            Log.Write(string.Format("walk style={0} speed={1:0}pt/s pts={2} len={3:0} interval={4:0}ms",
                style.ToString().ToLowerInvariant(), actualSpeed, path.VertexCount,
                path.Total, newSession.FrameInterval * 1000));

            walkTimer = new Timer { Interval = 16 };
            walkTimer.Tick += TickWalk;
            walkTimer.Start();
        }

        private void TickWalk(object sender, EventArgs e)
        {
            var active = session;
            if (active == null) return;

            float elapsed = (float)(DateTime.UtcNow - active.Started).TotalSeconds;
            float travelled = Math.Min(active.Path.Total, elapsed * active.Speed);
            var point = active.Path.PositionAt(travelled);
            window.MoveTo(Geometry.ClampWindowOrigin(point, window.WindowSize, PetWindow.ScreenAreas()));

            // Face where the path goes a little later, and only turn once the
            // horizontal component is decisive - no per-sample flicker.
            var ahead = active.Path.PositionAt(Math.Min(active.Path.Total, travelled + 26f * scale));
            float dx = ahead.X - point.X;
            if (Math.Abs(dx) > 6f)
            {
                bool shouldFaceRight = dx > 0f;
                if (shouldFaceRight != active.FacingRight)
                {
                    active.FacingRight = shouldFaceRight;
                    window.StartWalking(shouldFaceRight, active.Style);
                }
            }

            active.FrameAccumulator += 0.016f;
            if (active.FrameAccumulator >= active.FrameInterval)
            {
                active.FrameAccumulator = 0f;
                window.AdvanceWalkFrame();
            }

            if (travelled >= active.Path.Total)
            {
                var finished = active.Done;
                StopWalk(true);
                if (finished != null) finished();
            }
        }

        private void StopWalk(bool resetAnimation)
        {
            if (walkTimer != null)
            {
                walkTimer.Stop();
                walkTimer.Dispose();
                walkTimer = null;
            }
            session = null;
            if (resetAnimation) window.StopWalking();
        }

        // MARK: - Cursor nudge

        private void NudgeRepeatedly(bool force)
        {
            for (int burst = 0; burst < 3; burst++)
            {
                bool capturedForce = force;
                OneShot(450 * burst, () => StartNudge(capturedForce));
            }
        }

        private void StartNudge(bool force)
        {
            if (!force && !settings.TantrumEnabled) return;
            if (state != State.Tantrum) return;

            var cursor = Cursor.Position;
            var body = window.BodyCenter;
            float dx = cursor.X - body.X;
            float dy = cursor.Y - body.Y;
            float length = Math.Max(Geometry.Hypot(dx, dy), 1f);
            float unitX = dx / length;
            float unitY = dy / length;

            // Short shoves, not a teleport: the cursor should look pushed.
            var steps = new[] { 6f, 10f, 12f, 9f, 5f };
            int index = 0;
            Point? previous = null;

            var timer = new Timer { Interval = 100 };
            timer.Tick += (sender, args) =>
            {
                bool stillWanted = force || settings.TantrumEnabled;
                if (!stillWanted || state != State.Tantrum || index >= steps.Length)
                {
                    timer.Stop();
                    timer.Dispose();
                    return;
                }

                var current = Cursor.Position;
                if (previous.HasValue &&
                    Geometry.Hypot(current.X - previous.Value.X, current.Y - previous.Value.Y) > 24f * scale)
                {
                    // The user moved the mouse deliberately - don't fight them.
                    timer.Stop();
                    timer.Dispose();
                    return;
                }

                float step = steps[index] * scale;
                var target = new Point(
                    (int)Math.Round(current.X + unitX * step),
                    (int)Math.Round(current.Y + unitY * step));
                target = ClampToVirtualScreen(target);
                if (SetCursorPos(target.X, target.Y))
                {
                    previous = target;
                    Log.Write("nudge step " + index + " -> " + target.X + "," + target.Y);
                }
                index++;
            };
            timer.Start();
        }

        private static Point ClampToVirtualScreen(Point point)
        {
            var bounds = SystemInformation.VirtualScreen;
            return new Point(
                Math.Min(Math.Max(point.X, bounds.Left + 4), bounds.Right - 4),
                Math.Min(Math.Max(point.Y, bounds.Top + 4), bounds.Bottom - 4));
        }

        [DllImport("user32.dll")]
        private static extern bool SetCursorPos(int x, int y);

        // MARK: - States and schedules

        public void EnterSleep()
        {
            state = State.Sleep;
            StopWalk(true);
            window.ShowSprite(assets.Sleep);
            window.SetBubble(null);
            StartZzzPulse();
        }

        private void EnterIdle()
        {
            state = State.Idle;
            StopZzz();
            window.SetZzz(0f);
            window.SetBubble(null);
            ScheduleAwake(RandomRange(2f, 3f));
        }

        private void StartZzzPulse()
        {
            StopZzz();
            zzzPhase = 0;
            window.SetZzz(1f);
            zzzTimer = new Timer { Interval = 1600 };
            zzzTimer.Tick += (s, e) =>
            {
                zzzPhase = (zzzPhase + 1) % 2;
                window.SetZzz(zzzPhase == 0 ? 1f : 0.45f);
            };
            zzzTimer.Start();
        }

        private void StopZzz()
        {
            if (zzzTimer != null)
            {
                zzzTimer.Stop();
                zzzTimer.Dispose();
                zzzTimer = null;
            }
        }

        public void RescheduleStroll()
        {
            if (strollTimer != null) { strollTimer.Stop(); strollTimer.Dispose(); strollTimer = null; }
            float seconds = StrollInterval(settings.Excitement);
            strollTimer = OneShot((int)(seconds * 1000), () =>
            {
                if (state == State.Sleep || state == State.Idle) StartStroll();
                else RescheduleStroll();
            });
        }

        public void RescheduleTantrum()
        {
            if (tantrumTimer != null) { tantrumTimer.Stop(); tantrumTimer.Dispose(); tantrumTimer = null; }
            if (!settings.TantrumEnabled) return;
            tantrumTimer = OneShot((int)(RandomRange(60f, 180f) * 1000), () =>
            {
                if (state == State.Sleep || state == State.Idle) PerformAutomaticActivity();
                else RescheduleTantrum();
            });
        }

        private void ScheduleAwake(float seconds)
        {
            if (awakeTimer != null) { awakeTimer.Stop(); awakeTimer.Dispose(); awakeTimer = null; }
            awakeTimer = OneShot((int)(seconds * 1000), () =>
            {
                if (state == State.Tantrum || state == State.Switching || state == State.Idle)
                {
                    EnterSleep();
                }
            });
        }

        private void StopTimers()
        {
            if (awakeTimer != null) { awakeTimer.Stop(); awakeTimer.Dispose(); awakeTimer = null; }
            if (tantrumTimer != null) { tantrumTimer.Stop(); tantrumTimer.Dispose(); tantrumTimer = null; }
            if (strollTimer != null) { strollTimer.Stop(); strollTimer.Dispose(); strollTimer = null; }
            StopZzz();
        }

        private float StrollInterval(Excitement excitement)
        {
            switch (excitement)
            {
                case Excitement.Low: return RandomRange(180f, 300f);
                case Excitement.High: return RandomRange(12f, 30f);
                default: return RandomRange(45f, 90f);
            }
        }

        private float RandomRange(float min, float max)
        {
            return min + (float)random.NextDouble() * (max - min);
        }

        private static Timer OneShot(int milliseconds, Action action)
        {
            var timer = new Timer { Interval = Math.Max(1, milliseconds) };
            timer.Tick += (sender, args) =>
            {
                timer.Stop();
                timer.Dispose();
                action();
            };
            timer.Start();
            return timer;
        }

        // MARK: - Menu actions

        public void ResetPosition()
        {
            var work = Screen.PrimaryScreen.WorkingArea;
            window.MoveTo(BottomLeftOrigin(work));
            settings.HasOrigin = true;
            settings.OriginX = window.Position.X;
            settings.OriginY = window.Position.Y;
            Persist();
        }

        private PointF BottomLeftOrigin(Rectangle work)
        {
            return new PointF(
                work.Left + 8f * scale,
                work.Bottom - 240f * scale - 8f * scale);
        }

        public void ToggleTantrum()
        {
            settings.TantrumEnabled = !settings.TantrumEnabled;
            Persist();
            if (!settings.TantrumEnabled) CancelTantrum();
            else RescheduleTantrum();
        }

        public void SetExcitement(Excitement excitement)
        {
            settings.Excitement = excitement;
            Persist();
            RescheduleStroll();
        }

        public void SetNudgeFrequency(NudgeFrequency frequency)
        {
            settings.NudgeFrequency = frequency;
            Persist();
        }

        public void SetWalkPace(WalkPace pace)
        {
            settings.WalkPace = pace;
            Persist();
        }

        public void ToggleBubbles()
        {
            settings.BubbleEnabled = !settings.BubbleEnabled;
            Persist();
            if (!settings.BubbleEnabled) window.SetBubble(null);
        }

        public void ToggleLoginItem()
        {
            bool turnOn = !LoginItem.IsEnabled;
            bool enabled = LoginItem.SetEnabled(turnOn);
            settings.LoginItemAsked = true;
            Persist();
            if (turnOn && !enabled) FlashBubble("开机自启没设上，稍后再试");
        }

        public void Quit()
        {
            StopTimers();
            StopWalk(false);
            window.Close();
        }

        private void Persist()
        {
            settings.Save();
        }
    }
}
