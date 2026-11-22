using System;
using System.Drawing;
using System.Threading;
using System.Windows.Forms;

namespace PiggyPet
{
    internal static class Program
    {
        [STAThread]
        private static void Main(string[] args)
        {
            Log.Enabled = Array.IndexOf(args, "--debug") >= 0 ||
                          Environment.GetEnvironmentVariable("PIGGY_DEBUG") == "1";

            // One pig only: a second copy would fight over the same saved spot.
            bool created;
            using (var mutex = new Mutex(true, @"Local\PiggyPet.SingleInstance", out created))
            {
                if (!created)
                {
                    Log.Write("already running, quitting this copy");
                    return;
                }

                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
                Application.ThreadException += (s, e) => Log.Error("ui: " + e.Exception);
                AppDomain.CurrentDomain.UnhandledException += (s, e) =>
                    Log.Error("fatal: " + e.ExceptionObject);

                float scale;
                using (var screen = Graphics.FromHwnd(IntPtr.Zero))
                {
                    scale = screen.DpiX / 96f;
                }

                var assets = new Assets(AppDomain.CurrentDomain.BaseDirectory, scale);
                var settings = Settings.Load();
                var app = new PetApp(assets, settings, scale);
                app.Start();
                Application.Run(app);
            }
        }
    }
}
