#!/usr/bin/env node
/**
 * Generates platform token files from design/tokens.json.
 * Run: node design/generate.mjs
 */

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const TOKENS_PATH = join(__dirname, 'tokens.json');

const tokens = JSON.parse(readFileSync(TOKENS_PATH, 'utf8'));

function hexToFlutter(hex) {
  const h = hex.replace('#', '').toUpperCase();
  return `0xFF${h}`;
}

function dartNumber(v) {
  return Number.isInteger(v) ? `${v}.0` : `${v}`;
}

function parseColor(value) {
  if (value.startsWith('#')) {
    return { type: 'hex', flutter: hexToFlutter(value), css: value.toLowerCase() };
  }
  if (value.startsWith('rgba(')) {
    const m = value.match(/rgba\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)/);
    if (!m) throw new Error(`Invalid rgba: ${value}`);
    const [, r, g, b, a] = m.map(Number);
    const alpha = Math.round(a * 255);
    const flutter = `0x${alpha.toString(16).padStart(2, '0').toUpperCase()}${Math.round(r).toString(16).padStart(2, '0')}${Math.round(g).toString(16).padStart(2, '0')}${Math.round(b).toString(16).padStart(2, '0')}`.toUpperCase();
    return { type: 'rgba', flutter, css: value };
  }
  throw new Error(`Unsupported color: ${value}`);
}

function dartColorConst(name, value) {
  const c = parseColor(value);
  return `  static const ${name} = Color(${c.flutter});`;
}

function generateDart() {
  const { color, spacing, radius } = tokens;
  const lines = [
    '// GENERATED FILE — DO NOT EDIT BY HAND',
    '// Source: design/tokens.json',
    '// Regenerate: node design/generate.mjs',
    '',
    "import 'package:flutter/material.dart';",
    '',
    '/// Generated color, spacing, and radius tokens.',
    'class AppTokens {',
    '  AppTokens._();',
    '',
    '  // Brand',
    dartColorConst('brandPrimary', color.brand.primary),
    dartColorConst('brandStrong', color.brand.strong),
    dartColorConst('brandLight', color.brand.light),
    '',
    '  // Status',
    dartColorConst('danger', color.status.danger),
    dartColorConst('success', color.status.success),
    '',
    '  // Dark theme',
    ...Object.entries(color.dark).map(([k, v]) => {
      const name = `dark${k.charAt(0).toUpperCase()}${k.slice(1)}`;
      return dartColorConst(name, v);
    }),
    '',
    '  // Light theme',
    ...Object.entries(color.light).map(([k, v]) => {
      const name = `light${k.charAt(0).toUpperCase()}${k.slice(1)}`;
      return dartColorConst(name, v);
    }),
    '',
    '  // Spacing',
    ...Object.entries(spacing).map(([k, v]) => {
      return `  static const ${k} = ${dartNumber(v)};`;
    }),
    '',
    '  // Radius',
    ...Object.entries(radius).map(([k, v]) => {
      const dartName = `radius${k.charAt(0).toUpperCase()}${k.slice(1)}`;
      return `  static const ${dartName} = ${dartNumber(v)};`;
    }),
    '',
    '  // Typography sizes',
    ...Object.entries(tokens.typography.size).map(([k, v]) => {
      return `  static const fontSize${k.charAt(0).toUpperCase()}${k.slice(1)} = ${dartNumber(v)};`;
    }),
    '}',
    '',
    '/// Backward-compatible aliases used across the Flutter app.',
    'class AppColors {',
    '  AppColors._();',
    '',
    '  static const teal = AppTokens.brandPrimary;',
    '  static const tealDark = AppTokens.brandStrong;',
    '  static const tealLight = AppTokens.brandLight;',
    '  static const unreadBadge = AppTokens.brandPrimary;',
    '',
    '  static const darkBg = AppTokens.darkBg;',
    '  static const darkList = AppTokens.darkBg;',
    '  static const darkAppBar = AppTokens.darkBgElev;',
    '  static const darkChatBg = AppTokens.darkChatBg;',
    '  static const darkDrawer = AppTokens.darkBgElev;',
    '  static const darkDrawerHeader = AppTokens.darkDrawerHeader;',
    '  static const darkBubbleReceived = AppTokens.darkBubbleOther;',
    '  static const darkBubbleMine = AppTokens.darkBubbleMine;',
    '  static const darkInput = AppTokens.darkBgInput;',
    '  static const dateChipBg = AppTokens.darkDateChipBg;',
    '  static const darkSubtitle = AppTokens.darkTextMuted;',
    '  static const darkDivider = AppTokens.darkDividerSolid;',
    '  static const darkTileHighlight = AppTokens.darkTileHighlight;',
    '  static const darkTileActive = AppTokens.darkTileActive;',
    '  static const darkText = AppTokens.darkText;',
    '',
    '  static const lightBg = AppTokens.lightBg;',
    '  static const lightBgElev = AppTokens.lightBgElev;',
    '  static const lightBgElev2 = AppTokens.lightBgElev2;',
    '  static const lightAppBar = AppTokens.lightAppBar;',
    '  static const lightBubbleReceived = AppTokens.lightDateChipBg;',
    '  static const lightBubbleMine = AppTokens.lightBubbleMine;',
    '  static const lightBubbleOther = AppTokens.lightBubbleOther;',
    '  static const lightSubtitle = AppTokens.lightTextMuted;',
    '  static const lightDivider = AppTokens.lightDivider;',
    '  static const lightInput = AppTokens.lightBgInput;',
    '  static const lightTileHighlight = AppTokens.lightTileHighlight;',
    '  static const lightTileActive = AppTokens.lightTileActive;',
    '  static const lightText = AppTokens.lightText;',
    '  static const lightBorder = AppTokens.lightBorder;',
    '}',
    '',
  ];

  const outputs = [
    join(__dirname, 'generated', 'tokens.dart'),
    join(ROOT, 'App', 'lib', 'core', 'generated', 'tokens.dart'),
  ];

  for (const out of outputs) {
    mkdirSync(dirname(out), { recursive: true });
    writeFileSync(out, lines.join('\n'), 'utf8');
    console.log(`Wrote ${out}`);
  }
}

function cssVar(name, value) {
  const c = parseColor(value);
  return `  --${name}: ${c.css};`;
}

function generateCss() {
  const { color, radius, shadow, layout, avatar } = tokens;
  const sidebarClamp = `clamp(${layout.sidebarWidthMin}px, ${layout.sidebarWidthVw}vw, ${layout.sidebarWidthMax}px)`;

  const lines = [
    '/* GENERATED FILE — DO NOT EDIT BY HAND */',
    '/* Source: design/tokens.json */',
    '/* Regenerate: node design/generate.mjs */',
    '',
    ':root {',
    '  color-scheme: dark light;',
    '',
    '  /* Brand */',
    cssVar('brand', color.brand.primary),
    cssVar('brand-strong', color.brand.strong),
    `  --brand-soft: ${color.brand.soft};`,
    '',
    '  /* Status */',
    cssVar('danger', color.status.danger),
    `  --danger-soft: ${color.status.dangerSoft};`,
    cssVar('success', color.status.success),
    '',
    '  /* Sizing */',
    `  --radius-sm: ${radius.sm}px;`,
    `  --radius-md: ${radius.md}px;`,
    `  --radius-lg: ${radius.lg}px;`,
    `  --radius-xl: ${radius.xl}px;`,
    `  --radius-input: ${radius.input}px;`,
    `  --shadow-1: ${shadow['1']};`,
    `  --shadow-2: ${shadow['2']};`,
    '',
    `  --header-height: ${layout.headerHeight}px;`,
    `  --compose-min-height: ${layout.composeMinHeight}px;`,
    `  --sidebar-width: ${sidebarClamp};`,
    '',
    '  /* Avatar gradient palette for letter fallbacks */',
    ...avatar.gradients.map((g, i) => `  --av-${i + 1}: ${g};`),
    '}',
    '',
    "[data-theme='dark'] {",
    cssVar('bg', color.dark.bg),
    cssVar('bg-elev', color.dark.bgElev),
    cssVar('bg-elev-2', color.dark.bgElev2),
    cssVar('bg-hover', color.dark.bgHover),
    cssVar('bg-input', color.dark.bgInput),
    `  --bg-overlay: ${color.dark.bgOverlay};`,
    cssVar('text', color.dark.text),
    cssVar('text-muted', color.dark.textMuted),
    cssVar('text-faint', color.dark.textFaint),
    `  --border: ${color.dark.border};`,
    `  --divider: ${color.dark.divider};`,
    cssVar('bubble-mine', color.dark.bubbleMine),
    cssVar('bubble-mine-fg', color.dark.bubbleMineFg),
    cssVar('bubble-other', color.dark.bubbleOther),
    cssVar('bubble-other-fg', color.dark.bubbleOtherFg),
    `  --bubble-time: ${color.dark.bubbleTime};`,
    cssVar('chat-bg', color.dark.chatBg),
    '  --chat-pattern: radial-gradient(',
    '    circle at 20% 10%,',
    '    rgba(42, 171, 238, 0.07),',
    '    transparent 50%',
    '  );',
    `  --scrollbar: ${color.dark.scrollbar};`,
    `  --scrollbar-hover: ${color.dark.scrollbarHover};`,
    '}',
    '',
    "[data-theme='light'] {",
    cssVar('bg', color.light.bg),
    cssVar('bg-elev', color.light.bgElev),
    cssVar('bg-elev-2', color.light.bgElev2),
    cssVar('bg-hover', color.light.bgHover),
    cssVar('bg-input', color.light.bgInput),
    `  --bg-overlay: ${color.light.bgOverlay};`,
    cssVar('text', color.light.text),
    cssVar('text-muted', color.light.textMuted),
    cssVar('text-faint', color.light.textFaint),
    `  --border: ${color.light.border};`,
    `  --divider: ${color.light.divider};`,
    cssVar('bubble-mine', color.light.bubbleMine),
    cssVar('bubble-mine-fg', color.light.bubbleMineFg),
    cssVar('bubble-other', color.light.bubbleOther),
    cssVar('bubble-other-fg', color.light.bubbleOtherFg),
    `  --bubble-time: ${color.light.bubbleTime};`,
    cssVar('chat-bg', color.light.chatBg),
    '  --chat-pattern: radial-gradient(',
    '    circle at 20% 10%,',
    '    rgba(42, 171, 238, 0.08),',
    '    transparent 50%',
    '  );',
    `  --scrollbar: ${color.light.scrollbar};`,
    `  --scrollbar-hover: ${color.light.scrollbarHover};`,
    '}',
    '',
  ];

  const out = join(ROOT, 'Web', 'src', 'styles', 'tokens.css');
  writeFileSync(out, lines.join('\n'), 'utf8');
  console.log(`Wrote ${out}`);
}

generateDart();
generateCss();
console.log('Token generation complete.');
