using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace PiggyPet
{
    /// <summary>
    /// A very small JSON reader/writer. The app only ever reads the sprite
    /// manifest and writes a flat settings file, so pulling in a library (and
    /// shipping its DLL next to the exe) would be overkill.
    /// </summary>
    internal static class Json
    {
        public static object Parse(string text)
        {
            int index = 0;
            object value = ParseValue(text, ref index);
            SkipSpace(text, ref index);
            return value;
        }

        public static Dictionary<string, object> AsObject(object value)
        {
            return value as Dictionary<string, object>;
        }

        public static List<object> AsArray(object value)
        {
            return value as List<object>;
        }

        public static string AsString(object value)
        {
            return value as string;
        }

        public static string String(object obj, string key, string fallback = "")
        {
            var dict = AsObject(obj);
            if (dict == null || !dict.ContainsKey(key)) return fallback;
            return AsString(dict[key]) ?? fallback;
        }

        private static object ParseValue(string text, ref int index)
        {
            SkipSpace(text, ref index);
            if (index >= text.Length) throw new FormatException("Unexpected end of JSON");
            char c = text[index];
            switch (c)
            {
                case '{': return ParseObject(text, ref index);
                case '[': return ParseArray(text, ref index);
                case '"': return ParseString(text, ref index);
                case 't': Expect(text, ref index, "true"); return true;
                case 'f': Expect(text, ref index, "false"); return false;
                case 'n': Expect(text, ref index, "null"); return null;
                default: return ParseNumber(text, ref index);
            }
        }

        private static Dictionary<string, object> ParseObject(string text, ref int index)
        {
            var result = new Dictionary<string, object>();
            index++; // {
            SkipSpace(text, ref index);
            if (index < text.Length && text[index] == '}') { index++; return result; }

            while (true)
            {
                SkipSpace(text, ref index);
                string key = ParseString(text, ref index);
                SkipSpace(text, ref index);
                if (index >= text.Length || text[index] != ':') throw new FormatException("Expected ':'");
                index++;
                result[key] = ParseValue(text, ref index);
                SkipSpace(text, ref index);
                if (index >= text.Length) throw new FormatException("Unterminated object");
                if (text[index] == ',') { index++; continue; }
                if (text[index] == '}') { index++; return result; }
                throw new FormatException("Expected ',' or '}'");
            }
        }

        private static List<object> ParseArray(string text, ref int index)
        {
            var result = new List<object>();
            index++; // [
            SkipSpace(text, ref index);
            if (index < text.Length && text[index] == ']') { index++; return result; }

            while (true)
            {
                result.Add(ParseValue(text, ref index));
                SkipSpace(text, ref index);
                if (index >= text.Length) throw new FormatException("Unterminated array");
                if (text[index] == ',') { index++; continue; }
                if (text[index] == ']') { index++; return result; }
                throw new FormatException("Expected ',' or ']'");
            }
        }

        private static string ParseString(string text, ref int index)
        {
            SkipSpace(text, ref index);
            if (index >= text.Length || text[index] != '"') throw new FormatException("Expected string");
            index++;
            var builder = new StringBuilder();
            while (index < text.Length)
            {
                char c = text[index++];
                if (c == '"') return builder.ToString();
                if (c != '\\') { builder.Append(c); continue; }

                if (index >= text.Length) break;
                char escape = text[index++];
                switch (escape)
                {
                    case '"': builder.Append('"'); break;
                    case '\\': builder.Append('\\'); break;
                    case '/': builder.Append('/'); break;
                    case 'b': builder.Append('\b'); break;
                    case 'f': builder.Append('\f'); break;
                    case 'n': builder.Append('\n'); break;
                    case 'r': builder.Append('\r'); break;
                    case 't': builder.Append('\t'); break;
                    case 'u':
                        if (index + 4 > text.Length) throw new FormatException("Bad \\u escape");
                        builder.Append((char)Convert.ToInt32(text.Substring(index, 4), 16));
                        index += 4;
                        break;
                    default: throw new FormatException("Bad escape");
                }
            }
            throw new FormatException("Unterminated string");
        }

        private static double ParseNumber(string text, ref int index)
        {
            int start = index;
            while (index < text.Length && "+-.eE0123456789".IndexOf(text[index]) >= 0) index++;
            return double.Parse(text.Substring(start, index - start), CultureInfo.InvariantCulture);
        }

        private static void Expect(string text, ref int index, string literal)
        {
            if (index + literal.Length > text.Length ||
                string.CompareOrdinal(text, index, literal, 0, literal.Length) != 0)
            {
                throw new FormatException("Expected " + literal);
            }
            index += literal.Length;
        }

        private static void SkipSpace(string text, ref int index)
        {
            while (index < text.Length && char.IsWhiteSpace(text[index])) index++;
        }

        public static string Escape(string value)
        {
            var builder = new StringBuilder();
            foreach (char c in value ?? "")
            {
                switch (c)
                {
                    case '"': builder.Append("\\\""); break;
                    case '\\': builder.Append("\\\\"); break;
                    case '\n': builder.Append("\\n"); break;
                    case '\r': builder.Append("\\r"); break;
                    case '\t': builder.Append("\\t"); break;
                    default:
                        if (c < 0x20) builder.Append("\\u").Append(((int)c).ToString("x4"));
                        else builder.Append(c);
                        break;
                }
            }
            return builder.ToString();
        }
    }
}
