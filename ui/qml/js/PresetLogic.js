.pragma library
// Preset and live-settings logic shared by the Settings & Presets pages (ported from views/presets.js).

var CAT_LABELS = {
  sens: "Sensitivity", fov: "Field of view", crosshair: "Crosshair", visuals: "Colors & visuals", audio: "Audio",
  graphics: "Graphics", hud: "HUD", theme: "Theme", gameplay: "Gameplay"
}
var CAT_ORDER = ["sens", "fov", "crosshair", "visuals", "audio", "graphics", "hud", "theme", "gameplay"]
var CAT_ICONS = { sens: "target", fov: "eye", crosshair: "target", visuals: "image", audio: "bolt", graphics: "layers", hud: "grid", theme: "sliders", gameplay: "settings" }

// Friendly labels for the settings people touch most; everything else is shown by its KovaaK's key.
var LABELS = {
  XSens: ["Horizontal sensitivity"], YSens: ["Vertical sensitivity"], DPI: ["Mouse DPI", "Used for cm/360 & in/360 scales"],
  SensScaleString: ["Sensitivity scale", "Which game's sensitivity units to use"], FOV: ["Field of view"], FOVScaleString: ["FOV scale"],
  CrosshairFile: ["Crosshair image"], CrosshairScale: ["Crosshair scale"], CrosshairColor: ["Crosshair color"],
  CurrentThemeName: ["UI theme"], MasterVolume: ["Master volume"], MaxFPS: ["Max FPS (in game)"], MenuMaxFPS: ["Max FPS (menus)"],
  HideGun: ["Hide weapon model"], WeaponHidden: ["Hide weapon (weapon settings)"], PauseOnLossOfFocus: ["Pause when the game loses focus", "Recommended ON so switching to Kovaak's Plus pauses the run"],
  EnemyBodyColor: ["Enemy body color"], EnemyHeadColor: ["Enemy head color"], ShowHealthBars: ["Show health bars"],
  CountDownBeforeChallengeStart: ["Countdown before challenge (s)"], Gamma: ["Gamma"], ResolutionScale: ["Resolution scale (%)"],
  SaveStatistics: ["Save run statistics", "Must be ON for Kovaak's Plus to see your runs"], SkipPlaylistChallengeResults: ["Skip playlist results screens"],
  HitVolume: ["Hit sound volume"], KillConfirmedSound: ["Kill sound"], SpawnSound: ["Spawn sound"], BodyHitSound: ["Hit sound (weapon)"]
}
var PRIORITY = ["XSens", "YSens", "SensScaleString", "DPI", "FOV", "FOVScaleString", "CrosshairFile", "CrosshairScale", "CrosshairColor", "CurrentThemeName", "MasterVolume", "PauseOnLossOfFocus", "SaveStatistics"]
var SECTION_TYPE = { booleanSettings: "bool", integerSettings: "int", floatSettings: "float", stringSettings: "string", vectorSettings: "vector", colorSettings: "color" }

function short(k) { var i = k.indexOf("::"); return i >= 0 ? k.slice(i + 2) : k }
function humanize(k) { return short(k).replace(/_/g, " ").replace(/([a-z])([A-Z])/g, "$1 $2").replace(/([A-Z]+)([A-Z][a-z])/g, "$1 $2") }

// Mirror of SettingsManager.Category on the C# side.
function category(key) {
  var k = short(key);
  if (/^(XSens|YSens|DPI|SensScaleString|SensitivityScaleTargetEnum|BaseIncrement|YInvert|ToggleADS|ZoomSensMultiplier|AutoScaleZoomSens|SensRandomizer_.*)$/.test(k)) return "sens";
  if (/^(FOV|FOVScaleString|FOVScalarTargetEnum|FILMSCustom.*|CustomFOVYawMult|CustomYaw|ADSZoomFOV|ZoomFOVMultiplier|HipfireCustomFOV.*|ADSCustomFOV.*|FOVScale|ADSFOVScale)$/.test(k)) return "fov";
  if (/^(Crosshair.*|Hitmarker.*|HeadHitmarker.*|Hitmarkers|HeadHitmarkers|ShowBloom|BloomMultiplier)$/.test(k)) return "crosshair";
  if (k === "CurrentThemeName") return "theme";
  if (/(Volume|Pitch|Sound|Sounds)/i.test(k) || k.indexOf("Miss") === 0) return "audio";
  if (/^(Anisotropy|AntiAliasing.*|Shadows|PostProcessing|Effects|MaxFPS|MenuMaxFPS|ResolutionScale|Gamma|TextureStreaming|LowLatencyMode|SceneColorFormat|CloudCover|TiledReflections|OneFrameThreadLag|InputLagFrameCount|UseMeshInstancesInKmc|CacheDuration)$/.test(k)) return "graphics";
  if (/^(HiddenUiElementsMask|ShowVersionDuringGameplay|ShowInfoBars|ShowSessionBestOnHighScoreBar|HighScoreFadeout|UIAnimationSpeed|ScoreGraphHistoryLength|SessionStatsMode|ChallengeHistogramStats|ChallengeResults.*|LatencyFlashIndicator|FloatingCombatText|ShowBotProfileOnHealthbar)$/.test(k)) return "hud";
  if (/^(Enemy|Team|Wall|Floor|Ceiling|Ramp|Sky|Solid|OnHit|OnLookAt|Override|ChangeEnemy|BoundingBox|HideGibs|HideGun|WeaponHidden|ShowHealthBars|AutoHideHealthbar|DecalTime|ProjectileMarkerScale|BarSize|ShowSun|DeathCam|Tracer|WeaponModel|WeaponSkin|OverrideWeapon|ProjectileGraphic)/i.test(k) || /Material$/.test(k)) return "visuals";
  return "gameplay";
}

// Colour helpers: vectors are 0-1 floats, colors are 0-255 ints, weapon ini uses "X=0.9 Y=0.0 Z=0.0".
function hex2(n) { var s = Math.round(Math.max(0, Math.min(255, n))).toString(16); return s.length < 2 ? "0" + s : s }
function vecToHex(v) { return "#" + hex2(v.x * 255) + hex2(v.y * 255) + hex2(v.z * 255) }
function hexToVec(hx) { hx = String(hx); return { x: +(parseInt(hx.slice(1, 3), 16) / 255).toFixed(4), y: +(parseInt(hx.slice(3, 5), 16) / 255).toFixed(4), z: +(parseInt(hx.slice(5, 7), 16) / 255).toFixed(4) } }
function iniToVec(s) { var m = /X=([\d.\-]+)\s+Y=([\d.\-]+)\s+Z=([\d.\-]+)/.exec(s || ""); return m ? { x: +m[1], y: +m[2], z: +m[3] } : null }
function vecToIni(v) { return "X=" + v.x.toFixed(3) + " Y=" + v.y.toFixed(3) + " Z=" + v.z.toFixed(3) }
function rgbToHex(c) { return "#" + hex2(c.r) + hex2(c.g) + hex2(c.b) }

/** Flatten a settings snapshot into editable rows. */
function rows(snap) {
  var out = []
  Object.keys(SECTION_TYPE).forEach(function (section) {
    var type = SECTION_TYPE[section], sec = snap.primary[section] || {}
    Object.keys(sec).forEach(function (key) {
      var cat = category(key)
      out.push({ id: "p:" + section + ":" + key, src: "primary", section: section, key: key, value: sec[key], type: type,
                 cat: (type === "vector" || type === "color") && cat === "gameplay" ? "visuals" : cat })
    })
  })
  Object.keys(snap.weapon || {}).forEach(function (key) {
    var value = snap.weapon[key], vec = iniToVec(value)
    var type = vec ? "inivector" : /^(true|false)$/i.test(value) ? "inibool" : /^-?\d+(\.\d+)?$/.test(value) ? "ininum" : "inistring"
    out.push({ id: "w:" + key, src: "weapon", key: key, value: value, type: type, cat: category(key) })
  })
  return out
}

function label(r) { var l = LABELS[short(r.key)]; return l ? l[0] : humanize(r.key) }
function hint(r) { var l = LABELS[short(r.key)]; return l && l[1] ? l[1] : (r.src === "weapon" ? "weaponsettings.ini \u00b7 " + short(r.key) : short(r.key)) }

function specs(p) {
  var f = p.primary.floatSettings || {}, s = p.primary.stringSettings || {}, i = p.primary.integerSettings || {}
  var sens = f["EFloatSettingId::XSens"]
  return {
    sens: sens != null ? (+sens.toFixed(3)) + " " + (s["EStringSettingId::SensScaleString"] || "") : null,
    dpi: i["EIntegerSettingId::DPI"],
    fov: f["EFloatSettingId::FOV"] != null ? f["EFloatSettingId::FOV"] + " " + (s["EStringSettingId::FOVScaleString"] || "") : null,
    crosshair: (p.weapon && p.weapon.CrosshairFile) || p.crosshairFile,
    theme: p.themeName
  }
}
