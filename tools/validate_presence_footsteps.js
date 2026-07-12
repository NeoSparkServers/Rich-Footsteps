const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const modDir = path.resolve(__dirname, "..");
const dataDir = path.join(modDir, "data");
const soundsDir = path.join(modDir, "sounds");
const specialValues = new Set(["MESSY_GROUND", "NON_EMITTER", "NOT_EMITTED", "NOT_EMITTER", "VANILLA"]);
const errors = [];

function read(file) {
  return fs.readFileSync(file, "utf8");
}

function unique(values) {
  return [...new Set(values)];
}

function luaTopKeys(file) {
  const text = read(file);
  return new Set([...text.matchAll(/^  \["([^"]+)"\] = \{/gm)].map((match) => match[1]));
}

function checkAcousticList(source, value, acoustics) {
  for (const key of String(value).split(/[,\s]+/).filter(Boolean)) {
    if (!specialValues.has(key) && !acoustics.has(key)) {
      errors.push(`${source}: missing acoustic ${key}`);
    }
  }
}

function checkLuaDataFile(file, acoustics) {
  const full = path.join(dataDir, file);
  if (!fs.existsSync(full)) {
    errors.push(`missing data file: ${file}`);
    return;
  }
  const text = read(full);
  for (const match of text.matchAll(/\]\s*=\s*"([^"]+)"/g)) {
    checkAcousticList(file, match[1], acoustics);
  }
  for (const match of text.matchAll(/},\s*"([^"]+)"\)/g)) {
    checkAcousticList(file, match[1], acoustics);
  }
}

function validateMclCherryStairs() {
  const text = read(path.join(dataDir, "mcl_nodes.lua"));
  const mappings = new Map();
  for (const match of text.matchAll(/add\("mcl_stairs",\s*\{([\s\S]*?)\},\s*"([^"]+)"\)/g)) {
    for (const name of match[1].matchAll(/"([^"]+)"/g)) {
      mappings.set(name[1], match[2]);
    }
  }

  for (const name of [
    "stair_cherrywood",
    "slab_cherrywood",
    "stair_cherry_blossom",
    "slab_cherry_blossom",
    "stair_cherry_blossom_bark",
    "stair_cherry_blossom_bark_inner",
    "stair_cherry_blossom_bark_outer",
    "slab_cherry_blossom_bark",
    "slab_cherry_blossom_bark_top",
    "slab_cherry_blossom_bark_double",
  ]) {
    if (mappings.get(name) !== "softwood") {
      errors.push(`mcl_nodes.lua: expected mcl_stairs:${name} to map to softwood`);
    }
  }
}

function validateCdb() {
  const cdb = JSON.parse(read(path.join(modDir, ".cdb.json")));
  if (cdb.title !== "Rich Footsteps") {
    errors.push(`.cdb.json: expected title Rich Footsteps, got ${cdb.title}`);
  }
  if (cdb.license !== "LGPL-3.0-or-later") {
    errors.push(`.cdb.json: expected license LGPL-3.0-or-later, got ${cdb.license}`);
  }
  if (cdb.media_license !== "MIT") {
    errors.push(`.cdb.json: expected media_license MIT, got ${cdb.media_license}`);
  }
  if (cdb.ai_disclosure !== "ASSISTED") {
    errors.push(`.cdb.json: expected ai_disclosure ASSISTED, got ${cdb.ai_disclosure}`);
  }
}

function validateMetadataText() {
  const modConf = read(path.join(modDir, "mod.conf"));
  const readme = read(path.join(modDir, "README.md"));
  const notices = read(path.join(modDir, "THIRD_PARTY_NOTICES.md"));

  if (!modConf.includes("title = Rich Footsteps")) {
    errors.push("mod.conf: missing title = Rich Footsteps");
  }
  if (!readme.includes("<h1 align=\"center\">Rich Footsteps Luanti Mod</h1>")) {
    errors.push("README.md: expected centered Rich Footsteps Luanti Mod heading");
  }
  if (!readme.includes("screenshots/icon.png")) {
    errors.push("README.md: missing icon reference");
  }
  if (!fs.existsSync(path.join(modDir, "screenshots", "icon.png"))) {
    errors.push("missing screenshots/icon.png");
  }
  for (const text of [readme, notices]) {
    const normalized = text.replace(/\s+/g, " ");
    if (!normalized.includes("1.13.0+26.1")) {
      errors.push("metadata: missing Presence Footsteps 1.13.0+26.1 baseline");
      break;
    }
    if (!normalized.includes("No assets, data, or code from Presence Footsteps 1.13.2+26.1 or later are used.")) {
      errors.push("metadata: missing no-newer-PolyForm-materials statement");
      break;
    }
  }
}

function validateLicenseFiles() {
  for (const file of ["LICENSE", "THIRD_PARTY_NOTICES.md", "README.md"]) {
    const full = path.join(modDir, file);
    if (!fs.existsSync(full)) {
      errors.push(`missing release notice file: ${file}`);
    }
  }

  const license = read(path.join(modDir, "LICENSE"));
  for (const expected of [
    "LGPL-3.0-or-later",
    "The MIT License (MIT)",
    "Copyright (c) 2019 Mine Little Pony",
    "AI-assisted",
  ]) {
    if (!license.includes(expected)) {
      errors.push(`LICENSE: missing ${expected}`);
    }
  }

  const notices = read(path.join(modDir, "THIRD_PARTY_NOTICES.md"));
  for (const expected of [
    "Presence-Footsteps-1.13.0-26.1",
    "Hurricaaane",
    "Sollace",
    "Mine Little Pony contributors",
    "sounds/*.ogg",
    "MIT",
  ]) {
    if (!notices.includes(expected)) {
      errors.push(`THIRD_PARTY_NOTICES.md: missing ${expected}`);
    }
  }
}

function validateRefs() {
  const soundsLua = read(path.join(dataDir, "sounds.lua"));
  const acousticsLua = read(path.join(dataDir, "acoustics.lua"));
  const soundGroups = luaTopKeys(path.join(dataDir, "sounds.lua"));
  const acoustics = luaTopKeys(path.join(dataDir, "acoustics.lua"));
  const oggs = new Set(fs.readdirSync(soundsDir).filter((file) => file.endsWith(".ogg")).map((file) => file.replace(/\.ogg$/, "")));

  for (const match of acousticsLua.matchAll(/\["name"\] = "([^"]+)"/g)) {
    if (!soundGroups.has(match[1])) {
      errors.push(`missing sound group: ${match[1]}`);
    }
  }
  for (const match of soundsLua.matchAll(/"(presence_footsteps_[^"]+)"/g)) {
    if (!oggs.has(match[1])) {
      errors.push(`missing ogg: ${match[1]}`);
    }
  }

  for (const file of [
    "block_map.lua",
    "primitive_map.lua",
    "biome_variance.lua",
    "golem_map.lua",
    "mcl_nodes.lua",
    "minetest_game_nodes.lua",
  ]) {
    checkLuaDataFile(file, acoustics);
  }

  return { acoustics: acoustics.size, soundGroups: soundGroups.size, oggs: oggs.size };
}

function validateNoJavaArtifacts() {
  const forbidden = new Set([".java", ".class", ".jar"]);
  const forbiddenNames = new Set(["build.gradle", "gradlew", "gradlew.bat", "settings.gradle", "gradle.properties", "fabric.mod.json"]);
  const stack = [modDir];
  while (stack.length) {
    const dir = stack.pop();
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        if (entry.name === ".git" || entry.name === "node_modules") {
          continue;
        }
        stack.push(full);
      } else if (forbidden.has(path.extname(entry.name)) || forbiddenNames.has(entry.name)) {
        errors.push(`forbidden Java/Fabric artifact: ${path.relative(modDir, full)}`);
      }
    }
  }
}

function validateMonoOgg() {
  const ffprobe = spawnSync("ffprobe", ["-version"], { encoding: "utf8" });
  if (ffprobe.status !== 0) {
    console.warn("ffprobe not found; skipped mono OGG validation");
    return;
  }
  const files = fs.readdirSync(soundsDir).filter((file) => file.endsWith(".ogg"));
  for (const file of files) {
    const full = path.join(soundsDir, file);
    const result = spawnSync("ffprobe", [
      "-v", "error",
      "-select_streams", "a:0",
      "-show_entries", "stream=channels",
      "-of", "default=nokey=1:noprint_wrappers=1",
      full,
    ], { encoding: "utf8" });
    if (result.status !== 0 || result.stdout.trim().split(/\s+/)[0] !== "1") {
      errors.push(`non-mono or unreadable ogg: ${file}`);
    }
  }
}

validateCdb();
validateMetadataText();
validateLicenseFiles();
validateMclCherryStairs();
const counts = validateRefs();
validateNoJavaArtifacts();
validateMonoOgg();

const finalErrors = unique(errors).sort();
if (finalErrors.length) {
  console.error(finalErrors.join("\n"));
  process.exit(1);
}

console.log(`validation ok: ${counts.acoustics} acoustics, ${counts.soundGroups} sound groups, ${counts.oggs} ogg files`);
