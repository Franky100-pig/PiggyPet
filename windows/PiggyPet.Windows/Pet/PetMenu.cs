using System;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace PiggyPet
{
    /// <summary>
    /// The right-click menu, mirroring the macOS one item for item. Rebuilt on
    /// every open so every check mark reflects the current setting.
    /// </summary>
    internal sealed class PetMenu
    {
        private readonly PetApp app;

        public PetMenu(PetApp app)
        {
            this.app = app;
        }

        public void Show(Point screenPoint)
        {
            var menu = Build();
            menu.Show(screenPoint);

            // The pet panel is always-on-top; without this the menu can open
            // underneath it.
            SetWindowPos(menu.Handle, HWND_TOPMOST, 0, 0, 0, 0,
                SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
        }

        private ContextMenuStrip Build()
        {
            var menu = new ContextMenuStrip
            {
                ShowImageMargin = false,
                ShowCheckMargin = true
            };

            menu.Items.Add(Item("换个表情", app.HandleTap));
            menu.Items.Add(Item("到处逛逛", app.StartStroll));
            menu.Items.Add(Item("追着鼠标", () => app.StartChase(true)));
            menu.Items.Add(new ToolStripSeparator());

            var tantrum = new ToolStripMenuItem("调皮模式") { Checked = app.Settings.TantrumEnabled };
            tantrum.Click += (s, e) => app.ToggleTantrum();
            menu.Items.Add(tantrum);

            var nudge = new ToolStripMenuItem("拱鼠标频率");
            foreach (NudgeFrequency frequency in Enum.GetValues(typeof(NudgeFrequency)))
            {
                var value = frequency;
                var item = new ToolStripMenuItem(Title(value))
                {
                    Checked = app.Settings.NudgeFrequency == value
                };
                item.Click += (s, e) => app.SetNudgeFrequency(value);
                nudge.DropDownItems.Add(item);
            }
            menu.Items.Add(nudge);

            var bubbles = new ToolStripMenuItem("气泡文字") { Checked = app.Settings.BubbleEnabled };
            bubbles.Click += (s, e) => app.ToggleBubbles();
            menu.Items.Add(bubbles);

            var excitement = new ToolStripMenuItem("兴奋程度");
            foreach (Excitement level in Enum.GetValues(typeof(Excitement)))
            {
                var value = level;
                var item = new ToolStripMenuItem(Title(value))
                {
                    Checked = app.Settings.Excitement == value
                };
                item.Click += (s, e) => app.SetExcitement(value);
                excitement.DropDownItems.Add(item);
            }
            menu.Items.Add(excitement);

            var pace = new ToolStripMenuItem("走路速度");
            foreach (WalkPace speed in Enum.GetValues(typeof(WalkPace)))
            {
                var value = speed;
                var item = new ToolStripMenuItem(Title(value))
                {
                    Checked = app.Settings.WalkPace == value
                };
                item.Click += (s, e) => app.SetWalkPace(value);
                pace.DropDownItems.Add(item);
            }
            menu.Items.Add(pace);

            var login = new ToolStripMenuItem("开机自启") { Checked = LoginItem.IsEnabled };
            login.Click += (s, e) => app.ToggleLoginItem();
            menu.Items.Add(login);

            menu.Items.Add(Item("回到左下角", app.ResetPosition));
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add(Item("关于 PiggyPet", ShowAbout));
            menu.Items.Add(Item("退出 PiggyPet", app.Quit));

            return menu;
        }

        private static ToolStripMenuItem Item(string text, Action action)
        {
            var item = new ToolStripMenuItem(text);
            item.Click += (s, e) => action();
            return item;
        }

        private static string Title(Excitement value)
        {
            switch (value)
            {
                case Excitement.Low: return "低";
                case Excitement.High: return "高";
                default: return "中";
            }
        }

        private static string Title(NudgeFrequency value)
        {
            switch (value)
            {
                case NudgeFrequency.Never: return "从不";
                case NudgeFrequency.Often: return "经常";
                default: return "偶尔";
            }
        }

        private static string Title(WalkPace value)
        {
            switch (value)
            {
                case WalkPace.Slow: return "慢悠悠";
                case WalkPace.Fast: return "利索";
                default: return "正常";
            }
        }

        private static void ShowAbout()
        {
            var version = typeof(PetMenu).Assembly.GetName().Version;
            var text = string.Format(
                "PiggyPet {0}.{1}.{2}\r\n\r\n" +
                "一只住在桌面上的小猪。左键换表情，拖拽搬家，右键打开菜单。\r\n" +
                "开机自启可以在菜单里随时关掉。\r\n\r\n" +
                "github.com/Franky100-pig/PiggyPet",
                version.Major, version.Minor, version.Build);

            using (var form = new Form())
            {
                form.Text = "关于 PiggyPet";
                form.FormBorderStyle = FormBorderStyle.FixedDialog;
                form.StartPosition = FormStartPosition.CenterScreen;
                form.MaximizeBox = false;
                form.MinimizeBox = false;
                form.ShowInTaskbar = false;
                form.TopMost = true;
                form.ClientSize = new Size(420, 210);
                form.BackColor = Color.White;

                var label = new Label
                {
                    Text = text,
                    AutoSize = false,
                    Bounds = new Rectangle(18, 16, 384, 120),
                    Font = new Font(Assets.PickFamily(), 9.5f)
                };
                form.Controls.Add(label);

                var home = new Button
                {
                    Text = "打开项目主页",
                    Bounds = new Rectangle(18, 152, 130, 32)
                };
                home.Click += (s, e) => Process.Start("https://github.com/Franky100-pig/PiggyPet");
                form.Controls.Add(home);

                var ok = new Button
                {
                    Text = "好",
                    Bounds = new Rectangle(320, 152, 82, 32),
                    DialogResult = DialogResult.OK
                };
                form.Controls.Add(ok);
                form.AcceptButton = ok;
                form.CancelButton = ok;
                form.ShowDialog();
            }
        }

        private const int HWND_TOPMOST = -1;
        private const int SWP_NOMOVE = 0x0002;
        private const int SWP_NOSIZE = 0x0001;
        private const int SWP_NOACTIVATE = 0x0010;

        [DllImport("user32.dll")]
        private static extern bool SetWindowPos(
            IntPtr hWnd, int hWndInsertAfter, int x, int y, int cx, int cy, int flags);
    }
}
