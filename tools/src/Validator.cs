// ForeverGuide build tooling - content validation and coverage report.
// Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
// SPDX-License-Identifier: GPL-3.0-only
//
// Checks (errors fail the build; warnings are reported):
//   * every race/class combination (Database/RaceClass.lua) has a start guide and a guide
//     chain that reaches the level cap without level gaps, cycles or dead ends (a chain that ends in
//     placeholder guides is a warning: its content is pending);
//   * guides compile (quest resolution etc. - see GuideCompiler);
//   * talent builds, when talent data ships, are legal against it (none ships yet: PH-TALENTS-SYSTEM);
//   * placeholder safety: pending steps carry no live data and name registered placeholders;
//   * manifest interface matches Config/Target.lua; saved variables declared (and not TBCGuide's);
//     every TOC/XML file exists; release blockers are listed.
// The coverage report (docs/COVERAGE_REPORT.md) is generated from the same data, so it can never
// claim more than the checks actually found.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace ForeverGuideTools
{
    public sealed class ValidationResult
    {
        public int Errors, Warnings;
        public List<string> Messages = new List<string>();
        public string Summary { get { return string.Format("validate: {0} error(s), {1} warning(s)", Errors, Warnings); } }
        public void Err(string m) { Errors++; Messages.Add("ERROR " + m); }
        public void Warn(string m) { Warnings++; Messages.Add("warn  " + m); }
        public void Info(string m) { Messages.Add("info  " + m); }
    }

    public sealed class TalentInfo { public int Id, Tier, Col, Ranks, Tab, PreId, PreRank; public string Name, Class, TabName; }

    public sealed class BuildCheck
    {
        public string Id, Name, Class, Kind, Role, File;
        public int Points;
        public int[] PerTab = new int[3];
        public List<string> Errors = new List<string>();
    }

    public sealed class RouteInfo
    {
        public string Race, Class, Faction;
        public List<CGuide> Guides = new List<CGuide>();
        public List<string> Problems = new List<string>();
        public int ReachedLevel;
    }

    public static class Validator
    {
        // ---------------------------------------------------------------- talent data
        static readonly Regex TalentLine = new Regex("\\{id=(\\d+),name=\"((?:[^\"\\\\]|\\\\.)*)\",tier=(\\d+),column=(\\d+),ranks=(\\d+),spells=\\{[^}]*\\}(?:,prereq=\\{(\\d+),(\\d+)\\})?\\}");
        static readonly Regex ClassLine = new Regex(@"^T\.(\w+) = \{");
        static readonly Regex TabLine = new Regex("^\\s*\\{id=(\\d+),name=\"([^\"]+)\"");

        public static Dictionary<string, List<TalentInfo>> LoadTalents(string addOnDir)
        {
            var d = new Dictionary<string, List<TalentInfo>>();
            string cls = null, tabName = null; int tab = 0;
            var treesFile = Path.Combine(addOnDir, "Talents", "Data", "TalentTrees.lua");
            if (!File.Exists(treesFile)) return d; // PH-TALENTS-SYSTEM: no data shipped
            foreach (var line in File.ReadAllLines(treesFile))
            {
                var cm = ClassLine.Match(line);
                if (cm.Success) { cls = cm.Groups[1].Value; tab = 0; d[cls] = new List<TalentInfo>(); continue; }
                var tm = TalentLine.Match(line);
                if (tm.Success && cls != null)
                {
                    d[cls].Add(new TalentInfo
                    {
                        Id = int.Parse(tm.Groups[1].Value), Name = (string)LuaLiteralReader.ParseValue("\"" + tm.Groups[2].Value + "\"", "t"),
                        Tier = int.Parse(tm.Groups[3].Value), Col = int.Parse(tm.Groups[4].Value), Ranks = int.Parse(tm.Groups[5].Value),
                        PreId = tm.Groups[6].Success ? int.Parse(tm.Groups[6].Value) : 0, PreRank = tm.Groups[7].Success ? int.Parse(tm.Groups[7].Value) : 0,
                        Tab = tab, Class = cls, TabName = tabName
                    });
                    continue;
                }
                var tb = TabLine.Match(line);
                if (tb.Success && cls != null && line.Contains("background=")) { tab++; tabName = tb.Groups[2].Value; }
            }
            return d;
        }

        // Parses Talents/Builds/*.lua: ns.RegisterTalentBuilds("CLASS", { ...literal... })
        static readonly Regex RegisterCall = new Regex("RegisterTalentBuilds\\(\\s*\"(\\w+)\"\\s*,");

        public static List<BuildCheck> CheckBuilds(string addOnDir, Dictionary<string, List<TalentInfo>> talents)
        {
            var result = new List<BuildCheck>();
            var buildDir = Path.Combine(addOnDir, "Talents", "Builds");
            if (!Directory.Exists(buildDir)) return result;
            foreach (var f in Directory.GetFiles(buildDir, "*.lua").OrderBy(x => x))
            {
                string text = File.ReadAllText(f);
                var m = RegisterCall.Match(text);
                if (!m.Success) { result.Add(new BuildCheck { File = Path.GetFileName(f), Id = "?", Errors = { "no RegisterTalentBuilds call" } }); continue; }
                string cls = m.Groups[1].Value;
                int open = text.IndexOf('{', m.Index + m.Length);
                int close = MatchBrace(text, open);
                LTable list;
                try { list = LuaLiteralReader.ParseValue(text.Substring(open, close - open + 1), Path.GetFileName(f)) as LTable; }
                catch (Exception e) { result.Add(new BuildCheck { File = Path.GetFileName(f), Id = "?", Errors = { "parse error: " + e.Message } }); continue; }
                List<TalentInfo> tl;
                talents.TryGetValue(cls, out tl);
                foreach (var kv in list.Pairs())
                {
                    var b = kv.Value as LTable;
                    if (b == null) continue;
                    var bc = new BuildCheck
                    {
                        File = Path.GetFileName(f), Class = cls, Id = b.Get("id") as string, Name = b.Get("name") as string,
                        Kind = b.Get("kind") as string, Role = b.Get("role") as string
                    };
                    result.Add(bc);
                    if (bc.Id == null || bc.Name == null || bc.Kind == null) bc.Errors.Add("missing id/name/kind");
                    if (tl == null) { bc.Errors.Add("no talent data for class " + cls); continue; }
                    var ranks = new Dictionary<int, int>();
                    var picks = b.Get("picks") as LTable;
                    if (picks == null) { bc.Errors.Add("no picks"); continue; }
                    int n = 0;
                    foreach (var pk in picks.Pairs())
                    {
                        var p = pk.Value as LTable;
                        string nm = p == null ? null : p.Get(1) as string;
                        int count = p != null && p.Get(2) is double ? (int)(double)p.Get(2) : 1;
                        var matches = tl.Where(x => string.Equals(x.Name, nm, StringComparison.OrdinalIgnoreCase)).ToList();
                        if (matches.Count == 0 && nm != null && nm.Contains(":"))
                        {
                            var parts = nm.Split(new[] { ':' }, 2);
                            matches = tl.Where(x => string.Equals(x.TabName, parts[0], StringComparison.OrdinalIgnoreCase) && string.Equals(x.Name, parts[1], StringComparison.OrdinalIgnoreCase)).ToList();
                        }
                        if (matches.Count != 1) { bc.Errors.Add((matches.Count == 0 ? "unknown" : "ambiguous") + " talent '" + nm + "'"); continue; }
                        var t = matches[0];
                        for (int k = 0; k < count; k++)
                        {
                            n++;
                            int cur; ranks.TryGetValue(t.Id, out cur);
                            int inTab = bc.PerTab[t.Tab - 1];
                            if (cur >= t.Ranks) bc.Errors.Add(string.Format("point {0}: {1} exceeds max rank {2}", n, t.Name, t.Ranks));
                            else if (inTab < (t.Tier - 1) * 5) bc.Errors.Add(string.Format("point {0}: {1} (tier {2}) needs {3} points in {4}, has {5}", n, t.Name, t.Tier, (t.Tier - 1) * 5, t.TabName, inTab));
                            else if (t.PreId > 0)
                            {
                                int pr; ranks.TryGetValue(t.PreId, out pr);
                                if (pr < t.PreRank)
                                {
                                    var pre = tl.FirstOrDefault(x => x.Id == t.PreId);
                                    bc.Errors.Add(string.Format("point {0}: {1} requires {2} {3}/{4} (has {5})", n, t.Name, pre != null ? pre.Name : "?", t.PreRank, pre != null ? pre.Ranks : 0, pr));
                                }
                            }
                            ranks[t.Id] = cur + 1;
                            bc.PerTab[t.Tab - 1]++;
                        }
                    }
                    bc.Points = n;
                    if (n > 61) bc.Errors.Add(n + " points exceeds 61");
                    if (n < 61) bc.Errors.Add("only " + n + " of 61 points allocated");
                }
            }
            return result;
        }

        static int MatchBrace(string s, int open)
        {
            int depth = 0; bool str = false; char q = '\0';
            for (int i = open; i < s.Length; i++)
            {
                char c = s[i];
                if (str) { if (c == '\\') { i++; continue; } if (c == q) str = false; continue; }
                if (c == '"' || c == '\'') { str = true; q = c; continue; }
                if (c == '-' && i + 1 < s.Length && s[i + 1] == '-') { while (i < s.Length && s[i] != '\n') i++; continue; }
                if (c == '{') depth++;
                else if (c == '}') { depth--; if (depth == 0) return i; }
            }
            return s.Length - 1;
        }

        // ---------------------------------------------------------------- race/class
        static readonly Regex RaceLine = new Regex("^\\s+(\\w+) = \\{id=(\\d+),faction=\"(\\w+)\",name=\"[^\"]+\",classes=\\{([^}]*)\\}");

        public static List<Tuple<string, string, string>> LoadCombos(string addOnDir)
        {
            var l = new List<Tuple<string, string, string>>();
            foreach (var line in File.ReadAllLines(Path.Combine(addOnDir, "Database", "RaceClass.lua")))
            {
                var m = RaceLine.Match(line);
                if (!m.Success) continue;
                foreach (Match c in Regex.Matches(m.Groups[4].Value, "\"(\\w+)\""))
                    l.Add(Tuple.Create(m.Groups[1].Value, c.Groups[1].Value, m.Groups[3].Value));
            }
            return l;
        }

        static bool Applies(CGuide g, string race, string cls, string faction)
        {
            if (g.Faction != "Both" && g.Faction != faction) return false;
            if (g.Races != null && !g.Races.Contains(race)) return false;
            if (g.Classes != null && !g.Classes.Contains(cls)) return false;
            return true;
        }

        public static RouteInfo Route(List<CGuide> guides, string race, string cls, string faction)
        {
            var r = new RouteInfo { Race = race, Class = cls, Faction = faction };
            var start = guides.FirstOrDefault(g => g.Start && g.Races != null && g.Races.Contains(race) && Applies(g, race, cls, faction));
            if (start == null) { r.Problems.Add("no start guide"); return r; }
            var seen = new HashSet<string>();
            var cur = start;
            int lastMax = 0;
            while (cur != null)
            {
                if (!seen.Add(cur.Id)) { r.Problems.Add("cycle at " + cur.Id); break; }
                if (!Applies(cur, race, cls, faction)) r.Problems.Add(cur.Id + " does not apply to this race/class/faction");
                if (lastMax > 0 && cur.MinLevel > lastMax + 2) r.Problems.Add(string.Format("level gap {0} -> {1} entering {2}", lastMax, cur.MinLevel, cur.Id));
                r.Guides.Add(cur);
                lastMax = Math.Max(lastMax, cur.MaxLevel);
                CGuide next = null;
                foreach (var n in cur.Next)
                {
                    List<string> l;
                    if (n.Value.TryGetValue("races", out l) && !l.Contains(race)) continue;
                    if (n.Value.TryGetValue("classes", out l) && !l.Contains(cls)) continue;
                    if (n.Value.TryGetValue("faction", out l) && l[0] != faction) continue;
                    next = guides.FirstOrDefault(g => g.Id == n.Key);
                    if (next != null) break;
                }
                cur = next;
            }
            r.ReachedLevel = lastMax;
            if (lastMax < GuideCompiler.LevelCap) r.Problems.Add("route ends at level " + lastMax);
            return r;
        }

        // ---------------------------------------------------------------- run
        public static ValidationResult Run(string root, string addOnDir)
        {
            var v = new ValidationResult();
            var comp = GuideCompiler.CompileAll(Path.Combine(root, "guides-src"), addOnDir, false);
            foreach (var e in comp.Errors) v.Err("guide: " + e);
            v.Info(comp.Summary);

            // Race/class coverage. ForeverGuide: routes may still be placeholders, so a route that ends in
            // a placeholder/blocked guide is reported (warning), never treated as reaching the cap.
            var combos = LoadCombos(addOnDir);
            foreach (var c in combos)
            {
                var r = Route(comp.Guides, c.Item1, c.Item2, c.Item3);
                foreach (var p in r.Problems)
                {
                    if (p.StartsWith("route ends") && r.Guides.Any(g => g.Status == "placeholder" || g.Status == "blocked"))
                        v.Warn(string.Format("route {0} {1}: content pending ({2})", c.Item1, c.Item2, p));
                    else v.Err(string.Format("route {0} {1}: {2}", c.Item1, c.Item2, p));
                }
            }
            var legal = new HashSet<string>(combos.Select(c => c.Item1 + "/" + c.Item2));
            foreach (var g in comp.Guides)
                if (g.Races != null && g.Classes != null)
                    foreach (var r in g.Races) foreach (var cl in g.Classes)
                            if (!legal.Contains(r + "/" + cl)) v.Warn(g.Id + " lists illegal combination " + r + "/" + cl);
            var used = new HashSet<string>();
            foreach (var c in combos) foreach (var g in Route(comp.Guides, c.Item1, c.Item2, c.Item3).Guides) used.Add(g.Id);
            foreach (var g in comp.Guides) if (!used.Contains(g.Id)) v.Warn("guide " + g.Id + " is not on any race/class route (reachable from the browser only)");

            // Placeholder safety: pending steps carry no live data; verified steps reference no placeholder.
            var phIds = GuideCompiler.LoadPlaceholderIds(addOnDir);
            if (phIds.Count == 0) v.Err("Config/Placeholders.lua defines no placeholders (file missing or unreadable)");
            foreach (var g in comp.Guides)
                foreach (var s in g.Steps)
                {
                    if (s.Kind == "pending" && (s.X >= 0 || s.Quest > 0 || s.MarkIcon > 0)) v.Err(g.Id + "/" + s.Sid + ": pending step carries live data");
                    if (s.Status == "verified" && s.Ph != null) v.Err(g.Id + "/" + s.Sid + ": verified step still references " + s.Ph);
                }
            int pendingSteps = comp.Guides.Sum(g => g.Steps.Count(s => s.Kind == "pending"));
            v.Info(string.Format("placeholders: {0} registered, {1} pending guide steps", phIds.Count, pendingSteps));

            // Talents: optional until verified Forever data exists (PH-TALENTS-SYSTEM).
            var talents = LoadTalents(addOnDir);
            var builds = CheckBuilds(addOnDir, talents);
            foreach (var b in builds) foreach (var e in b.Errors) v.Err(string.Format("build {0} ({1}): {2}", b.Id, b.File, e));
            if (builds.Select(b => b.Id).Distinct().Count() != builds.Count) v.Err("duplicate build ids");
            if (talents.Count == 0) v.Info("talents: no talent data shipped (PH-TALENTS-SYSTEM)");

            // Manifest vs target config, plus the release-packaging gate.
            string toc = File.ReadAllText(Path.Combine(addOnDir, "ForeverGuide.toc"));
            string target = File.ReadAllText(Path.Combine(addOnDir, "Config", "Target.lua"));
            var ti = Regex.Match(toc, @"## Interface:\s*(\d+)");
            var ci = Regex.Match(target, @"\binterface\s*=\s*(\d+)");
            if (!ti.Success || !ci.Success || ti.Groups[1].Value != ci.Groups[1].Value)
                v.Err("TOC interface and Config/Target.lua interface differ");
            if (!toc.Contains("## SavedVariables: ForeverGuideDB") || !toc.Contains("## SavedVariablesPerCharacter: ForeverGuideCharDB"))
                v.Err("saved variables not declared in TOC");
            if (Regex.IsMatch(toc, @"TBCGuideDB|TBCGuideCharDB")) v.Err("TOC declares TBCGuide's SavedVariables");
            foreach (var problem in ReleaseBlockers(addOnDir)) v.Warn("release blocked: " + problem);
            foreach (var problem in ManifestFiles(addOnDir)) v.Err(problem);

            var db = comp.Db;
            v.Info(string.Format("database: {0} quests, {1} npcs, {2} objects, {3} items, {4} zones (PH-DATA-QUESTDB)",
                db.Quests.Count, db.Npcs.Count, db.Objects.Count, db.Items.Count, db.UiMap.Count));
            return v;
        }

        // Reasons a public release must not be built yet. Empty = no known blocker.
        public static List<string> ReleaseBlockers(string addOnDir)
        {
            var l = new List<string>();
            string toc = File.ReadAllText(Path.Combine(addOnDir, "ForeverGuide.toc"));
            string target = File.ReadAllText(Path.Combine(addOnDir, "Config", "Target.lua"));
            if (Regex.IsMatch(toc, @"## X-Interface-Status:\s*BLOCKED") || Regex.IsMatch(target, "interfaceStatus\\s*=\\s*\"blocked\""))
                l.Add("TOC interface is unverified for the release client (PH-PLATFORM-INTERFACE)");
            var ph = File.ReadAllText(Path.Combine(addOnDir, "Config", "Placeholders.lua"));
            foreach (Match m in Regex.Matches(ph, "\\{\\s*id\\s*=\\s*\"(PH-[A-Z0-9-]+)\",\\s*area\\s*=\\s*\"packaging\",\\s*status\\s*=\\s*\"blocked\""))
                if (m.Groups[1].Value != "PH-PLATFORM-INTERFACE") l.Add(m.Groups[1].Value + " is blocked");
            return l;
        }

        // Every file the TOC (and the XML includes it names) loads must exist.
        public static List<string> ManifestFiles(string addOnDir)
        {
            var l = new List<string>();
            foreach (var raw in File.ReadAllLines(Path.Combine(addOnDir, "ForeverGuide.toc")))
            {
                var line = raw.Trim();
                if (line.Length == 0 || line.StartsWith("#")) continue;
                var path = Path.Combine(addOnDir, line.Replace('\\', Path.DirectorySeparatorChar));
                if (!File.Exists(path)) { l.Add("TOC lists missing file " + line); continue; }
                if (path.EndsWith(".xml", StringComparison.OrdinalIgnoreCase))
                    foreach (Match m in Regex.Matches(File.ReadAllText(path), "<Script\\s+file=\"([^\"]+)\""))
                        if (!File.Exists(Path.Combine(Path.GetDirectoryName(path), m.Groups[1].Value.Replace('\\', Path.DirectorySeparatorChar))))
                            l.Add(line + " includes missing file " + m.Groups[1].Value);
            }
            return l;
        }

        // ---------------------------------------------------------------- report
        public static void WriteCoverageReport(string root, string addOnDir, string path)
        {
            var comp = GuideCompiler.CompileAll(Path.Combine(root, "guides-src"), addOnDir, false);
            var combos = LoadCombos(addOnDir);
            var v = Run(root, addOnDir);
            var sb = new StringBuilder();
            sb.AppendLine("# ForeverGuide coverage report");
            sb.AppendLine();
            sb.AppendLine("Generated by `tools/build.ps1 report` from the guide sources and add-on files. It reports what the automated checks found.");
            sb.AppendLine("It is **not** evidence of in-game testing: nothing here has run in a WoW Forever client.");
            sb.AppendLine();
            sb.AppendLine("| Item | Count |");
            sb.AppendLine("|---|---|");
            sb.AppendLine("| Guides | " + comp.Guides.Count + " (" + comp.Guides.Count(g => g.Status == "verified") + " verified, " + comp.Guides.Count(g => g.Status == "placeholder" || g.Status == "blocked") + " placeholder/blocked) |");
            sb.AppendLine("| Guide steps | " + comp.Guides.Sum(g => g.Steps.Count) + " (" + comp.Guides.Sum(g => g.Steps.Count(s => s.Kind == "pending")) + " pending) |");
            sb.AppendLine("| Distinct quests referenced | " + comp.Guides.SelectMany(g => g.Steps).Where(s => s.Quest > 0).Select(s => s.Quest).Distinct().Count() + " |");
            sb.AppendLine("| Race/class combinations (inherited_unverified) | " + combos.Count + " |");
            sb.AppendLine("| Quest database records | " + comp.Db.Quests.Count + " |");
            sb.AppendLine("| Validation | " + v.Summary + " |");
            sb.AppendLine();
            sb.AppendLine("## Guides");
            sb.AppendLine();
            sb.AppendLine("| Guide | Faction | Status | Levels | Zone | Steps | Pending |");
            sb.AppendLine("|---|---|---|---|---|---|---|");
            foreach (var g in comp.Guides.OrderBy(g => g.Faction).ThenBy(g => g.MinLevel))
                sb.AppendLine(string.Format("| {0} | {1} | {2} | {3} | {4} | {5} | {6} |", g.Name, g.Faction, g.Status,
                    g.LevelsUnknown ? "pending" : g.MinLevel + "-" + g.MaxLevel, g.ZoneUnknown ? "pending" : g.ZoneName,
                    g.Steps.Count, g.Steps.Count(s => s.Kind == "pending")));
            sb.AppendLine();
            sb.AppendLine("## Release blockers");
            sb.AppendLine();
            var blockers = ReleaseBlockers(addOnDir);
            if (blockers.Count == 0) sb.AppendLine("None detected by the automated checks.");
            foreach (var b in blockers) sb.AppendLine("- " + b);
            sb.AppendLine();
            sb.AppendLine("See docs/PLACEHOLDERS.md for every open item and docs/COMPATIBILITY.md for the evidence log.");
            File.WriteAllText(path, sb.ToString(), new UTF8Encoding(false));
            WritePlaceholderReport(addOnDir, Path.Combine(Path.GetDirectoryName(path), "PLACEHOLDERS.md"), comp);
        }

        // docs/PLACEHOLDERS.md, generated from Config/Placeholders.lua (the single source of truth).
        public static void WritePlaceholderReport(string addOnDir, string path, CompileResult comp)
        {
            var text = File.ReadAllText(Path.Combine(addOnDir, "Config", "Placeholders.lua"));
            int open = text.IndexOf("ns.Placeholders = {", StringComparison.Ordinal);
            int brace = text.IndexOf('{', open);
            var list = LuaLiteralReader.ParseValue(text.Substring(brace, MatchBrace(text, brace) - brace + 1), "Placeholders.lua") as LTable;
            var sb = new StringBuilder();
            sb.AppendLine("# Placeholder registry");
            sb.AppendLine();
            sb.AppendLine("GENERATED by `tools/build.ps1 report` from `ForeverGuide/Config/Placeholders.lua`. Edit that file, not this one.");
            sb.AppendLine("Each entry is something ForeverGuide does not know yet about WoW Forever. Search the repository for an id to find every record it affects.");
            sb.AppendLine();
            sb.AppendLine("| Id | Area | Status | Missing | Why unknown | Expected type | Affects | Evidence needed | Guide steps |");
            sb.AppendLine("|---|---|---|---|---|---|---|---|---|");
            foreach (var kv in list.Pairs())
            {
                var e = kv.Value as LTable;
                if (e == null) continue;
                string id = e.Get("id") as string;
                int steps = comp.Guides.Sum(g => g.Steps.Count(s => s.Ph == id));
                Func<string, string> f = k => ((e.Get(k) as string) ?? "").Replace("|", "\\|");
                sb.AppendLine(string.Format("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} |", id, f("area"), f("status"),
                    f("missing"), f("why"), f("type"), f("affects"), f("evidence"), steps));
            }
            File.WriteAllText(path, sb.ToString(), new UTF8Encoding(false));
        }
    }
}
