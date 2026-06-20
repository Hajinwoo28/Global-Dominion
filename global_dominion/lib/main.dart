// ============================================================================
// GLOBAL DOMINION: RISE OF NATIONS
// Complete Real-Time Strategy Game with Online Multiplayer
// Flutter Mobile/Desktop Client
// ============================================================================
//
// pubspec.yaml — add these dependencies:
//   web_socket_channel: ^3.0.1
//
// Flask Backend (server.py) events expected:
//   RECEIVE: join_room, leave_room, ready, action, end_turn, chat
//   SEND:    room_created, room_joined, player_ready, game_started,
//            game_state, action_ack, chat_msg, player_left, game_over
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 1 ▸ CONSTANTS
// ══════════════════════════════════════════════════════════════════════════════

const String kAppVersion = '1.0.0';
const String kDefaultWsUrl = 'wss://global-dominion.vercel.app/ws';
const int kMapW = 30;
const int kMapH = 20;
const double kTileSize = 48.0;
const int kTickMs = 1000; // 1-second game tick
const int kAiTickMs = 2500; // AI action interval
const int kEcoVictoryTicks = 300; // 5 min at top economy
const int kTerritoryVictoryPct = 75;

// Admin / debug tooling — local dev convenience only. These are compiled
// straight into the client, so anyone who decompiles the app can read them.
// Fine for solo testing; before a public multiplayer release this check
// belongs server-side, not in the Flutter binary.
const String kAdminUsername = 'Hajinwoo';
const String kAdminPassword = 'BuunjaxPuccaV2';

const Color kColorBg = Color(0xFF0A0E1A);
const Color kColorPanel = Color(0xFF111827);
const Color kColorBorder = Color(0xFF1E2D45);
const Color kColorGold = Color(0xFFD4AF37);
const Color kColorGoldDark = Color(0xFF8B6914);
const Color kColorAccent = Color(0xFFE53935);
const Color kColorText = Color(0xFFE8E0CC);
const Color kColorMuted = Color(0xFF6B7280);
const Color kColorSuccess = Color(0xFF22C55E);

const List<Color> kNationColors = [
  Color(0xFFEF4444),
  Color(0xFF3B82F6),
  Color(0xFF22C55E),
  Color(0xFFF97316),
  Color(0xFFA855F7),
  Color(0xFF06B6D4),
  Color(0xFFEC4899),
  Color(0xFF64748B),
  Color(0xFFEAB308),
  Color(0xFF14B8A6),
  Color(0xFFD946EF),
  Color(0xFF0EA5E9),
  Color(0xFF84CC16),
  Color(0xFFF43F5E),
  Color(0xFF6366F1),
  Color(0xFF78716C),
];

const List<String> kDefaultNationNames = [
  'Crimson Empire',
  'Azure Kingdom',
  'Emerald Republic',
  'Amber Dynasty',
  'Violet Sultanate',
  'Cyan Federation',
  'Rose Confederation',
  'Iron Pact',
  'Golden Horde',
  'Jade Empire',
  'Scarlet Alliance',
  'Sapphire Union',
  'Verdant Republic',
  'Copper League',
  'Indigo Dominion',
  'Obsidian Order',
];

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 2 ▸ ENUMS
// ══════════════════════════════════════════════════════════════════════════════

enum TerrainType { plains, forest, mountain, water, desert, tundra }

enum Age {
  ancient,
  classical,
  medieval,
  renaissance,
  industrial,
  modern,
  information,
  future,
}

enum NationTier { settlement, village, town, city, metropolis, globalCapital }

enum VictoryType { military, economic, territorial, technological, diplomatic }

enum GamePhase { menu, lobby, playing, paused, ended }

enum ActionType {
  build,
  trainUnit,
  moveUnit,
  attack,
  research,
  endTurn,
  diplomacy,
  upgrade,
}

enum DiplomacyAction { ally, declareWar, makePeace, embargo }

enum BuildingCat { economic, military, defensive, technology, special }

enum WeatherType { clear, rain, storm, snow, fog }

extension WeatherTypeLabel on WeatherType {
  String get label => const {
    WeatherType.clear: 'Clear',
    WeatherType.rain: 'Rain',
    WeatherType.storm: 'Storm',
    WeatherType.snow: 'Snow',
    WeatherType.fog: 'Fog',
  }[this]!;
  String get icon => const {
    WeatherType.clear: '☀️',
    WeatherType.rain: '🌧️',
    WeatherType.storm: '⛈️',
    WeatherType.snow: '❄️',
    WeatherType.fog: '🌫️',
  }[this]!;
}

extension AgeLabel on Age {
  String get label => const {
    Age.ancient: 'Ancient Age',
    Age.classical: 'Classical Age',
    Age.medieval: 'Medieval Age',
    Age.renaissance: 'Renaissance Age',
    Age.industrial: 'Industrial Age',
    Age.modern: 'Modern Age',
    Age.information: 'Information Age',
    Age.future: 'Future Age',
  }[this]!;
  int get index2 => Age.values.indexOf(this);
}

extension NationTierLabel on NationTier {
  String get label => const {
    NationTier.settlement: 'Settlement',
    NationTier.village: 'Village',
    NationTier.town: 'Town',
    NationTier.city: 'City',
    NationTier.metropolis: 'Metropolis',
    NationTier.globalCapital: 'Global Capital',
  }[this]!;
  int get popCap => const {
    NationTier.settlement: 20,
    NationTier.village: 50,
    NationTier.town: 120,
    NationTier.city: 300,
    NationTier.metropolis: 750,
    NationTier.globalCapital: 2000,
  }[this]!;
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 3 ▸ RESOURCE MODEL
// ══════════════════════════════════════════════════════════════════════════════

class Resources {
  double gold;
  double food;
  double wood;
  double stone;
  double iron;
  double oil;
  int population;
  int populationCap;
  int researchPoints;

  Resources({
    this.gold = 200,
    this.food = 100,
    this.wood = 80,
    this.stone = 60,
    this.iron = 0,
    this.oil = 0,
    this.population = 5,
    this.populationCap = 20,
    this.researchPoints = 0,
  });

  bool canAfford(Map<String, double> cost) {
    return (cost['gold'] ?? 0) <= gold &&
        (cost['food'] ?? 0) <= food &&
        (cost['wood'] ?? 0) <= wood &&
        (cost['stone'] ?? 0) <= stone &&
        (cost['iron'] ?? 0) <= iron &&
        (cost['oil'] ?? 0) <= oil;
  }

  void spend(Map<String, double> cost) {
    gold -= cost['gold'] ?? 0;
    food -= cost['food'] ?? 0;
    wood -= cost['wood'] ?? 0;
    stone -= cost['stone'] ?? 0;
    iron -= cost['iron'] ?? 0;
    oil -= cost['oil'] ?? 0;
  }

  void add(Map<String, double> income) {
    gold = (gold + (income['gold'] ?? 0)).clamp(0, 99999);
    food = (food + (income['food'] ?? 0)).clamp(0, 99999);
    wood = (wood + (income['wood'] ?? 0)).clamp(0, 99999);
    stone = (stone + (income['stone'] ?? 0)).clamp(0, 99999);
    iron = (iron + (income['iron'] ?? 0)).clamp(0, 99999);
    oil = (oil + (income['oil'] ?? 0)).clamp(0, 99999);
  }

  Map<String, dynamic> toJson() => {
    'gold': gold,
    'food': food,
    'wood': wood,
    'stone': stone,
    'iron': iron,
    'oil': oil,
    'population': population,
    'populationCap': populationCap,
    'researchPoints': researchPoints,
  };

  factory Resources.fromJson(Map<String, dynamic> j) => Resources(
    gold: (j['gold'] ?? 0).toDouble(),
    food: (j['food'] ?? 0).toDouble(),
    wood: (j['wood'] ?? 0).toDouble(),
    stone: (j['stone'] ?? 0).toDouble(),
    iron: (j['iron'] ?? 0).toDouble(),
    oil: (j['oil'] ?? 0).toDouble(),
    population: j['population'] ?? 5,
    populationCap: j['populationCap'] ?? 20,
    researchPoints: j['researchPoints'] ?? 0,
  );

  Resources copy() => Resources(
    gold: gold,
    food: food,
    wood: wood,
    stone: stone,
    iron: iron,
    oil: oil,
    population: population,
    populationCap: populationCap,
    researchPoints: researchPoints,
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 4 ▸ BUILDING DEFINITIONS
// ══════════════════════════════════════════════════════════════════════════════

class BuildingDef {
  final String id, name, emoji, description;
  final BuildingCat category;
  final Map<String, double> cost;
  final Map<String, double> production; // per tick
  final int buildTicks, health;
  final Age requiredAge;
  final int? popCapBonus;
  final List<String> unlocks; // unit def IDs

  const BuildingDef({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.category,
    required this.cost,
    this.production = const {},
    required this.buildTicks,
    required this.health,
    this.requiredAge = Age.ancient,
    this.popCapBonus,
    this.unlocks = const [],
  });
}

final Map<String, BuildingDef> kBuildingDefs = {
  // ── ECONOMIC ─────────────────────────────────────────────
  'farm': BuildingDef(
    id: 'farm',
    name: 'Farm',
    emoji: '🌾',
    category: BuildingCat.economic,
    description: 'Produces food each tick.',
    cost: {'gold': 50, 'wood': 30},
    production: {'food': 4},
    buildTicks: 3,
    health: 80,
    popCapBonus: 10,
  ),
  'windmill': BuildingDef(
    id: 'windmill',
    name: 'Windmill',
    emoji: '🏭',
    category: BuildingCat.economic,
    description: 'Converts food surplus into gold.',
    cost: {'gold': 80, 'wood': 50, 'stone': 20},
    production: {'gold': 3, 'food': 2},
    buildTicks: 4,
    health: 100,
  ),
  'mine': BuildingDef(
    id: 'mine',
    name: 'Mine',
    emoji: '⛏️',
    category: BuildingCat.economic,
    description: 'Extracts stone and iron from mountains.',
    cost: {'gold': 100, 'wood': 40},
    production: {'stone': 3, 'iron': 1},
    buildTicks: 5,
    health: 120,
  ),
  'lumber_mill': BuildingDef(
    id: 'lumber_mill',
    name: 'Lumber Mill',
    emoji: '🪵',
    category: BuildingCat.economic,
    description: 'Processes wood efficiently.',
    cost: {'gold': 60, 'stone': 20},
    production: {'wood': 4},
    buildTicks: 3,
    health: 90,
  ),
  'market': BuildingDef(
    id: 'market',
    name: 'Market',
    emoji: '🏪',
    category: BuildingCat.economic,
    description: 'Generates gold from trade.',
    cost: {'gold': 120, 'wood': 60, 'stone': 40},
    production: {'gold': 6},
    buildTicks: 5,
    health: 100,
    popCapBonus: 5,
  ),
  'bank': BuildingDef(
    id: 'bank',
    name: 'Bank',
    emoji: '🏦',
    category: BuildingCat.economic,
    description: 'Advanced financial institution.',
    cost: {'gold': 300, 'stone': 100, 'iron': 50},
    production: {'gold': 12},
    buildTicks: 8,
    health: 150,
    requiredAge: Age.medieval,
  ),
  'oil_rig': BuildingDef(
    id: 'oil_rig',
    name: 'Oil Rig',
    emoji: '🛢️',
    category: BuildingCat.economic,
    description: 'Extracts oil for modern units.',
    cost: {'gold': 500, 'iron': 200, 'stone': 100},
    production: {'oil': 5, 'gold': 4},
    buildTicks: 10,
    health: 200,
    requiredAge: Age.industrial,
  ),

  // ── MILITARY ─────────────────────────────────────────────
  'barracks': BuildingDef(
    id: 'barracks',
    name: 'Barracks',
    emoji: '⚔️',
    category: BuildingCat.military,
    description: 'Trains basic land units.',
    cost: {'gold': 100, 'wood': 80, 'stone': 30},
    buildTicks: 5,
    health: 200,
    unlocks: ['spearman', 'builder', 'farmer'],
  ),
  'archery_range': BuildingDef(
    id: 'archery_range',
    name: 'Archery Range',
    emoji: '🏹',
    category: BuildingCat.military,
    description: 'Trains ranged units.',
    cost: {'gold': 120, 'wood': 100},
    buildTicks: 5,
    health: 180,
    unlocks: ['archer', 'crossbowman'],
  ),
  'stable': BuildingDef(
    id: 'stable',
    name: 'Stable',
    emoji: '🐴',
    category: BuildingCat.military,
    description: 'Trains cavalry units.',
    cost: {'gold': 150, 'wood': 80, 'food': 60},
    buildTicks: 6,
    health: 180,
    unlocks: ['scout_cavalry', 'knight'],
    requiredAge: Age.classical,
  ),
  'siege_workshop': BuildingDef(
    id: 'siege_workshop',
    name: 'Siege Workshop',
    emoji: '💣',
    category: BuildingCat.military,
    description: 'Builds siege engines.',
    cost: {'gold': 200, 'wood': 150, 'stone': 80},
    buildTicks: 8,
    health: 200,
    unlocks: ['catapult', 'trebuchet'],
    requiredAge: Age.medieval,
  ),
  'military_academy': BuildingDef(
    id: 'military_academy',
    name: 'Military Academy',
    emoji: '🎖️',
    category: BuildingCat.military,
    description: 'Trains elite modern soldiers.',
    cost: {'gold': 400, 'stone': 200, 'iron': 150},
    buildTicks: 10,
    health: 250,
    unlocks: ['rifleman', 'special_forces', 'engineer'],
    requiredAge: Age.industrial,
  ),
  'tank_factory': BuildingDef(
    id: 'tank_factory',
    name: 'Tank Factory',
    emoji: '🪖',
    category: BuildingCat.military,
    description: 'Produces armored vehicles.',
    cost: {'gold': 600, 'iron': 300, 'oil': 100},
    buildTicks: 12,
    health: 300,
    unlocks: ['tank', 'artillery'],
    requiredAge: Age.modern,
  ),
  'air_force_base': BuildingDef(
    id: 'air_force_base',
    name: 'Air Force Base',
    emoji: '✈️',
    category: BuildingCat.military,
    description: 'Fields aircraft and helicopters.',
    cost: {'gold': 800, 'iron': 400, 'oil': 200},
    buildTicks: 15,
    health: 350,
    unlocks: ['jet_fighter', 'attack_helicopter'],
    requiredAge: Age.modern,
  ),
  'naval_base': BuildingDef(
    id: 'naval_base',
    name: 'Naval Base',
    emoji: '⚓',
    category: BuildingCat.military,
    description: 'Builds warships and submarines.',
    cost: {'gold': 700, 'iron': 350, 'wood': 200},
    buildTicks: 14,
    health: 320,
    unlocks: ['destroyer', 'submarine'],
    requiredAge: Age.industrial,
  ),

  // ── DEFENSIVE ────────────────────────────────────────────
  'walls': BuildingDef(
    id: 'walls',
    name: 'Walls',
    emoji: '🧱',
    category: BuildingCat.defensive,
    description: 'Stone walls that fortify territory.',
    cost: {'stone': 80, 'gold': 40},
    buildTicks: 4,
    health: 500,
  ),
  'watchtower': BuildingDef(
    id: 'watchtower',
    name: 'Watchtower',
    emoji: '🗼',
    category: BuildingCat.defensive,
    description: 'Ranged defensive structure.',
    cost: {'wood': 60, 'stone': 40, 'gold': 50},
    buildTicks: 3,
    health: 200,
  ),
  'fortress': BuildingDef(
    id: 'fortress',
    name: 'Fortress',
    emoji: '🏰',
    category: BuildingCat.defensive,
    description: 'Powerful defensive stronghold.',
    cost: {'stone': 200, 'iron': 80, 'gold': 300},
    buildTicks: 12,
    health: 1000,
    requiredAge: Age.medieval,
    popCapBonus: 20,
  ),
  'cannon_tower': BuildingDef(
    id: 'cannon_tower',
    name: 'Cannon Tower',
    emoji: '💥',
    category: BuildingCat.defensive,
    description: 'Heavy artillery emplacement.',
    cost: {'iron': 150, 'stone': 100, 'gold': 400},
    buildTicks: 10,
    health: 400,
    requiredAge: Age.renaissance,
  ),
  'missile_defense': BuildingDef(
    id: 'missile_defense',
    name: 'Missile Defense',
    emoji: '🚀',
    category: BuildingCat.defensive,
    description: 'Intercepts air and missile attacks.',
    cost: {'gold': 1000, 'iron': 500, 'oil': 200},
    buildTicks: 20,
    health: 500,
    requiredAge: Age.modern,
  ),

  // ── TECHNOLOGY ───────────────────────────────────────────
  'research_center': BuildingDef(
    id: 'research_center',
    name: 'Research Center',
    emoji: '🔬',
    category: BuildingCat.technology,
    description: 'Generates research points per tick.',
    cost: {'gold': 200, 'stone': 100, 'wood': 80},
    production: {'research': 2},
    buildTicks: 7,
    health: 150,
    requiredAge: Age.classical,
  ),
  'university': BuildingDef(
    id: 'university',
    name: 'University',
    emoji: '🎓',
    category: BuildingCat.technology,
    description: 'Advanced research generation.',
    cost: {'gold': 400, 'stone': 200, 'iron': 50},
    production: {'research': 5},
    buildTicks: 10,
    health: 200,
    requiredAge: Age.medieval,
    popCapBonus: 10,
  ),
  'innovation_lab': BuildingDef(
    id: 'innovation_lab',
    name: 'Innovation Lab',
    emoji: '💡',
    category: BuildingCat.technology,
    description: 'Cutting-edge research facility.',
    cost: {'gold': 800, 'iron': 300, 'oil': 100},
    production: {'research': 10},
    buildTicks: 15,
    health: 300,
    requiredAge: Age.modern,
  ),

  // ── SPECIAL ──────────────────────────────────────────────
  'harbor': BuildingDef(
    id: 'harbor',
    name: 'Harbor',
    emoji: '🚢',
    category: BuildingCat.special,
    description: 'Enables naval trade and units.',
    cost: {'gold': 350, 'wood': 200, 'stone': 100},
    production: {'gold': 5},
    buildTicks: 8,
    health: 300,
    requiredAge: Age.classical,
    unlocks: ['trader'],
  ),
  'airport': BuildingDef(
    id: 'airport',
    name: 'Airport',
    emoji: '🛫',
    category: BuildingCat.special,
    description: 'Strategic transport hub.',
    cost: {'gold': 900, 'iron': 400, 'oil': 150},
    production: {'gold': 8},
    buildTicks: 18,
    health: 400,
    requiredAge: Age.modern,
  ),
  'nuclear_facility': BuildingDef(
    id: 'nuclear_facility',
    name: 'Nuclear Facility',
    emoji: '☢️',
    category: BuildingCat.special,
    description: 'Provides nuclear energy and weapons.',
    cost: {'gold': 2000, 'iron': 800, 'oil': 400},
    production: {'gold': 15, 'oil': 10},
    buildTicks: 30,
    health: 600,
    requiredAge: Age.information,
  ),
  'space_center': BuildingDef(
    id: 'space_center',
    name: 'Space Center',
    emoji: '🛸',
    category: BuildingCat.special,
    description: 'Required for technological victory.',
    cost: {'gold': 5000, 'iron': 2000, 'oil': 1000},
    production: {'research': 20, 'gold': 20},
    buildTicks: 50,
    health: 800,
    requiredAge: Age.future,
  ),
  'capital_fortress': BuildingDef(
    id: 'capital_fortress',
    name: 'Capital Fortress',
    emoji: '🏛️',
    category: BuildingCat.defensive,
    description: 'Your nation\'s beating heart. Losing it ends your game.',
    cost: {},
    buildTicks: 0,
    health: 2000,
    popCapBonus: 20,
  ),
};

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 5 ▸ UNIT DEFINITIONS
// ══════════════════════════════════════════════════════════════════════════════

class UnitDef {
  final String id, name, emoji;
  final bool isMilitary;
  final int health, attack, defense, speed, range;
  final Map<String, double> cost;
  final int trainTicks;
  final Age requiredAge;
  final String? requiredBuilding;

  const UnitDef({
    required this.id,
    required this.name,
    required this.emoji,
    this.isMilitary = false,
    required this.health,
    this.attack = 0,
    this.defense = 0,
    this.speed = 1,
    this.range = 1,
    required this.cost,
    required this.trainTicks,
    this.requiredAge = Age.ancient,
    this.requiredBuilding,
  });
}

final Map<String, UnitDef> kUnitDefs = {
  // ── CIVILIAN ─────────────────────────────────────────────
  'builder': UnitDef(
    id: 'builder',
    name: 'Builder',
    emoji: '👷',
    health: 40,
    defense: 1,
    speed: 2,
    cost: {'gold': 50, 'food': 20},
    trainTicks: 3,
    requiredBuilding: 'barracks',
  ),
  'engineer': UnitDef(
    id: 'engineer',
    name: 'Engineer',
    emoji: '🔧',
    health: 50,
    defense: 2,
    speed: 2,
    cost: {'gold': 100, 'food': 30, 'iron': 10},
    trainTicks: 5,
    requiredAge: Age.industrial,
    requiredBuilding: 'military_academy',
  ),
  'farmer': UnitDef(
    id: 'farmer',
    name: 'Farmer',
    emoji: '🧑‍🌾',
    health: 30,
    defense: 0,
    speed: 1,
    cost: {'gold': 30, 'food': 10},
    trainTicks: 2,
    requiredBuilding: 'barracks',
  ),
  'trader': UnitDef(
    id: 'trader',
    name: 'Trader',
    emoji: '🧑‍💼',
    health: 35,
    defense: 0,
    speed: 3,
    cost: {'gold': 80, 'food': 20},
    trainTicks: 4,
    requiredBuilding: 'harbor',
  ),
  'repair_specialist': UnitDef(
    id: 'repair_specialist',
    name: 'Repair Specialist',
    emoji: '🛠️',
    health: 45,
    defense: 2,
    speed: 2,
    cost: {'gold': 120, 'iron': 30},
    trainTicks: 5,
    requiredAge: Age.industrial,
    requiredBuilding: 'military_academy',
  ),

  // ── ANCIENT ──────────────────────────────────────────────
  'spearman': UnitDef(
    id: 'spearman',
    name: 'Spearman',
    emoji: '🗡️',
    isMilitary: true,
    health: 80,
    attack: 15,
    defense: 8,
    speed: 2,
    cost: {'gold': 60, 'food': 30, 'wood': 10},
    trainTicks: 3,
    requiredBuilding: 'barracks',
  ),
  'archer': UnitDef(
    id: 'archer',
    name: 'Archer',
    emoji: '🏹',
    isMilitary: true,
    health: 60,
    attack: 18,
    defense: 5,
    speed: 2,
    range: 3,
    cost: {'gold': 70, 'wood': 30, 'food': 20},
    trainTicks: 3,
    requiredBuilding: 'archery_range',
  ),
  'scout_cavalry': UnitDef(
    id: 'scout_cavalry',
    name: 'Scout Cavalry',
    emoji: '🐎',
    isMilitary: true,
    health: 70,
    attack: 12,
    defense: 6,
    speed: 4,
    cost: {'gold': 80, 'food': 40},
    trainTicks: 4,
    requiredAge: Age.classical,
    requiredBuilding: 'stable',
  ),

  // ── MEDIEVAL ─────────────────────────────────────────────
  'knight': UnitDef(
    id: 'knight',
    name: 'Knight',
    emoji: '🛡️',
    isMilitary: true,
    health: 120,
    attack: 28,
    defense: 22,
    speed: 3,
    cost: {'gold': 150, 'iron': 50, 'food': 40},
    trainTicks: 6,
    requiredAge: Age.medieval,
    requiredBuilding: 'stable',
  ),
  'crossbowman': UnitDef(
    id: 'crossbowman',
    name: 'Crossbowman',
    emoji: '🎯',
    isMilitary: true,
    health: 70,
    attack: 28,
    defense: 8,
    speed: 2,
    range: 4,
    cost: {'gold': 120, 'iron': 30, 'wood': 40},
    trainTicks: 5,
    requiredAge: Age.medieval,
    requiredBuilding: 'archery_range',
  ),
  'catapult': UnitDef(
    id: 'catapult',
    name: 'Catapult',
    emoji: '💣',
    isMilitary: true,
    health: 80,
    attack: 45,
    defense: 4,
    speed: 1,
    range: 5,
    cost: {'gold': 200, 'wood': 150, 'stone': 60},
    trainTicks: 8,
    requiredAge: Age.medieval,
    requiredBuilding: 'siege_workshop',
  ),
  'trebuchet': UnitDef(
    id: 'trebuchet',
    name: 'Trebuchet',
    emoji: '🏹',
    isMilitary: true,
    health: 90,
    attack: 65,
    defense: 3,
    speed: 1,
    range: 6,
    cost: {'gold': 300, 'wood': 200, 'stone': 100},
    trainTicks: 10,
    requiredAge: Age.renaissance,
    requiredBuilding: 'siege_workshop',
  ),

  // ── INDUSTRIAL ───────────────────────────────────────────
  'rifleman': UnitDef(
    id: 'rifleman',
    name: 'Rifleman',
    emoji: '💂',
    isMilitary: true,
    health: 100,
    attack: 40,
    defense: 15,
    speed: 2,
    range: 3,
    cost: {'gold': 180, 'iron': 60, 'food': 30},
    trainTicks: 5,
    requiredAge: Age.industrial,
    requiredBuilding: 'military_academy',
  ),
  'artillery': UnitDef(
    id: 'artillery',
    name: 'Artillery',
    emoji: '🎖️',
    isMilitary: true,
    health: 110,
    attack: 75,
    defense: 10,
    speed: 1,
    range: 6,
    cost: {'gold': 350, 'iron': 150, 'oil': 20},
    trainTicks: 10,
    requiredAge: Age.industrial,
    requiredBuilding: 'tank_factory',
  ),
  'tank': UnitDef(
    id: 'tank',
    name: 'Tank',
    emoji: '🪖',
    isMilitary: true,
    health: 200,
    attack: 80,
    defense: 50,
    speed: 3,
    cost: {'gold': 500, 'iron': 200, 'oil': 50},
    trainTicks: 12,
    requiredAge: Age.modern,
    requiredBuilding: 'tank_factory',
  ),

  // ── MODERN ───────────────────────────────────────────────
  'special_forces': UnitDef(
    id: 'special_forces',
    name: 'Special Forces',
    emoji: '🔱',
    isMilitary: true,
    health: 150,
    attack: 90,
    defense: 40,
    speed: 4,
    cost: {'gold': 600, 'iron': 150, 'oil': 60},
    trainTicks: 10,
    requiredAge: Age.modern,
    requiredBuilding: 'military_academy',
  ),
  'attack_helicopter': UnitDef(
    id: 'attack_helicopter',
    name: 'Attack Helicopter',
    emoji: '🚁',
    isMilitary: true,
    health: 160,
    attack: 100,
    defense: 30,
    speed: 6,
    range: 4,
    cost: {'gold': 800, 'iron': 300, 'oil': 120},
    trainTicks: 14,
    requiredAge: Age.modern,
    requiredBuilding: 'air_force_base',
  ),
  'jet_fighter': UnitDef(
    id: 'jet_fighter',
    name: 'Jet Fighter',
    emoji: '✈️',
    isMilitary: true,
    health: 140,
    attack: 120,
    defense: 25,
    speed: 8,
    range: 5,
    cost: {'gold': 1000, 'iron': 400, 'oil': 200},
    trainTicks: 16,
    requiredAge: Age.modern,
    requiredBuilding: 'air_force_base',
  ),
  'destroyer': UnitDef(
    id: 'destroyer',
    name: 'Destroyer',
    emoji: '🚢',
    isMilitary: true,
    health: 250,
    attack: 95,
    defense: 60,
    speed: 4,
    range: 5,
    cost: {'gold': 900, 'iron': 350, 'oil': 150},
    trainTicks: 18,
    requiredAge: Age.industrial,
    requiredBuilding: 'naval_base',
  ),
  'submarine': UnitDef(
    id: 'submarine',
    name: 'Submarine',
    emoji: '🔱',
    isMilitary: true,
    health: 200,
    attack: 140,
    defense: 50,
    speed: 3,
    range: 6,
    cost: {'gold': 1200, 'iron': 500, 'oil': 250},
    trainTicks: 20,
    requiredAge: Age.modern,
    requiredBuilding: 'naval_base',
  ),
};

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 6 ▸ TECHNOLOGY DEFINITIONS
// ══════════════════════════════════════════════════════════════════════════════

class TechDef {
  final String id, name, emoji, description;
  final Age era;
  final int cost;
  final List<String> prerequisites;
  final Map<String, double> bonuses; // 'gold_production', 'unit_attack', etc.

  const TechDef({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.era,
    required this.cost,
    this.prerequisites = const [],
    this.bonuses = const {},
  });
}

final Map<String, TechDef> kTechDefs = {
  // ANCIENT
  'pottery': TechDef(
    id: 'pottery',
    name: 'Pottery',
    emoji: '🏺',
    description: 'Increases food storage capacity.',
    era: Age.ancient,
    cost: 50,
    bonuses: {'food_storage': 0.5},
  ),
  'bronze_working': TechDef(
    id: 'bronze_working',
    name: 'Bronze Working',
    emoji: '🔨',
    description: '+10% unit attack.',
    era: Age.ancient,
    cost: 80,
    bonuses: {'unit_attack': 0.10},
  ),
  'agriculture': TechDef(
    id: 'agriculture',
    name: 'Agriculture',
    emoji: '🌿',
    description: '+30% farm production.',
    era: Age.ancient,
    cost: 60,
    bonuses: {'farm_prod': 0.30},
  ),
  'masonry': TechDef(
    id: 'masonry',
    name: 'Masonry',
    emoji: '🧱',
    description: '+50% building health.',
    era: Age.ancient,
    cost: 70,
    bonuses: {'building_hp': 0.50},
  ),
  // CLASSICAL
  'iron_working': TechDef(
    id: 'iron_working',
    name: 'Iron Working',
    emoji: '⚒️',
    description: '+20% military unit attack.',
    era: Age.classical,
    cost: 120,
    bonuses: {'unit_attack': 0.20},
  ),
  'philosophy': TechDef(
    id: 'philosophy',
    name: 'Philosophy',
    emoji: '📜',
    description: '+50% research generation.',
    era: Age.classical,
    cost: 100,
    bonuses: {'research_prod': 0.50},
  ),
  'trade_routes': TechDef(
    id: 'trade_routes',
    name: 'Trade Routes',
    emoji: '🛒',
    description: '+40% market and harbor gold.',
    era: Age.classical,
    cost: 110,
    bonuses: {'market_gold': 0.40},
  ),
  // MEDIEVAL
  'steel': TechDef(
    id: 'steel',
    name: 'Steel',
    emoji: '🗡️',
    description: '+25% military attack and defense.',
    era: Age.medieval,
    cost: 180,
    bonuses: {'unit_attack': 0.25, 'unit_defense': 0.25},
  ),
  'gunpowder': TechDef(
    id: 'gunpowder',
    name: 'Gunpowder',
    emoji: '💥',
    description: 'Unlocks siege units.',
    era: Age.medieval,
    cost: 200,
    bonuses: {},
  ),
  'chivalry': TechDef(
    id: 'chivalry',
    name: 'Chivalry',
    emoji: '🛡️',
    description: '+40% cavalry unit stats.',
    era: Age.medieval,
    cost: 160,
    bonuses: {'cavalry_attack': 0.40},
  ),
  // RENAISSANCE
  'banking': TechDef(
    id: 'banking',
    name: 'Banking',
    emoji: '💰',
    description: '+60% gold generation.',
    era: Age.renaissance,
    cost: 250,
    bonuses: {'gold_prod': 0.60},
  ),
  'astronomy': TechDef(
    id: 'astronomy',
    name: 'Astronomy',
    emoji: '🌟',
    description: '+2 unit range globally.',
    era: Age.renaissance,
    cost: 220,
    bonuses: {'unit_range': 2},
  ),
  'printing_press': TechDef(
    id: 'printing_press',
    name: 'Printing Press',
    emoji: '📰',
    description: '+80% research generation.',
    era: Age.renaissance,
    cost: 280,
    bonuses: {'research_prod': 0.80},
  ),
  // INDUSTRIAL
  'steam_power': TechDef(
    id: 'steam_power',
    name: 'Steam Power',
    emoji: '⚙️',
    description: '+30% production speed.',
    era: Age.industrial,
    cost: 350,
    bonuses: {'build_speed': 0.30},
  ),
  'rifling': TechDef(
    id: 'rifling',
    name: 'Rifling',
    emoji: '🔫',
    description: '+35% ranged unit attack.',
    era: Age.industrial,
    cost: 380,
    bonuses: {'ranged_attack': 0.35},
  ),
  'combustion': TechDef(
    id: 'combustion',
    name: 'Combustion',
    emoji: '🔥',
    description: 'Unlocks oil extraction and tanks.',
    era: Age.industrial,
    cost: 400,
    bonuses: {},
  ),
  // MODERN
  'electronics': TechDef(
    id: 'electronics',
    name: 'Electronics',
    emoji: '💻',
    description: '+50% research generation.',
    era: Age.modern,
    cost: 500,
    bonuses: {'research_prod': 0.50},
  ),
  'nuclear_fission': TechDef(
    id: 'nuclear_fission',
    name: 'Nuclear Fission',
    emoji: '☢️',
    description: 'Unlocks nuclear facility.',
    era: Age.modern,
    cost: 800,
    bonuses: {},
  ),
  'aviation': TechDef(
    id: 'aviation',
    name: 'Aviation',
    emoji: '✈️',
    description: 'Unlocks air units.',
    era: Age.modern,
    cost: 600,
    bonuses: {},
  ),
  // INFORMATION
  'stealth': TechDef(
    id: 'stealth',
    name: 'Stealth Tech',
    emoji: '👁️',
    description: '+25% special forces stats.',
    era: Age.information,
    cost: 700,
    bonuses: {'special_attack': 0.25},
  ),
  'ai_systems': TechDef(
    id: 'ai_systems',
    name: 'AI Systems',
    emoji: '🤖',
    description: '+100% research generation.',
    era: Age.information,
    cost: 1000,
    bonuses: {'research_prod': 1.0},
  ),
  // FUTURE
  'fusion_power': TechDef(
    id: 'fusion_power',
    name: 'Fusion Power',
    emoji: '⚡',
    description: 'All production +100%.',
    era: Age.future,
    cost: 2000,
    bonuses: {'all_prod': 1.0},
  ),
  'quantum_computing': TechDef(
    id: 'quantum_computing',
    name: 'Quantum Computing',
    emoji: '🔮',
    description: 'Required for tech victory.',
    era: Age.future,
    cost: 3000,
    bonuses: {'research_prod': 2.0},
  ),
  'space_colonization': TechDef(
    id: 'space_colonization',
    name: 'Space Colonization',
    emoji: '🛸',
    description: 'Final step: tech victory.',
    era: Age.future,
    cost: 5000,
    prerequisites: ['quantum_computing', 'fusion_power'],
    bonuses: {},
  ),
};

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 7 ▸ MAP & TILE MODELS
// ══════════════════════════════════════════════════════════════════════════════

class MapTile {
  final int x, y;
  TerrainType terrain;
  String? ownerNationId;
  String? buildingId;
  final List<String> unitIds;

  MapTile({
    required this.x,
    required this.y,
    this.terrain = TerrainType.plains,
    this.ownerNationId,
    this.buildingId,
    List<String>? unitIds,
  }) : unitIds = unitIds ?? [];

  Color get baseColor {
    switch (terrain) {
      case TerrainType.plains:
        return const Color(0xFF2D5A27);
      case TerrainType.forest:
        return const Color(0xFF1B3A1B);
      case TerrainType.mountain:
        return const Color(0xFF5C4033);
      case TerrainType.water:
        return const Color(0xFF0D3B6B);
      case TerrainType.desert:
        return const Color(0xFF8B6914);
      case TerrainType.tundra:
        return const Color(0xFF4A5568);
    }
  }

  String get emoji {
    switch (terrain) {
      case TerrainType.plains:
        return '🌿';
      case TerrainType.forest:
        return '🌲';
      case TerrainType.mountain:
        return '⛰️';
      case TerrainType.water:
        return '🌊';
      case TerrainType.desert:
        return '🏜️';
      case TerrainType.tundra:
        return '❄️';
    }
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'terrain': terrain.name,
    'owner': ownerNationId,
    'building': buildingId,
    'units': unitIds,
  };

  factory MapTile.fromJson(Map<String, dynamic> j) => MapTile(
    x: j['x'],
    y: j['y'],
    terrain: TerrainType.values.firstWhere(
      (t) => t.name == j['terrain'],
      orElse: () => TerrainType.plains,
    ),
    ownerNationId: j['owner'],
    buildingId: j['building'],
    unitIds: List<String>.from(j['units'] ?? []),
  );
}

class GameMap {
  final int width, height;
  final List<List<MapTile>> tiles;

  GameMap({this.width = kMapW, this.height = kMapH})
    : tiles = List.generate(
        kMapH,
        (y) => List.generate(kMapW, (x) => MapTile(x: x, y: y)),
      );

  MapTile at(int x, int y) => tiles[y][x];
  bool isValid(int x, int y) => x >= 0 && x < width && y >= 0 && y < height;

  List<MapTile> neighbors(int x, int y) {
    final res = <MapTile>[];
    for (final d in [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ]) {
      final nx = x + d[0], ny = y + d[1];
      if (isValid(nx, ny)) res.add(at(nx, ny));
    }
    return res;
  }

  List<MapTile> inRange(int x, int y, int r) {
    final res = <MapTile>[];
    for (int dy = -r; dy <= r; dy++) {
      for (int dx = -r; dx <= r; dx++) {
        if (dx == 0 && dy == 0) continue;
        final dist = dx.abs() + dy.abs();
        if (dist <= r && isValid(x + dx, y + dy)) res.add(at(x + dx, y + dy));
      }
    }
    return res;
  }

  void generate(int seed, int nationCount) {
    final rng = math.Random(seed);

    // Fill with plains first
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        tiles[y][x].terrain = TerrainType.plains;
      }
    }

    // Water blobs (edges + random interior)
    _placeTerrain(
      rng,
      TerrainType.water,
      (width * height * 0.18).round(),
      minSize: 4,
      maxSize: 12,
    );
    _placeTerrain(
      rng,
      TerrainType.forest,
      (width * height * 0.18).round(),
      minSize: 3,
      maxSize: 8,
    );
    _placeTerrain(
      rng,
      TerrainType.mountain,
      (width * height * 0.10).round(),
      minSize: 2,
      maxSize: 6,
    );
    _placeTerrain(
      rng,
      TerrainType.desert,
      (width * height * 0.08).round(),
      minSize: 3,
      maxSize: 7,
    );
    _placeTerrain(
      rng,
      TerrainType.tundra,
      (width * height * 0.06).round(),
      minSize: 2,
      maxSize: 5,
    );
  }

  void _placeTerrain(
    math.Random rng,
    TerrainType t,
    int count, {
    required int minSize,
    required int maxSize,
  }) {
    int placed = 0;
    int attempts = 0;
    while (placed < count && attempts < count * 10) {
      attempts++;
      int cx = rng.nextInt(width), cy = rng.nextInt(height);
      final size = minSize + rng.nextInt(maxSize - minSize + 1);
      int thisBatch = 0;
      final queue = [MapTile(x: cx, y: cy)];
      final visited = <String>{};
      while (queue.isNotEmpty && thisBatch < size) {
        final current = queue.removeAt(0);
        final key = '${current.x},${current.y}';
        if (visited.contains(key)) continue;
        visited.add(key);
        if (!isValid(current.x, current.y)) continue;
        tiles[current.y][current.x].terrain = t;
        thisBatch++;
        placed++;
        final ns = neighbors(current.x, current.y)..shuffle(rng);
        queue.addAll(ns.take(2));
      }
    }
  }

  List<List<int>> getSpawnPositions(int count, math.Random rng) {
    final positions = <List<int>>[];
    final cellW =
        width ~/
        (count <= 4
            ? 2
            : count <= 8
            ? 4
            : 4);
    final cellH =
        height ~/
        (count <= 4
            ? 2
            : count <= 8
            ? 2
            : 4);

    for (int i = 0; i < count; i++) {
      int cx = (i % (width ~/ cellW)) * cellW + cellW ~/ 2;
      int cy = (i ~/ (width ~/ cellW)) * cellH + cellH ~/ 2;
      // Find nearest non-water tile
      for (int r = 0; r < 10; r++) {
        bool found = false;
        for (int dy = -r; dy <= r && !found; dy++) {
          for (int dx = -r; dx <= r && !found; dx++) {
            final nx = cx + dx, ny = cy + dy;
            if (isValid(nx, ny) && at(nx, ny).terrain != TerrainType.water) {
              cx = nx;
              cy = ny;
              found = true;
            }
          }
        }
        if (found) break;
      }
      positions.add([cx, cy]);
    }
    return positions;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 8 ▸ GAME ENTITY MODELS
// ══════════════════════════════════════════════════════════════════════════════

class Building {
  String id, defId, nationId;
  int x, y, health, maxHealth, buildTicksLeft;
  bool isConstructing;
  String? trainingUnitDefId;
  int trainingTicksLeft;

  Building({
    required this.id,
    required this.defId,
    required this.nationId,
    required this.x,
    required this.y,
    required this.health,
    required this.maxHealth,
    this.buildTicksLeft = 0,
    this.isConstructing = false,
    this.trainingUnitDefId,
    this.trainingTicksLeft = 0,
  });

  BuildingDef get def => kBuildingDefs[defId]!;

  Map<String, dynamic> toJson() => {
    'id': id,
    'defId': defId,
    'nationId': nationId,
    'x': x,
    'y': y,
    'health': health,
    'maxHealth': maxHealth,
    'buildTicksLeft': buildTicksLeft,
    'isConstructing': isConstructing,
    'trainingUnitDefId': trainingUnitDefId,
    'trainingTicksLeft': trainingTicksLeft,
  };

  factory Building.fromJson(Map<String, dynamic> j) => Building(
    id: j['id'],
    defId: j['defId'],
    nationId: j['nationId'],
    x: j['x'],
    y: j['y'],
    health: j['health'],
    maxHealth: j['maxHealth'],
    buildTicksLeft: j['buildTicksLeft'] ?? 0,
    isConstructing: j['isConstructing'] ?? false,
    trainingUnitDefId: j['trainingUnitDefId'],
    trainingTicksLeft: j['trainingTicksLeft'] ?? 0,
  );
}

class GameUnit {
  String id, defId, nationId;
  int x, y, health, maxHealth;
  bool hasMoved, hasAttacked;
  int movesLeft;

  GameUnit({
    required this.id,
    required this.defId,
    required this.nationId,
    required this.x,
    required this.y,
    required this.health,
    required this.maxHealth,
    this.hasMoved = false,
    this.hasAttacked = false,
    this.movesLeft = 0,
  });

  UnitDef get def => kUnitDefs[defId]!;

  Map<String, dynamic> toJson() => {
    'id': id,
    'defId': defId,
    'nationId': nationId,
    'x': x,
    'y': y,
    'health': health,
    'maxHealth': maxHealth,
    'hasMoved': hasMoved,
    'hasAttacked': hasAttacked,
    'movesLeft': movesLeft,
  };

  factory GameUnit.fromJson(Map<String, dynamic> j) => GameUnit(
    id: j['id'],
    defId: j['defId'],
    nationId: j['nationId'],
    x: j['x'],
    y: j['y'],
    health: j['health'],
    maxHealth: j['maxHealth'],
    hasMoved: j['hasMoved'] ?? false,
    hasAttacked: j['hasAttacked'] ?? false,
    movesLeft: j['movesLeft'] ?? 0,
  );
}

class ResearchProject {
  final String techId;
  double progress; // 0.0 – 1.0
  bool completed;

  ResearchProject({
    required this.techId,
    this.progress = 0,
    this.completed = false,
  });

  Map<String, dynamic> toJson() => {
    'techId': techId,
    'progress': progress,
    'completed': completed,
  };
  factory ResearchProject.fromJson(Map<String, dynamic> j) => ResearchProject(
    techId: j['techId'],
    progress: (j['progress'] ?? 0).toDouble(),
    completed: j['completed'] ?? false,
  );
}

class DiplomacyState {
  String otherId;
  bool isAllied, atWar;
  int treaties; // bitmask

  DiplomacyState({
    required this.otherId,
    this.isAllied = false,
    this.atWar = false,
    this.treaties = 0,
  });

  Map<String, dynamic> toJson() => {
    'otherId': otherId,
    'isAllied': isAllied,
    'atWar': atWar,
    'treaties': treaties,
  };
  factory DiplomacyState.fromJson(Map<String, dynamic> j) => DiplomacyState(
    otherId: j['otherId'],
    isAllied: j['isAllied'] ?? false,
    atWar: j['atWar'] ?? false,
    treaties: j['treaties'] ?? 0,
  );
}

class Nation {
  String id, name;
  Color color;
  bool isAI, isAlive, isPlayer;

  Resources resources;
  NationTier tier;
  Age currentAge;

  Set<String> ownedTiles; // "x,y"
  List<String> buildingIds;
  List<String> unitIds;

  String? capitalBuildingId;
  int capitalX, capitalY;

  Map<String, ResearchProject> research;
  String? activeResearchId;

  Map<String, DiplomacyState> diplomacy;

  // Stats
  int economyScore = 0, militaryScore = 0, influenceScore = 0;
  int economicVictoryTicks = 0;
  int techVictoryProgress = 0; // 0-100

  // AI
  String aiStrategy = 'balanced';
  int aiTick = 0;

  // Chat / log
  List<String> eventLog = [];

  Nation({
    required this.id,
    required this.name,
    required this.color,
    this.isAI = false,
    this.isAlive = true,
    this.isPlayer = false,
    required this.capitalX,
    required this.capitalY,
    Resources? resources,
    this.tier = NationTier.settlement,
    this.currentAge = Age.ancient,
    Set<String>? ownedTiles,
    List<String>? buildingIds,
    List<String>? unitIds,
    Map<String, ResearchProject>? research,
    Map<String, DiplomacyState>? diplomacy,
    this.capitalBuildingId,
  }) : resources = resources ?? Resources(),
       ownedTiles = ownedTiles ?? {},
       buildingIds = buildingIds ?? [],
       unitIds = unitIds ?? [],
       research = research ?? {},
       diplomacy = diplomacy ?? {};

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color.toARGB32(),
    'isAI': isAI,
    'isAlive': isAlive,
    'isPlayer': isPlayer,
    'resources': resources.toJson(),
    'tier': tier.name,
    'currentAge': currentAge.name,
    'ownedTiles': ownedTiles.toList(),
    'buildingIds': buildingIds,
    'unitIds': unitIds,
    'capitalBuildingId': capitalBuildingId,
    'capitalX': capitalX,
    'capitalY': capitalY,
    'research': research.map((k, v) => MapEntry(k, v.toJson())),
    'activeResearchId': activeResearchId,
    'diplomacy': diplomacy.map((k, v) => MapEntry(k, v.toJson())),
    'economyScore': economyScore,
    'militaryScore': militaryScore,
    'influenceScore': influenceScore,
    'economicVictoryTicks': economicVictoryTicks,
    'aiStrategy': aiStrategy,
  };

  factory Nation.fromJson(Map<String, dynamic> j) {
    final n = Nation(
      id: j['id'],
      name: j['name'],
      color: Color(j['color']),
      isAI: j['isAI'] ?? false,
      isAlive: j['isAlive'] ?? true,
      isPlayer: j['isPlayer'] ?? false,
      resources: Resources.fromJson(j['resources']),
      capitalX: j['capitalX'] ?? 0,
      capitalY: j['capitalY'] ?? 0,
      capitalBuildingId: j['capitalBuildingId'],
    );
    n.tier = NationTier.values.firstWhere(
      (t) => t.name == j['tier'],
      orElse: () => NationTier.settlement,
    );
    n.currentAge = Age.values.firstWhere(
      (a) => a.name == j['currentAge'],
      orElse: () => Age.ancient,
    );
    n.ownedTiles = Set<String>.from(j['ownedTiles'] ?? []);
    n.buildingIds = List<String>.from(j['buildingIds'] ?? []);
    n.unitIds = List<String>.from(j['unitIds'] ?? []);
    n.activeResearchId = j['activeResearchId'];
    n.economyScore = j['economyScore'] ?? 0;
    n.militaryScore = j['militaryScore'] ?? 0;
    n.influenceScore = j['influenceScore'] ?? 0;
    n.economicVictoryTicks = j['economicVictoryTicks'] ?? 0;
    n.aiStrategy = j['aiStrategy'] ?? 'balanced';
    if (j['research'] != null) {
      (j['research'] as Map).forEach((k, v) {
        n.research[k] = ResearchProject.fromJson(v);
      });
    }
    if (j['diplomacy'] != null) {
      (j['diplomacy'] as Map).forEach((k, v) {
        n.diplomacy[k] = DiplomacyState.fromJson(v);
      });
    }
    return n;
  }

  bool hasCompletedTech(String techId) => research[techId]?.completed == true;

  bool hasBuilding(String defId, Map<String, Building> buildings) =>
      buildingIds.any((id) => buildings[id]?.defId == defId);

  void addTile(int x, int y) => ownedTiles.add('$x,$y');
  void removeTile(int x, int y) => ownedTiles.remove('$x,$y');
  bool ownsTile(int x, int y) => ownedTiles.contains('$x,$y');
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 9 ▸ LOBBY MODEL
// ══════════════════════════════════════════════════════════════════════════════

class LobbyPlayer {
  String id, name, nationName;
  Color nationColor;
  bool ready;

  LobbyPlayer({
    required this.id,
    required this.name,
    required this.nationName,
    required this.nationColor,
    this.ready = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nationName': nationName,
    'nationColor': nationColor.toARGB32(),
    'ready': ready,
  };

  factory LobbyPlayer.fromJson(Map<String, dynamic> j) => LobbyPlayer(
    id: j['id'],
    name: j['name'],
    nationName: j['nationName'],
    nationColor: Color(j['nationColor']),
    ready: j['ready'] ?? false,
  );
}

class GameRoom {
  String id, name, hostId, gameMode;
  int maxPlayers;
  List<LobbyPlayer> players;
  bool started;
  int seed;

  GameRoom({
    required this.id,
    required this.name,
    required this.hostId,
    this.gameMode = 'ffa',
    this.maxPlayers = 8,
    List<LobbyPlayer>? players,
    this.started = false,
    this.seed = 0,
  }) : players = players ?? [];
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 10 ▸ GAME STATE
// ══════════════════════════════════════════════════════════════════════════════

class GameEvent {
  final String message;
  final Color color;
  final DateTime time;
  GameEvent(this.message, {this.color = kColorText}) : time = DateTime.now();
}

class CombatEffect {
  final int x, y;
  final int damage;
  final bool isCrit;
  final bool isKill;
  final Color color;
  final DateTime spawned;
  CombatEffect({
    required this.x,
    required this.y,
    required this.damage,
    this.isCrit = false,
    this.isKill = false,
    this.color = kColorAccent,
  }) : spawned = DateTime.now();
}

class GameState extends ChangeNotifier {
  // Core data
  String gameId = '';
  GameMap map = GameMap();
  Map<String, Nation> nations = {};
  Map<String, Building> buildings = {};
  Map<String, GameUnit> units = {};
  GamePhase phase = GamePhase.menu;
  int tick = 0;
  WeatherType currentWeather = WeatherType.clear;

  // Player
  String? playerNationId;
  String? localPlayerId;

  // Victory
  VictoryType? victoryType;
  String? winnerNationId;

  // Selection
  int? selX, selY;
  String? selUnitId, selBuildingId;
  String? pendingBuildDefId;
  List<List<int>> moveHighlights = [];
  List<List<int>> attackHighlights = [];

  // Multi-select
  Set<String> selectedUnitIds = {};

  // Pathfinding preview
  List<List<int>> pendingPath = [];

  // Combat effects (floating damage numbers)
  List<CombatEffect> combatEffects = [];

  // Chat & events
  List<GameEvent> events = [];
  List<Map<String, String>> chatMessages = [];

  // Unique ID counter
  int _nextId = 0;
  String _uid(String prefix) => '${prefix}_${_nextId++}';

  // ── Initialise single player ──────────────────────────────
  void initSinglePlayer({
    required int aiCount,
    required int difficulty,
    required int seed,
    required String playerNationName,
    required Color playerColor,
  }) {
    gameId = 'sp_${DateTime.now().millisecondsSinceEpoch}';
    tick = 0;
    nations.clear();
    buildings.clear();
    units.clear();
    events.clear();
    chatMessages.clear();
    phase = GamePhase.playing;

    map = GameMap();
    map.generate(seed, aiCount + 1);

    final rng = math.Random(seed);
    final spawnPositions = map.getSpawnPositions(aiCount + 1, rng);

    // Player nation
    final playerId = 'n_0';
    playerNationId = playerId;
    _spawnNation(
      id: playerId,
      name: playerNationName,
      color: playerColor,
      isAI: false,
      isPlayer: true,
      x: spawnPositions[0][0],
      y: spawnPositions[0][1],
    );

    // AI nations
    for (int i = 0; i < aiCount; i++) {
      final idx = i + 1;
      final colorIdx = idx % kNationColors.length;
      final strategies = [
        'military',
        'economic',
        'expansion',
        'technology',
        'balanced',
      ];
      final n = _spawnNation(
        id: 'n_$idx',
        name: kDefaultNationNames[idx % kDefaultNationNames.length],
        color: kNationColors[colorIdx],
        isAI: true,
        isPlayer: false,
        x: spawnPositions[idx][0],
        y: spawnPositions[idx][1],
      );
      n.aiStrategy = strategies[rng.nextInt(strategies.length)];
    }

    addEvent(
      '🌍 Global Dominion begins! Build your empire.',
      color: kColorGold,
    );
    notifyListeners();
  }

  Nation _spawnNation({
    required String id,
    required String name,
    required Color color,
    required bool isAI,
    required bool isPlayer,
    required int x,
    required int y,
  }) {
    final nation = Nation(
      id: id,
      name: name,
      color: color,
      isAI: isAI,
      isPlayer: isPlayer,
      capitalX: x,
      capitalY: y,
    );

    // Claim starting territory (3x3)
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        final nx = x + dx, ny = y + dy;
        if (map.isValid(nx, ny) &&
            map.at(nx, ny).terrain != TerrainType.water) {
          map.at(nx, ny).ownerNationId = id;
          nation.addTile(nx, ny);
        }
      }
    }

    // Place capital
    final cap = Building(
      id: _uid('b'),
      defId: 'capital_fortress',
      nationId: id,
      x: x,
      y: y,
      health: kBuildingDefs['capital_fortress']!.health,
      maxHealth: kBuildingDefs['capital_fortress']!.health,
    );
    buildings[cap.id] = cap;
    nation.capitalBuildingId = cap.id;
    nation.buildingIds.add(cap.id);
    map.at(x, y).buildingId = cap.id;

    // Starting units
    for (int i = 0; i < 3; i++) {
      final sx =
          x +
          (i == 0
              ? 1
              : i == 1
              ? -1
              : 0);
      final sy = y + (i == 2 ? 1 : 0);
      if (map.isValid(sx, sy) && map.at(sx, sy).terrain != TerrainType.water) {
        _spawnUnit(defId: 'builder', nationId: id, x: sx, y: sy);
      }
    }
    _spawnUnit(defId: 'spearman', nationId: id, x: x, y: y + 1);

    nations[id] = nation;
    return nation;
  }

  void _spawnUnit({
    required String defId,
    required String nationId,
    required int x,
    required int y,
  }) {
    if (!map.isValid(x, y)) return;
    final def = kUnitDefs[defId];
    if (def == null) return;
    final unit = GameUnit(
      id: _uid('u'),
      defId: defId,
      nationId: nationId,
      x: x,
      y: y,
      health: def.health,
      maxHealth: def.health,
      movesLeft: def.speed,
    );
    units[unit.id] = unit;
    nations[nationId]?.unitIds.add(unit.id);
    map.at(x, y).unitIds.add(unit.id);
  }

  // ── Game tick ─────────────────────────────────────────────
  void processTick() {
    if (phase != GamePhase.playing) return;
    tick++;

    for (final nation in nations.values.where((n) => n.isAlive)) {
      _processNationTick(nation);
    }

    _resetUnitMoves();
    _checkVictoryConditions();

    if (tick % 30 == 0) addEvent('📅 Turn $tick complete.', color: kColorMuted);
    notifyListeners();
  }

  void _processNationTick(Nation nation) {
    // Resource production
    double gold = 0, food = 0, wood = 0, stone = 0, iron = 0, oil = 0;
    int research = 0;

    // Base income
    gold += 2;
    food += 1;

    // Building production
    for (final bid in nation.buildingIds) {
      final b = buildings[bid];
      if (b == null || b.isConstructing) continue;
      final def = b.def;

      gold += def.production['gold'] ?? 0;
      food += def.production['food'] ?? 0;
      wood += def.production['wood'] ?? 0;
      stone += def.production['stone'] ?? 0;
      iron += def.production['iron'] ?? 0;
      oil += def.production['oil'] ?? 0;
      research += (def.production['research'] ?? 0).round();

      // Apply research bonuses
      if (nation.hasCompletedTech('agriculture') && def.id == 'farm') {
        food *= 1.3;
      }
      if (nation.hasCompletedTech('trade_routes') &&
          (def.id == 'market' || def.id == 'harbor')) {
        gold *= 1.4;
      }
      if (nation.hasCompletedTech('banking') &&
          (def.id == 'bank' || def.id == 'market')) {
        gold *= 1.6;
      }
      if (nation.hasCompletedTech('philosophy') ||
          nation.hasCompletedTech('printing_press')) {
        research = (research * 1.5).round();
      }
      if (nation.hasCompletedTech('ai_systems')) research *= 2;
      if (nation.hasCompletedTech('fusion_power')) {
        gold *= 2;
        food *= 2;
        wood *= 2;
        stone *= 2;
        iron *= 2;
        oil *= 2;
      }

      // Advance construction
      if (b.isConstructing) {
        b.buildTicksLeft--;
        if (b.buildTicksLeft <= 0) {
          b.isConstructing = false;
          addEvent(
            '🏗️ ${nation.name} finished building ${def.name}!',
            color: nation.color,
          );
        }
      }

      // Advance training
      if (b.trainingUnitDefId != null) {
        b.trainingTicksLeft--;
        if (b.trainingTicksLeft <= 0) {
          _completeUnitTraining(b, nation);
        }
      }
    }

    nation.resources.add({
      'gold': gold,
      'food': food,
      'wood': wood,
      'stone': stone,
      'iron': iron,
      'oil': oil,
    });
    nation.resources.researchPoints += research;

    // Research progress
    if (nation.activeResearchId != null) {
      final proj = nation.research[nation.activeResearchId!];
      if (proj != null && !proj.completed) {
        final techCost = kTechDefs[proj.techId]?.cost ?? 100;
        proj.progress += research / techCost;
        if (proj.progress >= 1.0) {
          proj.progress = 1.0;
          proj.completed = true;
          nation.activeResearchId = null;
          addEvent(
            '🔬 ${nation.name} researched ${kTechDefs[proj.techId]?.name}!',
            color: nation.color,
          );
        }
      }
    }

    // Nation tier upgrade check
    _checkTierUpgrade(nation);

    // Scores
    nation.economyScore =
        (nation.resources.gold +
                nation.resources.food * 0.5 +
                nation.resources.wood * 0.3 +
                nation.resources.stone * 0.3 +
                nation.resources.iron * 0.5 +
                nation.resources.oil * 0.8)
            .round();
    nation.militaryScore = nation.unitIds
        .map((uid) => units[uid])
        .whereType<GameUnit>()
        .where((u) => u.def.isMilitary)
        .fold(0, (sum, u) => sum + u.def.attack + u.def.defense);
    nation.influenceScore =
        nation.buildingIds.length * 5 + nation.ownedTiles.length * 2;
  }

  void _checkTierUpgrade(Nation nation) {
    final tierThresholds = {
      NationTier.settlement: (tiles: 5, buildings: 3, pop: 10),
      NationTier.village: (tiles: 15, buildings: 6, pop: 30),
      NationTier.town: (tiles: 30, buildings: 12, pop: 80),
      NationTier.city: (tiles: 60, buildings: 20, pop: 200),
      NationTier.metropolis: (tiles: 100, buildings: 35, pop: 500),
    };

    final current = nation.tier;
    if (current == NationTier.globalCapital) return;

    final tiers = NationTier.values;
    final nextTier = tiers[tiers.indexOf(current) + 1];
    final threshold = tierThresholds[current];
    if (threshold == null) return;

    if (nation.ownedTiles.length >= threshold.tiles &&
        nation.buildingIds.length >= threshold.buildings &&
        nation.resources.population >= threshold.pop) {
      nation.tier = nextTier;
      nation.resources.populationCap += nextTier.popCap;
      addEvent(
        '🌆 ${nation.name} has risen to ${nextTier.label}!',
        color: nation.color,
      );
    }
  }

  void _completeUnitTraining(Building b, Nation nation) {
    final defId = b.trainingUnitDefId!;
    // Find empty tile near building
    int ux = b.x, uy = b.y + 1;
    for (int r = 1; r <= 3; r++) {
      bool found = false;
      for (int dy = -r; dy <= r && !found; dy++) {
        for (int dx = -r; dx <= r && !found; dx++) {
          final nx = b.x + dx, ny = b.y + dy;
          if (map.isValid(nx, ny) &&
              map.at(nx, ny).unitIds.isEmpty &&
              map.at(nx, ny).terrain != TerrainType.water) {
            ux = nx;
            uy = ny;
            found = true;
          }
        }
      }
      if (found) break;
    }
    _spawnUnit(defId: defId, nationId: nation.id, x: ux, y: uy);
    b.trainingUnitDefId = null;
    b.trainingTicksLeft = 0;
    addEvent(
      '⚔️ ${nation.name} trained a ${kUnitDefs[defId]?.name ?? defId}!',
      color: nation.color,
    );
  }

  void _resetUnitMoves() {
    for (final unit in units.values) {
      unit.hasMoved = false;
      unit.hasAttacked = false;
      unit.movesLeft = unit.def.speed;
    }
  }

  // ── PLAYER ACTIONS ────────────────────────────────────────

  bool buildBuilding(String nationId, String buildingDefId, int x, int y) {
    final nation = nations[nationId];
    final def = kBuildingDefs[buildingDefId];
    if (nation == null || def == null) return false;
    if (!nation.isAlive) return false;

    // Age check
    if (def.requiredAge.index2 > nation.currentAge.index2) {
      addEvent('❌ Requires ${def.requiredAge.label}!', color: kColorAccent);
      return false;
    }

    // Tile check
    if (!map.isValid(x, y)) return false;
    final tile = map.at(x, y);
    if (tile.buildingId != null) {
      addEvent('❌ Tile already has a building!', color: kColorAccent);
      return false;
    }
    if (tile.terrain == TerrainType.water) {
      addEvent('❌ Cannot build on water!', color: kColorAccent);
      return false;
    }
    if (tile.ownerNationId != nationId) {
      addEvent('❌ Must build on your own territory!', color: kColorAccent);
      return false;
    }

    // Cost check
    if (!nation.resources.canAfford(def.cost)) {
      addEvent(
        '❌ Insufficient resources for ${def.name}!',
        color: kColorAccent,
      );
      return false;
    }

    nation.resources.spend(def.cost);

    final b = Building(
      id: _uid('b'),
      defId: buildingDefId,
      nationId: nationId,
      x: x,
      y: y,
      health: def.health,
      maxHealth: def.health,
      buildTicksLeft: def.buildTicks,
      isConstructing: def.buildTicks > 0,
    );
    buildings[b.id] = b;
    nation.buildingIds.add(b.id);
    tile.buildingId = b.id;

    // Pop cap bonus
    if (def.popCapBonus != null) {
      nation.resources.populationCap += def.popCapBonus!;
    }

    addEvent(
      '🏗️ ${nation.name} is building a ${def.name}!',
      color: nation.color,
    );
    notifyListeners();
    return true;
  }

  bool trainUnit(String nationId, String buildingId, String unitDefId) {
    final nation = nations[nationId];
    final building = buildings[buildingId];
    final def = kUnitDefs[unitDefId];
    if (nation == null || building == null || def == null) return false;
    if (!nation.isAlive ||
        building.isConstructing ||
        building.trainingUnitDefId != null) {
      return false;
    }

    if (def.requiredAge.index2 > nation.currentAge.index2) {
      addEvent('❌ Requires ${def.requiredAge.label}!', color: kColorAccent);
      return false;
    }

    if (!nation.resources.canAfford(def.cost)) {
      addEvent('❌ Insufficient resources!', color: kColorAccent);
      return false;
    }

    nation.resources.spend(def.cost);
    building.trainingUnitDefId = unitDefId;
    building.trainingTicksLeft = def.trainTicks;

    addEvent(
      '🎯 ${nation.name} is training a ${def.name}!',
      color: nation.color,
    );
    notifyListeners();
    return true;
  }

  bool moveUnit(String unitId, int toX, int toY) {
    final unit = units[unitId];
    if (unit == null || unit.hasMoved) return false;
    if (!map.isValid(toX, toY)) return false;

    final targetTile = map.at(toX, toY);

    // Check if occupied by enemy
    for (final uid in targetTile.unitIds) {
      final other = units[uid];
      if (other != null && other.nationId != unit.nationId) {
        addEvent('❌ Tile occupied by enemy!', color: kColorAccent);
        return false;
      }
    }

    if (targetTile.terrain == TerrainType.water &&
        unit.defId != 'destroyer' &&
        unit.defId != 'submarine') {
      addEvent('❌ Unit cannot enter water!', color: kColorAccent);
      return false;
    }

    // Distance check (simple Manhattan)
    final dist = (toX - unit.x).abs() + (toY - unit.y).abs();
    if (dist > unit.def.speed) return false;

    // Move
    map.at(unit.x, unit.y).unitIds.remove(unitId);
    unit.x = toX;
    unit.y = toY;
    map.at(toX, toY).unitIds.add(unitId);
    unit.hasMoved = true;
    unit.movesLeft -= dist;

    // Claim tile
    if (targetTile.ownerNationId != unit.nationId) {
      if (targetTile.ownerNationId != null) {
        nations[targetTile.ownerNationId!]?.removeTile(toX, toY);
      }
      targetTile.ownerNationId = unit.nationId;
      nations[unit.nationId]?.addTile(toX, toY);
    }

    notifyListeners();
    return true;
  }

  bool attackTarget(String attackerUnitId, int targetX, int targetY) {
    final attacker = units[attackerUnitId];
    if (attacker == null || attacker.hasAttacked) return false;
    if (!attacker.def.isMilitary) return false;

    final dist = (targetX - attacker.x).abs() + (targetY - attacker.y).abs();
    if (dist > attacker.def.range) return false;

    final targetTile = map.at(targetX, targetY);
    final attackerNation = nations[attacker.nationId]!;

    // Attack enemy units
    final enemyUnitIds = targetTile.unitIds
        .where((uid) => units[uid]?.nationId != attacker.nationId)
        .toList();

    if (enemyUnitIds.isNotEmpty) {
      final targetUnitId = enemyUnitIds.first;
      final targetUnit = units[targetUnitId]!;
      _resolveCombat(
        attacker,
        targetUnit,
        attackerNation,
        nations[targetUnit.nationId]!,
      );
      attacker.hasAttacked = true;
      notifyListeners();
      return true;
    }

    // Attack enemy building
    final buildingId = targetTile.buildingId;
    if (buildingId != null) {
      final b = buildings[buildingId];
      if (b != null && b.nationId != attacker.nationId) {
        final damage =
            (attacker.def.attack *
                    (1 +
                        (attackerNation.hasCompletedTech('bronze_working')
                            ? 0.1
                            : 0) +
                        (attackerNation.hasCompletedTech('iron_working')
                            ? 0.2
                            : 0) +
                        (attackerNation.hasCompletedTech('steel') ? 0.25 : 0)))
                .round();
        b.health -= damage;
        addEvent(
          '💥 ${attackerNation.name} dealt $damage dmg to ${b.def.name}!',
          color: attackerNation.color,
        );

        if (b.health <= 0) {
          _destroyBuilding(b, attackerNation);
        }
        attacker.hasAttacked = true;
        notifyListeners();
        return true;
      }
    }

    return false;
  }

  void _resolveCombat(GameUnit a, GameUnit d, Nation aNation, Nation dNation) {
    final atkBonus =
        (aNation.hasCompletedTech('bronze_working') ? 0.1 : 0) +
        (aNation.hasCompletedTech('iron_working') ? 0.2 : 0) +
        (aNation.hasCompletedTech('steel') ? 0.25 : 0);
    final defBonus =
        (dNation.hasCompletedTech('masonry') ? 0.15 : 0) +
        (dNation.hasCompletedTech('steel') ? 0.25 : 0);

    final atkDmg = math.max(
      1,
      (a.def.attack * (1 + atkBonus) - d.def.defense * 0.5 * (1 + defBonus))
          .round(),
    );
    final defDmg = math.max(
      0,
      (d.def.attack * 0.5 * (1 + defBonus * 0.5) - a.def.defense * 0.3).round(),
    );

    d.health -= atkDmg;
    a.health -= defDmg;

    addEvent(
      '⚔️ ${aNation.name}\'s ${a.def.name} → ${dNation.name}\'s ${d.def.name}: -$atkDmg hp',
      color: aNation.color,
    );

    // Emit combat effect for floating damage numbers
    final dCrit = atkDmg > a.def.attack * 1.3;
    combatEffects.add(
      CombatEffect(
        x: d.x,
        y: d.y,
        damage: atkDmg,
        isCrit: dCrit,
        isKill: d.health <= 0,
        color: aNation.color,
      ),
    );
    if (defDmg > 0) {
      combatEffects.add(
        CombatEffect(
          x: a.x,
          y: a.y,
          damage: defDmg,
          isCrit: false,
          isKill: a.health <= 0,
          color: dNation.color,
        ),
      );
    }

    if (d.health <= 0) _removeUnit(d.id);
    if (a.health <= 0) _removeUnit(a.id);
  }

  void _removeUnit(String unitId) {
    final unit = units.remove(unitId);
    if (unit == null) return;
    nations[unit.nationId]?.unitIds.remove(unitId);
    map.at(unit.x, unit.y).unitIds.remove(unitId);
  }

  void _destroyBuilding(Building b, Nation capturer) {
    addEvent(
      '🔥 ${b.def.name} destroyed by ${capturer.name}!',
      color: capturer.color,
    );
    map.at(b.x, b.y).buildingId = null;
    buildings.remove(b.id);

    final ownerNation = nations[b.nationId];
    ownerNation?.buildingIds.remove(b.id);

    // Check if capital destroyed
    if (b.defId == 'capital_fortress') {
      ownerNation?.isAlive = false;
      addEvent(
        '💀 ${ownerNation?.name} has been conquered!',
        color: kColorAccent,
      );

      // Transfer all territory to capturer
      if (ownerNation != null) {
        for (final tileKey in ownerNation.ownedTiles) {
          final parts = tileKey.split(',');
          final x = int.parse(parts[0]), y = int.parse(parts[1]);
          map.at(x, y).ownerNationId = capturer.id;
          capturer.addTile(x, y);
        }
        ownerNation.ownedTiles.clear();
      }
    }
  }

  bool startResearch(String nationId, String techId) {
    final nation = nations[nationId];
    final tech = kTechDefs[techId];
    if (nation == null || tech == null) return false;
    if (nation.hasCompletedTech(techId)) return false;

    // Check prerequisites
    for (final prereq in tech.prerequisites) {
      if (!nation.hasCompletedTech(prereq)) {
        addEvent(
          '❌ Requires ${kTechDefs[prereq]?.name ?? prereq} first!',
          color: kColorAccent,
        );
        return false;
      }
    }

    // Check age
    if (tech.era.index2 > nation.currentAge.index2) {
      addEvent('❌ Requires ${tech.era.label}!', color: kColorAccent);
      return false;
    }

    nation.research[techId] ??= ResearchProject(techId: techId);
    nation.activeResearchId = techId;
    addEvent(
      '🔬 ${nation.name} is researching ${tech.name}!',
      color: nation.color,
    );
    notifyListeners();
    return true;
  }

  bool performDiplomacy(
    String nationId,
    String targetId,
    DiplomacyAction action,
  ) {
    final nation = nations[nationId];
    final target = nations[targetId];
    if (nation == null || target == null) return false;

    nation.diplomacy[targetId] ??= DiplomacyState(otherId: targetId);
    target.diplomacy[nationId] ??= DiplomacyState(otherId: nationId);

    switch (action) {
      case DiplomacyAction.ally:
        nation.diplomacy[targetId]!.isAllied = true;
        target.diplomacy[nationId]!.isAllied = true;
        nation.diplomacy[targetId]!.atWar = false;
        target.diplomacy[nationId]!.atWar = false;
        nation.influenceScore += 20;
        target.influenceScore += 20;
        addEvent(
          '🤝 ${nation.name} and ${target.name} formed an alliance!',
          color: kColorGold,
        );
        break;
      case DiplomacyAction.declareWar:
        nation.diplomacy[targetId]!.atWar = true;
        target.diplomacy[nationId]!.atWar = true;
        nation.diplomacy[targetId]!.isAllied = false;
        target.diplomacy[nationId]!.isAllied = false;
        addEvent(
          '⚔️ ${nation.name} declared war on ${target.name}!',
          color: kColorAccent,
        );
        break;
      case DiplomacyAction.makePeace:
        nation.diplomacy[targetId]!.atWar = false;
        target.diplomacy[nationId]!.atWar = false;
        addEvent(
          '🕊️ ${nation.name} and ${target.name} made peace!',
          color: kColorSuccess,
        );
        break;
      case DiplomacyAction.embargo:
        addEvent(
          '📦 ${nation.name} imposed an embargo on ${target.name}!',
          color: kColorMuted,
        );
        break;
    }
    notifyListeners();
    return true;
  }

  bool advanceAge(String nationId) {
    final nation = nations[nationId];
    if (nation == null) return false;
    if (nation.currentAge == Age.future) return false;

    final ages = Age.values;
    final nextAge = ages[ages.indexOf(nation.currentAge) + 1];

    // Age advance costs
    final ageCosts = <Age, Map<String, double>>{
      Age.classical: {'gold': 500, 'stone': 100, 'food': 200},
      Age.medieval: {'gold': 800, 'stone': 200, 'iron': 50},
      Age.renaissance: {'gold': 1200, 'iron': 100, 'stone': 300},
      Age.industrial: {'gold': 2000, 'iron': 300, 'oil': 50},
      Age.modern: {'gold': 3500, 'iron': 500, 'oil': 200},
      Age.information: {'gold': 6000, 'iron': 800, 'oil': 400},
      Age.future: {'gold': 12000, 'iron': 2000, 'oil': 1000},
    };

    final cost = ageCosts[nextAge] ?? {};
    if (!nation.resources.canAfford(cost)) {
      addEvent(
        '❌ Insufficient resources to advance to ${nextAge.label}!',
        color: kColorAccent,
      );
      return false;
    }

    nation.resources.spend(cost);
    nation.currentAge = nextAge;
    addEvent(
      '🌅 ${nation.name} entered the ${nextAge.label}!',
      color: kColorGold,
    );
    notifyListeners();
    return true;
  }

  // ── Victory checks ────────────────────────────────────────
  void _checkVictoryConditions() {
    final alive = nations.values.where((n) => n.isAlive).toList();

    // Military victory
    if (alive.length == 1) {
      _triggerVictory(VictoryType.military, alive.first.id);
      return;
    }

    // Check for player-specific defeats/wins
    for (final nation in nations.values) {
      if (!nation.isAlive) continue;

      // Territorial victory (75% of tiles)
      final totalTiles = kMapW * kMapH;
      if (nation.ownedTiles.length >= totalTiles * kTerritoryVictoryPct / 100) {
        _triggerVictory(VictoryType.territorial, nation.id);
        return;
      }

      // Technological victory
      if (nation.hasCompletedTech('space_colonization') &&
          nation.hasBuilding('space_center', buildings)) {
        _triggerVictory(VictoryType.technological, nation.id);
        return;
      }

      // Economic victory
      final topEconomy = alive.map((n) => n.economyScore).reduce(math.max);
      if (nation.economyScore == topEconomy && alive.length > 1) {
        nation.economicVictoryTicks++;
        if (nation.economicVictoryTicks >= kEcoVictoryTicks) {
          _triggerVictory(VictoryType.economic, nation.id);
          return;
        }
      } else {
        nation.economicVictoryTicks = 0;
      }

      // Diplomatic victory (highest influence with 3+ alliances)
      final allies = nation.diplomacy.values.where((d) => d.isAllied).length;
      if (allies >= 3) {
        final topInfluence = alive
            .map((n) => n.influenceScore)
            .reduce(math.max);
        if (nation.influenceScore == topInfluence && tick >= 500) {
          _triggerVictory(VictoryType.diplomatic, nation.id);
          return;
        }
      }
    }
  }

  void _triggerVictory(VictoryType type, String winnerId) {
    victoryType = type;
    winnerNationId = winnerId;
    phase = GamePhase.ended;
    final winner = nations[winnerId];
    const labels = {
      VictoryType.military: 'Military Conquest',
      VictoryType.economic: 'Economic Dominance',
      VictoryType.territorial: 'Territorial Control',
      VictoryType.technological: 'Technological Ascension',
      VictoryType.diplomatic: 'Global Diplomacy',
    };
    addEvent(
      '🏆 ${winner?.name} achieved VICTORY: ${labels[type]}!',
      color: kColorGold,
    );
    notifyListeners();
  }

  // ── Selection helpers ─────────────────────────────────────
  void selectTile(int x, int y) {
    if (!map.isValid(x, y)) return;
    selX = x;
    selY = y;
    moveHighlights.clear();
    attackHighlights.clear();

    final tile = map.at(x, y);

    // Select unit on tile
    final playerUnits = tile.unitIds
        .where((uid) => units[uid]?.nationId == playerNationId)
        .toList();
    if (playerUnits.isNotEmpty) {
      selUnitId = playerUnits.first;
      selBuildingId = null;
      _computeUnitHighlights(units[selUnitId!]!);
    } else {
      selUnitId = null;
    }

    // Select building
    if (tile.buildingId != null &&
        buildings[tile.buildingId!]?.nationId == playerNationId) {
      selBuildingId = tile.buildingId;
    } else {
      selBuildingId = null;
    }

    pendingBuildDefId = null;
    notifyListeners();
  }

  void _computeUnitHighlights(GameUnit unit) {
    if (unit.hasMoved) return;
    for (int dy = -unit.def.speed; dy <= unit.def.speed; dy++) {
      for (int dx = -unit.def.speed; dx <= unit.def.speed; dx++) {
        final dist = dx.abs() + dy.abs();
        if (dist == 0 || dist > unit.def.speed) continue;
        final nx = unit.x + dx, ny = unit.y + dy;
        if (!map.isValid(nx, ny)) continue;
        final t = map.at(nx, ny);
        if (t.terrain == TerrainType.water &&
            unit.defId != 'destroyer' &&
            unit.defId != 'submarine') {
          continue;
        }
        final hasEnemy = t.unitIds.any(
          (uid) => units[uid]?.nationId != unit.nationId,
        );
        if (!hasEnemy) moveHighlights.add([nx, ny]);
      }
    }
    if (!unit.hasAttacked && unit.def.isMilitary) {
      for (int dy = -unit.def.range; dy <= unit.def.range; dy++) {
        for (int dx = -unit.def.range; dx <= unit.def.range; dx++) {
          final dist = dx.abs() + dy.abs();
          if (dist == 0 || dist > unit.def.range) continue;
          final nx = unit.x + dx, ny = unit.y + dy;
          if (!map.isValid(nx, ny)) continue;
          final t = map.at(nx, ny);
          final hasEnemy =
              t.unitIds.any((uid) => units[uid]?.nationId != unit.nationId) ||
              (t.buildingId != null &&
                  buildings[t.buildingId!]?.nationId != unit.nationId);
          if (hasEnemy) attackHighlights.add([nx, ny]);
        }
      }
    }
  }

  void clearSelection() {
    selX = selY = null;
    selUnitId = selBuildingId = null;
    pendingBuildDefId = null;
    moveHighlights.clear();
    attackHighlights.clear();
    selectedUnitIds.clear();
    pendingPath.clear();
    notifyListeners();
  }

  void clearMultiSelection() {
    selectedUnitIds.clear();
    pendingPath.clear();
    notifyListeners();
  }

  void selectUnitsInRect(double x1, double y1, double x2, double y2) {
    selectedUnitIds.clear();
    final minX = x1 < x2 ? x1 : x2;
    final maxX = x1 < x2 ? x2 : x1;
    final minY = y1 < y2 ? y1 : y2;
    final maxY = y1 < y2 ? y2 : y1;
    for (final u in units.values) {
      if (u.nationId != playerNationId) continue;
      if (u.x >= minX && u.x <= maxX && u.y >= minY && u.y <= maxY) {
        selectedUnitIds.add(u.id);
      }
    }
    notifyListeners();
  }

  List<List<int>> computePath(int fromX, int fromY, int toX, int toY) {
    if (!map.isValid(fromX, fromY) || !map.isValid(toX, toY)) return [];
    final visited = <String>{};
    final queue = <List<dynamic>>[
      [fromX, fromY, <List<int>>[]],
    ];
    visited.add('$fromX,$fromY');
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final cx = current[0] as int;
      final cy = current[1] as int;
      final path = current[2] as List<List<int>>;
      if (cx == toX && cy == toY) return path;
      for (final d in [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ]) {
        final nx = cx + d[0], ny = cy + d[1];
        final key = '$nx,$ny';
        if (!map.isValid(nx, ny) || visited.contains(key)) continue;
        final t = map.at(nx, ny);
        if (t.terrain == TerrainType.water) continue;
        visited.add(key);
        queue.add([
          nx,
          ny,
          [
            ...path,
            [nx, ny],
          ],
        ]);
      }
    }
    return [];
  }

  void handleTileAction(int x, int y) {
    // Build mode
    if (pendingBuildDefId != null) {
      buildBuilding(playerNationId!, pendingBuildDefId!, x, y);
      clearSelection();
      return;
    }

    // Unit action
    if (selUnitId != null) {
      final unit = units[selUnitId!];
      if (unit == null) {
        clearSelection();
        return;
      }

      final isMoveTarget = moveHighlights.any((h) => h[0] == x && h[1] == y);
      final isAttackTarget = attackHighlights.any(
        (h) => h[0] == x && h[1] == y,
      );

      if (isAttackTarget) {
        attackTarget(selUnitId!, x, y);
        clearSelection();
      } else if (isMoveTarget) {
        moveUnit(selUnitId!, x, y);
        selectTile(x, y); // reselect
      } else {
        selectTile(x, y);
      }
    } else {
      selectTile(x, y);
    }
  }

  // ── Events & Chat ─────────────────────────────────────────
  void addEvent(String msg, {Color color = kColorText}) {
    events.insert(0, GameEvent(msg, color: color));
    if (events.length > 50) events.removeLast();
  }

  /// Public wrapper so external widgets can trigger a rebuild.
  void rebuild() => notifyListeners();

  void addChatMessage(String sender, String msg) {
    chatMessages.add({
      'sender': sender,
      'msg': msg,
      'time': DateTime.now().toIso8601String(),
    });
    if (chatMessages.length > 100) chatMessages.removeAt(0);
  }

  // ── Serialization ─────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'gameId': gameId,
    'tick': tick,
    'map': {
      'tiles': map.tiles.expand((row) => row).map((t) => t.toJson()).toList(),
    },
    'nations': nations.map((k, v) => MapEntry(k, v.toJson())),
    'buildings': buildings.map((k, v) => MapEntry(k, v.toJson())),
    'units': units.map((k, v) => MapEntry(k, v.toJson())),
    'phase': phase.name,
    'playerNationId': playerNationId,
    'victoryType': victoryType?.name,
    'winnerNationId': winnerNationId,
  };

  void loadFromJson(Map<String, dynamic> j) {
    gameId = j['gameId'] ?? gameId;
    tick = j['tick'] ?? tick;

    if (j['map'] != null) {
      final tileList = (j['map']['tiles'] as List)
          .map((t) => MapTile.fromJson(t))
          .toList();
      for (final tile in tileList) {
        if (map.isValid(tile.x, tile.y)) {
          map.tiles[tile.y][tile.x] = tile;
        }
      }
    }

    if (j['nations'] != null) {
      nations = (j['nations'] as Map).map(
        (k, v) => MapEntry(k as String, Nation.fromJson(v)),
      );
    }
    if (j['buildings'] != null) {
      buildings = (j['buildings'] as Map).map(
        (k, v) => MapEntry(k as String, Building.fromJson(v)),
      );
    }
    if (j['units'] != null) {
      units = (j['units'] as Map).map(
        (k, v) => MapEntry(k as String, GameUnit.fromJson(v)),
      );
    }

    phase = GamePhase.values.firstWhere(
      (p) => p.name == j['phase'],
      orElse: () => phase,
    );
    playerNationId = j['playerNationId'];
    if (j['victoryType'] != null) {
      victoryType = VictoryType.values.firstWhere(
        (v) => v.name == j['victoryType'],
      );
    }
    winnerNationId = j['winnerNationId'];
    notifyListeners();
  }

  // Getters
  Nation? get playerNation =>
      playerNationId != null ? nations[playerNationId!] : null;
  List<Nation> get aliveNations =>
      nations.values.where((n) => n.isAlive).toList();
  List<Building> buildingsFor(String nationId) => [
    for (final id in nations[nationId]?.buildingIds ?? [])
      if (buildings[id] != null) buildings[id]!,
  ];

  List<GameUnit> unitsFor(String nationId) => [
    for (final id in nations[nationId]?.unitIds ?? [])
      if (units[id] != null) units[id]!,
  ];

  List<GameUnit> unitsAt(int x, int y) => map
      .at(x, y)
      .unitIds
      .map((id) => units[id])
      .whereType<GameUnit>()
      .toList();

  Building? buildingAt(int x, int y) {
    final bid = map.at(x, y).buildingId;
    return bid != null ? buildings[bid] : null;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 11 ▸ AI ENGINE
// ══════════════════════════════════════════════════════════════════════════════

class AIEngine {
  final GameState state;
  final Nation nation;
  final math.Random _rng;

  AIEngine(this.state, this.nation) : _rng = math.Random(nation.id.hashCode);

  void processTick() {
    if (!nation.isAlive) return;
    nation.aiTick++;
    _tryResearch();
    _tryAdvanceAge();
    _tryBuild();
    _tryTrain();
    _tryExpand();
    _tryCombat();
  }

  void _tryResearch() {
    if (nation.activeResearchId != null) return;
    final available = kTechDefs.entries
        .where(
          (e) =>
              e.value.era.index2 <= nation.currentAge.index2 &&
              !nation.hasCompletedTech(e.key) &&
              e.value.prerequisites.every((p) => nation.hasCompletedTech(p)),
        )
        .toList();
    if (available.isEmpty) return;
    available.shuffle(_rng);
    state.startResearch(nation.id, available.first.key);
  }

  void _tryAdvanceAge() {
    if (nation.aiTick % 20 != 0) return;
    if (nation.resources.gold > 2000) state.advanceAge(nation.id);
  }

  void _tryBuild() {
    if (nation.aiTick % 3 != 0) return;
    final priority = _getBuildPriority();
    for (final defId in priority) {
      final def = kBuildingDefs[defId];
      if (def == null) continue;
      if (def.requiredAge.index2 > nation.currentAge.index2) continue;
      if (!nation.resources.canAfford(def.cost)) continue;
      final count = nation.buildingIds
          .where((bid) => state.buildings[bid]?.defId == defId)
          .length;
      if (count >= _maxBuildings(defId)) continue;
      final tile = _findBuildTile();
      if (tile == null) continue;
      state.buildBuilding(nation.id, defId, tile[0], tile[1]);
      return;
    }
  }

  List<String> _getBuildPriority() {
    switch (nation.aiStrategy) {
      case 'military':
        return [
          'barracks',
          'archery_range',
          'stable',
          'siege_workshop',
          'military_academy',
          'tank_factory',
          'farm',
          'mine',
          'market',
          'walls',
        ];
      case 'economic':
        return [
          'farm',
          'windmill',
          'lumber_mill',
          'market',
          'mine',
          'bank',
          'oil_rig',
          'harbor',
          'research_center',
          'barracks',
        ];
      case 'technology':
        return [
          'research_center',
          'university',
          'innovation_lab',
          'farm',
          'mine',
          'market',
          'barracks',
        ];
      default:
        return [
          'farm',
          'barracks',
          'lumber_mill',
          'mine',
          'archery_range',
          'market',
          'research_center',
          'stable',
          'walls',
        ];
    }
  }

  int _maxBuildings(String defId) {
    const caps = {
      'farm': 5,
      'windmill': 3,
      'mine': 3,
      'lumber_mill': 3,
      'market': 2,
      'bank': 1,
      'oil_rig': 2,
      'barracks': 2,
      'archery_range': 1,
      'stable': 1,
      'siege_workshop': 1,
      'military_academy': 1,
      'tank_factory': 1,
      'air_force_base': 1,
      'naval_base': 1,
      'walls': 8,
      'watchtower': 4,
      'fortress': 1,
      'cannon_tower': 2,
      'research_center': 2,
      'university': 1,
      'innovation_lab': 1,
      'harbor': 1,
    };
    return caps[defId] ?? 1;
  }

  List<int>? _findBuildTile() {
    final owned = nation.ownedTiles.toList()..shuffle(_rng);
    for (final key in owned) {
      final p = key.split(',');
      final x = int.parse(p[0]), y = int.parse(p[1]);
      if (!state.map.isValid(x, y)) continue;
      final t = state.map.at(x, y);
      if (t.buildingId == null &&
          t.terrain != TerrainType.water &&
          t.terrain != TerrainType.mountain) {
        return [x, y];
      }
    }
    return null;
  }

  void _tryTrain() {
    if (nation.aiTick % 4 != 0) return;
    for (final bid in nation.buildingIds) {
      final b = state.buildings[bid];
      if (b == null || b.isConstructing || b.trainingUnitDefId != null) {
        continue;
      }
      final opts = b.def.unlocks.where((uid) {
        final d = kUnitDefs[uid];
        return d != null &&
            d.requiredAge.index2 <= nation.currentAge.index2 &&
            nation.resources.canAfford(d.cost);
      }).toList();
      if (opts.isNotEmpty) {
        state.trainUnit(nation.id, bid, opts.last);
        return;
      }
    }
  }

  void _tryExpand() {
    if (nation.aiTick % 2 != 0) return;
    for (final uid in nation.unitIds.toList()) {
      final unit = state.units[uid];
      if (unit == null || unit.hasMoved || unit.def.isMilitary) continue;
      final targets = state.map
          .inRange(unit.x, unit.y, unit.def.speed)
          .where(
            (t) =>
                t.ownerNationId == null &&
                t.terrain != TerrainType.water &&
                t.unitIds.isEmpty,
          )
          .toList();
      if (targets.isNotEmpty) {
        targets.shuffle(_rng);
        state.moveUnit(uid, targets.first.x, targets.first.y);
      }
    }
  }

  void _tryCombat() {
    if (nation.aiTick % 2 != 0) return;
    for (final uid in nation.unitIds.toList()) {
      final unit = state.units[uid];
      if (unit == null || !unit.def.isMilitary) continue;
      if (!unit.hasAttacked) {
        for (final tile in state.map.inRange(unit.x, unit.y, unit.def.range)) {
          final hasEnemy =
              tile.unitIds.any(
                (id) => state.units[id]?.nationId != nation.id,
              ) ||
              (tile.buildingId != null &&
                  state.buildings[tile.buildingId!]?.nationId != nation.id);
          if (hasEnemy) {
            state.attackTarget(uid, tile.x, tile.y);
            break;
          }
        }
      }
      if (!unit.hasMoved) {
        final enemies = state.nations.values
            .where(
              (n) =>
                  n.isAlive &&
                  n.id != nation.id &&
                  nation.diplomacy[n.id]?.isAllied != true,
            )
            .toList();
        if (enemies.isEmpty) continue;
        enemies.sort((a, b) {
          final da = (a.capitalX - unit.x).abs() + (a.capitalY - unit.y).abs();
          final db = (b.capitalX - unit.x).abs() + (b.capitalY - unit.y).abs();
          return da.compareTo(db);
        });
        final target = enemies.first;
        final dx = (target.capitalX - unit.x).sign,
            dy = (target.capitalY - unit.y).sign;
        final nx = unit.x + dx, ny = unit.y + dy;
        if (state.map.isValid(nx, ny)) {
          final t = state.map.at(nx, ny);
          if (!t.unitIds.any((id) => state.units[id]?.nationId != nation.id)) {
            state.moveUnit(uid, nx, ny);
          }
        }
      }
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 12 ▸ MULTIPLAYER SERVICE
// ══════════════════════════════════════════════════════════════════════════════

class MultiplayerService {
  static final MultiplayerService instance = MultiplayerService._();
  MultiplayerService._();

  WebSocketChannel? _channel;
  bool _connected = false;
  String _serverUrl = kDefaultWsUrl;
  String? _roomCode;

  final StreamController<Map<String, dynamic>> _events =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get connected => _connected;
  String? get roomCode => _roomCode;
  String get serverUrl => _serverUrl;
  set serverUrl(String v) => _serverUrl = v;

  Future<bool> connect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_serverUrl));
      _channel!.stream.listen(
        (data) {
          try {
            _events.add(jsonDecode(data as String) as Map<String, dynamic>);
          } catch (_) {}
        },
        onDone: () {
          _connected = false;
          _events.add({'type': 'disconnected'});
        },
        onError: (_) {
          _connected = false;
          _events.add({'type': 'error'});
        },
      );
      _connected = true;
      return true;
    } catch (_) {
      _connected = false;
      return false;
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _connected = false;
    _roomCode = null;
  }

  void _send(String type, Map<String, dynamic> data) {
    if (!_connected) return;
    try {
      _channel!.sink.add(jsonEncode({'type': type, 'data': data}));
    } catch (_) {}
  }

  void createRoom({
    required String roomName,
    required String playerName,
    required String nationName,
    required int nationColorValue,
    int maxPlayers = 8,
    String gameMode = 'ffa',
  }) {
    _send('create_room', {
      'roomName': roomName,
      'playerName': playerName,
      'nationName': nationName,
      'nationColor': nationColorValue,
      'maxPlayers': maxPlayers,
      'gameMode': gameMode,
    });
  }

  void joinRoom({
    required String code,
    required String playerName,
    required String nationName,
    required int nationColorValue,
  }) {
    _roomCode = code;
    _send('join_room', {
      'code': code,
      'playerName': playerName,
      'nationName': nationName,
      'nationColor': nationColorValue,
    });
  }

  void setReady(bool ready) => _send('ready', {'ready': ready});
  void startGame() => _send('start_game', {});
  void leaveRoom() {
    _send('leave_room', {});
    _roomCode = null;
  }

  void sendAction(ActionType type, Map<String, dynamic> payload) =>
      _send('action', {'actionType': type.name, ...payload});
  void sendBuild(String defId, int x, int y) =>
      sendAction(ActionType.build, {'buildingDefId': defId, 'x': x, 'y': y});
  void sendMove(String unitId, int tx, int ty) =>
      sendAction(ActionType.moveUnit, {'unitId': unitId, 'toX': tx, 'toY': ty});
  void sendAttack(String unitId, int tx, int ty) => sendAction(
    ActionType.attack,
    {'unitId': unitId, 'targetX': tx, 'targetY': ty},
  );
  void sendResearch(String techId) =>
      sendAction(ActionType.research, {'techId': techId});
  void sendTrain(String bid, String uid) =>
      sendAction(ActionType.trainUnit, {'buildingId': bid, 'unitDefId': uid});
  void sendDiplomacy(String targetId, DiplomacyAction a) => sendAction(
    ActionType.diplomacy,
    {'targetNationId': targetId, 'action': a.name},
  );
  void syncState(Map<String, dynamic> s) => _send('sync_state', s);
  void sendChat(String msg) => _send('chat', {'message': msg});
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 13 ▸ MAIN APP
// ══════════════════════════════════════════════════════════════════════════════

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(GlobalDominionApp());
}

class GlobalDominionApp extends StatelessWidget {
  final GameState _game = GameState();
  GlobalDominionApp({super.key});

  @override
  Widget build(BuildContext ctx) => ListenableBuilder(
    listenable: _game,
    builder: (c, _) => MaterialApp(
      title: 'Global Dominion: Rise of Nations',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kColorBg,
        colorScheme: const ColorScheme.dark(
          primary: kColorGold,
          secondary: kColorGoldDark,
          surface: kColorPanel,
          error: kColorAccent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kColorPanel,
          foregroundColor: kColorGold,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: kColorText),
          bodySmall: TextStyle(color: kColorMuted),
          titleLarge: TextStyle(
            color: kColorGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kColorGoldDark,
            foregroundColor: kColorText,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kColorBorder,
          labelStyle: const TextStyle(color: kColorMuted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: kColorGoldDark),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: kColorBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: kColorGold),
          ),
        ),
      ),
      home: SplashScreen(game: _game),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 14 ▸ SPLASH SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  final GameState game;
  const SplashScreen({super.key, required this.game});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade, _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );
    _scale = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => MainMenuScreen(game: widget.game)),
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kColorBg,
    body: Center(
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌍', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 20),
              const Text(
                'GLOBAL DOMINION',
                style: TextStyle(
                  color: kColorGold,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'RISE OF NATIONS',
                style: TextStyle(
                  color: kColorText,
                  fontSize: 15,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  backgroundColor: kColorBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(kColorGold),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'v$kAppVersion',
                style: TextStyle(color: kColorMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 15 ▸ MAIN MENU
// ══════════════════════════════════════════════════════════════════════════════

class MainMenuScreen extends StatefulWidget {
  final GameState game;
  const MainMenuScreen({super.key, required this.game});
  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _g;
  @override
  void initState() {
    super.initState();
    _g = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _g.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        CustomPaint(
          painter: _GridBgPainter(),
          size: MediaQuery.of(context).size,
        ),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _g,
                      builder: (_, _) => Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: kColorGold.withValues(
                                alpha: _g.value * 0.5,
                              ),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🌍', style: TextStyle(fontSize: 72)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'GLOBAL DOMINION',
                      style: TextStyle(
                        color: kColorGold,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 5,
                      ),
                    ),
                    const Text(
                      'RISE OF NATIONS',
                      style: TextStyle(
                        color: kColorText,
                        fontSize: 12,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Build · Conquer · Dominate',
                      style: TextStyle(
                        color: kColorMuted,
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(width: 1, height: 260, color: kColorGoldDark),
            Expanded(
              flex: 2,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MBtn(
                        icon: '⚔️',
                        label: 'SINGLE PLAYER',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SinglePlayerSetupScreen(game: widget.game),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _MBtn(
                        icon: '🌐',
                        label: 'MULTIPLAYER',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                MultiplayerMenuScreen(game: widget.game),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _MBtn(
                        icon: '⚙️',
                        label: 'SETTINGS',
                        secondary: true,
                        onTap: () => _settings(context),
                      ),
                      const SizedBox(height: 10),
                      _MBtn(
                        icon: '📜',
                        label: 'HOW TO PLAY',
                        secondary: true,
                        onTap: () => _howToPlay(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 8,
          right: 12,
          child: const Text(
            'v$kAppVersion',
            style: TextStyle(color: kColorMuted, fontSize: 10),
          ),
        ),
      ],
    ),
  );

  void _settings(BuildContext ctx) {
    final ctrl = TextEditingController(
      text: MultiplayerService.instance.serverUrl,
    );
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: kColorPanel,
        title: const Text('⚙️ Settings', style: TextStyle(color: kColorGold)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: kColorText, fontSize: 12),
          decoration: const InputDecoration(labelText: 'WebSocket Server URL'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: kColorMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              MultiplayerService.instance.serverUrl = ctrl.text;
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _howToPlay(BuildContext ctx) => showDialog(
    context: ctx,
    builder: (_) => Dialog(
      backgroundColor: kColorPanel,
      child: SizedBox(
        width: 520,
        height: 380,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📜 HOW TO PLAY',
                style: TextStyle(
                  color: kColorGold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              const Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    '🌍 Build a nation from a Settlement to a Global Capital.\n\n'
                    '🏗️ BUILD: Open the left panel → pick category → tap territory to place.\n\n'
                    '⚔️ TRAIN: Tap a military building → choose a unit from bottom panel.\n\n'
                    '🗺️ MOVE: Tap a unit → green tiles = move · red tiles = attack.\n\n'
                    '🔬 RESEARCH: Top bar flask icon → select a technology to research.\n\n'
                    '🌐 EXPAND: Move units to unclaimed tiles to claim territory.\n\n'
                    '🏆 VICTORY:\n'
                    '  ⚔️  Military — Destroy all enemy capitals\n'
                    '  💰  Economic — Top economy for 5 min\n'
                    '  🗺️  Territorial — Control 75% of map\n'
                    '  🔬  Tech — Complete Future Age research\n'
                    '  🤝  Diplomatic — 3+ alliances + top influence',
                    style: TextStyle(
                      color: kColorText,
                      height: 1.7,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it!'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MBtn extends StatelessWidget {
  final String icon, label;
  final VoidCallback onTap;
  final bool secondary;
  const _MBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.secondary = false,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
      decoration: BoxDecoration(
        border: Border.all(
          color: secondary ? kColorBorder : kColorGoldDark,
          width: secondary ? 1 : 1.5,
        ),
        borderRadius: BorderRadius.circular(6),
        color: secondary
            ? Colors.transparent
            : kColorGoldDark.withValues(alpha: 0.15),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 17)),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: secondary ? kColorMuted : kColorGold,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}

class _GridBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = kColorBorder.withValues(alpha: 0.25)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 16 ▸ SINGLE PLAYER SETUP
// ══════════════════════════════════════════════════════════════════════════════

class SinglePlayerSetupScreen extends StatefulWidget {
  final GameState game;
  const SinglePlayerSetupScreen({super.key, required this.game});
  @override
  State<SinglePlayerSetupScreen> createState() => _SinglePlayerSetupState();
}

class _SinglePlayerSetupState extends State<SinglePlayerSetupScreen> {
  String _nationName = 'My Empire';
  int _colorIdx = 0, _aiCount = 3, _difficulty = 1;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Row(
      children: [
        Container(
          width: 300,
          color: kColorPanel,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                'SINGLE PLAYER',
                style: TextStyle(
                  color: kColorGold,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'NATION NAME',
                style: TextStyle(
                  color: kColorMuted,
                  fontSize: 9,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                initialValue: _nationName,
                style: const TextStyle(color: kColorText),
                decoration: const InputDecoration(hintText: 'Enter name...'),
                onChanged: (v) => setState(() => _nationName = v),
              ),
              const SizedBox(height: 18),
              const Text(
                'NATION COLOR',
                style: TextStyle(
                  color: kColorMuted,
                  fontSize: 9,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                  8,
                  (i) => GestureDetector(
                    onTap: () => setState(() => _colorIdx = i),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: kNationColors[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _colorIdx == i
                              ? Colors.white
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'AI OPPONENTS',
                style: TextStyle(
                  color: kColorMuted,
                  fontSize: 9,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [1, 3, 5, 7]
                    .map(
                      (n) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _Chip(
                          label: '$n',
                          sel: _aiCount == n,
                          onTap: () => setState(() => _aiCount = n),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              const Text(
                'DIFFICULTY',
                style: TextStyle(
                  color: kColorMuted,
                  fontSize: 9,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _Chip(
                    label: 'Easy',
                    sel: _difficulty == 0,
                    onTap: () => setState(() => _difficulty = 0),
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    label: 'Normal',
                    sel: _difficulty == 1,
                    onTap: () => setState(() => _difficulty = 1),
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    label: 'Hard',
                    sel: _difficulty == 2,
                    onTap: () => setState(() => _difficulty = 2),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kColorBorder),
                        foregroundColor: kColorMuted,
                      ),
                      child: const Text('BACK'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _start,
                      child: const Text('▶  START'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              CustomPaint(painter: _GridBgPainter()),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: kNationColors[_colorIdx].withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: kNationColors[_colorIdx],
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Text('🏛️', style: TextStyle(fontSize: 36)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _nationName.isEmpty ? 'My Empire' : _nationName,
                      style: TextStyle(
                        color: kNationColors[_colorIdx],
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_aiCount AI opponents · ${["Easy", "Normal", "Hard"][_difficulty]} difficulty',
                      style: const TextStyle(color: kColorMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: kColorBorder),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Starting resources:',
                            style: TextStyle(
                              color: kColorGold,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '💰 200 Gold   🌾 100 Food',
                            style: TextStyle(color: kColorText, fontSize: 10),
                          ),
                          Text(
                            '🪵 80 Wood    🪨 60 Stone',
                            style: TextStyle(color: kColorText, fontSize: 10),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Units: 3x Builder, 1x Spearman',
                            style: TextStyle(color: kColorMuted, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  void _start() {
    widget.game.initSinglePlayer(
      aiCount: _aiCount,
      difficulty: _difficulty,
      seed: math.Random().nextInt(99999),
      playerNationName: _nationName.isEmpty ? 'My Empire' : _nationName,
      playerColor: kNationColors[_colorIdx],
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(game: widget.game)),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool sel;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.sel, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: sel ? kColorGoldDark : Colors.transparent,
        border: Border.all(color: sel ? kColorGold : kColorBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: sel ? kColorGold : kColorMuted,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 17 ▸ MULTIPLAYER MENU
// ══════════════════════════════════════════════════════════════════════════════

class MultiplayerMenuScreen extends StatefulWidget {
  final GameState game;
  const MultiplayerMenuScreen({super.key, required this.game});
  @override
  State<MultiplayerMenuScreen> createState() => _MultiplayerMenuState();
}

class _MultiplayerMenuState extends State<MultiplayerMenuScreen> {
  final _nameCtrl = TextEditingController(text: 'Commander');
  final _nationCtrl = TextEditingController(text: 'My Empire');
  final _codeCtrl = TextEditingController();
  final _roomCtrl = TextEditingController(text: 'War Room 1');
  bool _connecting = false;
  String? _error;
  int _tab = 0, _colorIdx = 0;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nationCtrl.dispose();
    _codeCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        '🌐  MULTIPLAYER',
        style: TextStyle(color: kColorGold, letterSpacing: 3, fontSize: 13),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: kColorGold),
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: Row(
      children: [
        Container(
          width: 330,
          color: kColorPanel,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PLAYER INFO',
                style: TextStyle(
                  color: kColorMuted,
                  fontSize: 9,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: kColorText),
                decoration: const InputDecoration(labelText: 'Your Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nationCtrl,
                style: const TextStyle(color: kColorText),
                decoration: const InputDecoration(labelText: 'Nation Name'),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: List.generate(
                  kNationColors.length,
                  (i) => GestureDetector(
                    onTap: () => setState(() => _colorIdx = i),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: kNationColors[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _colorIdx == i
                              ? Colors.white
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _TabBtn(
                      label: '🔗 JOIN',
                      sel: _tab == 0,
                      onTap: () => setState(() => _tab = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TabBtn(
                      label: '➕ CREATE',
                      sel: _tab == 1,
                      onTap: () => setState(() => _tab = 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_tab == 0)
                TextField(
                  controller: _codeCtrl,
                  style: const TextStyle(
                    color: kColorText,
                    fontSize: 18,
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(labelText: 'Room Code'),
                  textCapitalization: TextCapitalization.characters,
                )
              else
                TextField(
                  controller: _roomCtrl,
                  style: const TextStyle(color: kColorText),
                  decoration: const InputDecoration(labelText: 'Room Name'),
                ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: kColorAccent, fontSize: 10),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _connecting ? null : _connect,
                  child: _connecting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kColorGold,
                          ),
                        )
                      : Text(_tab == 0 ? '▶  JOIN GAME' : '▶  CREATE ROOM'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              CustomPaint(painter: _GridBgPainter()),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🌐', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 14),
                    const Text(
                      'ONLINE MULTIPLAYER',
                      style: TextStyle(
                        color: kColorGold,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '2–16 Players · Real-Time Strategy',
                      style: TextStyle(color: kColorMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 28),
                    ...[
                      ('⚔️', 'Free-for-All', 'Every nation for itself'),
                      ('🤝', 'Team Battles', 'Allies vs enemies'),
                      ('🏆', 'Ranked Mode', 'Compete globally'),
                      ('🎮', 'Casual Mode', 'Just for fun'),
                    ].map(
                      (r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(r.$1, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.$2,
                                  style: const TextStyle(
                                    color: kColorText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  r.$3,
                                  style: const TextStyle(
                                    color: kColorMuted,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: kColorBorder),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Server: ${MultiplayerService.instance.serverUrl}',
                        style: const TextStyle(color: kColorMuted, fontSize: 9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    final mp = MultiplayerService.instance;
    final ok = await mp.connect();
    if (!ok) {
      setState(() {
        _connecting = false;
        _error = '❌ Cannot connect. Check server URL in Settings.';
      });
      return;
    }
    if (_tab == 1) {
      mp.createRoom(
        roomName: _roomCtrl.text.isEmpty ? 'War Room' : _roomCtrl.text,
        playerName: _nameCtrl.text.isEmpty ? 'Commander' : _nameCtrl.text,
        nationName: _nationCtrl.text.isEmpty ? 'My Empire' : _nationCtrl.text,
        nationColorValue: kNationColors[_colorIdx].toARGB32(),
      );
    } else {
      if (_codeCtrl.text.isEmpty) {
        setState(() {
          _connecting = false;
          _error = '❌ Enter a room code.';
        });
        return;
      }
      mp.joinRoom(
        code: _codeCtrl.text.toUpperCase(),
        playerName: _nameCtrl.text.isEmpty ? 'Commander' : _nameCtrl.text,
        nationName: _nationCtrl.text.isEmpty ? 'My Empire' : _nationCtrl.text,
        nationColorValue: kNationColors[_colorIdx].toARGB32(),
      );
    }
    setState(() => _connecting = false);
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LobbyScreen(game: widget.game)),
      );
    }
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool sel;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.sel, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: sel ? kColorGoldDark : Colors.transparent,
        border: Border.all(color: sel ? kColorGold : kColorBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: sel ? kColorGold : kColorMuted,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 18 ▸ LOBBY SCREEN
// ══════════════════════════════════════════════════════════════════════════════

// LobbyPlayer defined in Section 9

class LobbyScreen extends StatefulWidget {
  final GameState game;
  const LobbyScreen({super.key, required this.game});
  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final List<LobbyPlayer> _players = [];
  bool _ready = false, _isHost = false;
  String _code = '------';
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = MultiplayerService.instance.events.listen(_onEvent);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _code = 'GD${math.Random().nextInt(9000) + 1000}';
          _isHost = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(Map<String, dynamic> msg) {
    if (!mounted) return;
    switch (msg['type']) {
      case 'room_created':
        setState(() {
          _code = msg['data']['code'] ?? _code;
          _isHost = true;
        });
        break;
      case 'room_joined':
        setState(() {
          _code = msg['data']['code'] ?? _code;
        });
        break;
      case 'player_joined':
        setState(() => _players.add(LobbyPlayer.fromJson(msg['data'])));
        break;
      case 'player_left':
        final id = msg['data']['playerId'] as String;
        setState(() => _players.removeWhere((p) => p.id == id));
        break;
      case 'player_ready':
        final id = msg['data']['playerId'] as String;
        setState(() {
          final i = _players.indexWhere((p) => p.id == id);
          if (i >= 0) _players[i].ready = msg['data']['ready'] ?? false;
        });
        break;
      case 'game_started':
        if (msg['data']['gameState'] != null) {
          widget.game.loadFromJson(msg['data']['gameState']);
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => GameScreen(game: widget.game)),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        '🏛️  LOBBY — $_code',
        style: const TextStyle(
          color: kColorGold,
          letterSpacing: 2,
          fontSize: 13,
        ),
      ),
      actions: [
        if (_isHost)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _start,
              child: const Text('▶  START GAME'),
            ),
          ),
      ],
    ),
    body: Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Text(
                      'PLAYERS',
                      style: TextStyle(
                        color: kColorGold,
                        fontSize: 11,
                        letterSpacing: 3,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_players.length + 1} / 8',
                      style: const TextStyle(color: kColorMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    _PRow(
                      name: 'You',
                      nationName: 'My Empire',
                      color: kNationColors[0],
                      ready: _ready,
                      isHost: _isHost,
                    ),
                    ..._players.map(
                      (p) => _PRow(
                        name: p.name,
                        nationName: p.nationName,
                        color: p.nationColor,
                        ready: p.ready,
                        isHost: false,
                      ),
                    ),
                    ...List.generate(
                      math.max(0, 7 - _players.length),
                      (_) => _EmptyRow(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(width: 1, color: kColorBorder),
        SizedBox(
          width: 270,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ROOM INFO',
                  style: TextStyle(
                    color: kColorGold,
                    fontSize: 11,
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _IR('Code', _code, hi: true),
                _IR('Mode', 'Free-for-All'),
                _IR('Map', '30 × 20'),
                _IR('Players', 'Max 8'),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: kColorGoldDark),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Share Code',
                        style: TextStyle(color: kColorMuted, fontSize: 10),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _code,
                        style: const TextStyle(
                          color: kColorGold,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (!_isHost) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _ready = !_ready);
                        MultiplayerService.instance.setReady(_ready);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _ready
                            ? kColorSuccess.withValues(alpha: 0.2)
                            : kColorGoldDark,
                      ),
                      child: Text(_ready ? '✅ READY' : '⬜ MARK READY'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      MultiplayerService.instance.leaveRoom();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kColorAccent),
                      foregroundColor: kColorAccent,
                    ),
                    child: const Text('LEAVE ROOM'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  void _start() {
    MultiplayerService.instance.startGame();
    widget.game.initSinglePlayer(
      aiCount: _players.isEmpty ? 3 : _players.length,
      difficulty: 1,
      seed: math.Random().nextInt(99999),
      playerNationName: 'My Empire',
      playerColor: kNationColors[0],
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(game: widget.game)),
    );
  }
}

class _PRow extends StatelessWidget {
  final String name, nationName;
  final Color color;
  final bool ready, isHost;
  const _PRow({
    required this.name,
    required this.nationName,
    required this.color,
    required this.ready,
    required this.isHost,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 7),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      border: Border.all(
        color: ready ? kColorSuccess.withValues(alpha: 0.5) : kColorBorder,
      ),
      borderRadius: BorderRadius.circular(6),
      color: kColorPanel,
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: const Center(
            child: Text('🏛️', style: TextStyle(fontSize: 17)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: kColorText,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  if (isHost)
                    const Padding(
                      padding: EdgeInsets.only(left: 5),
                      child: Text('👑', style: TextStyle(fontSize: 10)),
                    ),
                ],
              ),
              Text(nationName, style: TextStyle(color: color, fontSize: 9)),
            ],
          ),
        ),
        Text(ready ? '✅' : '⏳', style: const TextStyle(fontSize: 14)),
      ],
    ),
  );
}

class _EmptyRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 7),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      border: Border.all(color: kColorBorder.withValues(alpha: 0.35)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Row(
      children: [
        SizedBox(
          width: 34,
          height: 34,
          child: Center(
            child: Text(
              '···',
              style: TextStyle(color: kColorBorder, fontSize: 14),
            ),
          ),
        ),
        SizedBox(width: 10),
        Text(
          'Waiting for player...',
          style: TextStyle(color: kColorBorder, fontSize: 11),
        ),
      ],
    ),
  );
}

class _IR extends StatelessWidget {
  final String l, v;
  final bool hi;
  const _IR(this.l, this.v, {this.hi = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Text('$l:', style: const TextStyle(color: kColorMuted, fontSize: 10)),
        const SizedBox(width: 8),
        Text(
          v,
          style: TextStyle(
            color: hi ? kColorGold : kColorText,
            fontSize: 10,
            fontWeight: hi ? FontWeight.bold : FontWeight.normal,
            letterSpacing: hi ? 2 : 0,
          ),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 19 ▸ GAME SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class GameScreen extends StatefulWidget {
  final GameState game;
  const GameScreen({super.key, required this.game});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Timer? _tick, _ai;
  bool _nationsOpen = false;
  int _buildCat = 0;
  bool _victoryShown = false;
  StreamSubscription? _mpSub;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(Duration(milliseconds: kTickMs), (_) {
      if (widget.game.phase == GamePhase.playing) {
        widget.game.processTick();
        if (!_victoryShown && widget.game.phase == GamePhase.ended) {
          _victoryShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _showVictory());
        }
      }
    });
    _ai = Timer.periodic(Duration(milliseconds: kAiTickMs), (_) {
      if (widget.game.phase != GamePhase.playing) return;
      for (final n in widget.game.nations.values) {
        if (n.isAI && n.isAlive) AIEngine(widget.game, n).processTick();
      }
    });
    if (MultiplayerService.instance.connected) {
      _mpSub = MultiplayerService.instance.events.listen((msg) {
        if (!mounted) return;
        if (msg['type'] == 'game_state') widget.game.loadFromJson(msg['data']);
        if (msg['type'] == 'chat_msg') {
          widget.game.addChatMessage(
            msg['data']['sender'] ?? '?',
            msg['data']['message'] ?? '',
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _ai?.cancel();
    _mpSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.game,
    builder: (_, _) => Scaffold(
      backgroundColor: const Color(0xFF06101A),
      body: Stack(
        children: [
          Positioned.fill(child: GameMapWidget(game: widget.game)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: TopBar(
              game: widget.game,
              onNations: () => setState(() => _nationsOpen = !_nationsOpen),
              onTech: _showTech,
              onDipl: _showDipl,
            ),
          ),
          Positioned(
            left: 0,
            top: 62,
            bottom: 150,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: _nationsOpen ? 210 : 0,
              child: OverflowBox(
                maxWidth: 210,
                alignment: Alignment.centerLeft,
                child: NationPanel(game: widget.game),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomToolbar(
              game: widget.game,
              cat: _buildCat,
              onCat: (c) => setState(() => _buildCat = c),
            ),
          ),
          Positioned(
            right: 14,
            top: 76,
            child: _ActionRail(
              onCenter: () {},
              onBuild: () =>
                  setState(() => _buildCat = _buildCat == -1 ? 0 : -1),
              onTech: _showTech,
              onDipl: _showDipl,
              onNations: () => setState(() => _nationsOpen = !_nationsOpen),
              onCancel: () {
                widget.game.clearSelection();
                widget.game.rebuild();
              },
            ),
          ),
          Positioned(
            left: 12,
            bottom: 160,
            child: _EventLog(game: widget.game),
          ),
        ],
      ),
    ),
  );

  void _showVictory() => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => VictoryDialog(
      game: widget.game,
      onExit: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => MainMenuScreen(game: widget.game)),
          (_) => false,
        );
      },
    ),
  );
  void _showTech() => showDialog(
    context: context,
    builder: (_) => TechDialog(game: widget.game),
  );
  void _showDipl() => showDialog(
    context: context,
    builder: (_) => DiplomacyDialog(game: widget.game),
  );
}

// ── Bottom Toolbar (replaces BuildPanel + SelectionPanel) ─────────────────

class BottomToolbar extends StatefulWidget {
  final GameState game;
  final int cat;
  final ValueChanged<int> onCat;
  const BottomToolbar({
    super.key,
    required this.game,
    required this.cat,
    required this.onCat,
  });
  @override
  State<BottomToolbar> createState() => _BottomToolbarState();
}

class _BottomToolbarState extends State<BottomToolbar> {
  static const _cats = ['💰', '⚔️', '🛡️', '🔬', '⭐'];
  static const _labs = ['Eco', 'Mil', 'Def', 'Tech', 'Spec'];
  static const _types = [
    BuildingCat.economic,
    BuildingCat.military,
    BuildingCat.defensive,
    BuildingCat.technology,
    BuildingCat.special,
  ];
  final ScrollController _buildScroll = ScrollController();

  @override
  void dispose() {
    _buildScroll.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    if (!_buildScroll.hasClients) return;
    final target = (_buildScroll.offset + delta).clamp(
      0.0,
      _buildScroll.position.maxScrollExtent,
    );
    _buildScroll.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final n = game.playerNation;
    final unit = game.selUnitId != null ? game.units[game.selUnitId!] : null;
    final building = game.selBuildingId != null
        ? game.buildings[game.selBuildingId!]
        : null;
    final multiSel = game.selectedUnitIds.isNotEmpty;

    // Selection info overlay — docked card above the build menu
    Widget? selInfo;
    if (multiSel) {
      selInfo = Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xEE060C18),
          border: Border(
            top: BorderSide(
              color: kColorGold.withValues(alpha: 0.40),
              width: 1.2,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kColorGold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kColorGold.withValues(alpha: 0.35)),
              ),
              child: Text(
                '⚔️  ${game.selectedUnitIds.length} units selected',
                style: const TextStyle(
                  color: kColorGold,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                game.clearMultiSelection();
                game.rebuild();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: kColorBorder),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  '✕  Clear',
                  style: TextStyle(color: kColorMuted, fontSize: 9),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (unit != null) {
      final d = unit.def;
      final hpFrac = unit.maxHealth > 0
          ? (unit.health / unit.maxHealth).clamp(0.0, 1.0)
          : 0.0;
      selInfo = Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xEE060C18),
          border: Border(
            top: BorderSide(
              color: kColorGold.withValues(alpha: 0.40),
              width: 1.2,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: kColorGold.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(color: kColorGold.withValues(alpha: 0.30)),
              ),
              child: Center(
                child: Text(d.emoji, style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.name,
                    style: const TextStyle(
                      color: kColorText,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Container(
                            height: 5,
                            color: kColorBorder,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: hpFrac,
                              child: Container(
                                color: hpFrac > 0.4
                                    ? kColorSuccess
                                    : kColorAccent,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${unit.health}/${unit.maxHealth} HP',
                        style: const TextStyle(color: kColorMuted, fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kColorBorder),
              ),
              child: Text(
                '⚔ ${d.attack}  🛡 ${d.defense}  🏃 ${d.speed}',
                style: const TextStyle(color: kColorMuted, fontSize: 9),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                game.clearSelection();
                game.rebuild();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: kColorBorder),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  '✕ Deselect',
                  style: TextStyle(color: kColorMuted, fontSize: 9),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (building != null && building.nationId == game.playerNationId) {
      final d = building.def;
      final hpFrac = building.maxHealth > 0
          ? (building.health / building.maxHealth).clamp(0.0, 1.0)
          : 0.0;
      selInfo = Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xEE060C18),
          border: Border(
            top: BorderSide(
              color: kColorGold.withValues(alpha: 0.40),
              width: 1.2,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: kColorGold.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(color: kColorGold.withValues(alpha: 0.30)),
              ),
              child: Center(
                child: Text(d.emoji, style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.name,
                    style: const TextStyle(
                      color: kColorText,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Container(
                            height: 5,
                            color: kColorBorder,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: hpFrac,
                              child: Container(
                                color: hpFrac > 0.4
                                    ? kColorSuccess
                                    : kColorAccent,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (building.isConstructing)
                        Text(
                          '⏳ Building… ${building.buildTicksLeft}t',
                          style: const TextStyle(
                            color: kColorGold,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else if (building.trainingUnitDefId != null)
                        Text(
                          '🎯 Training: ${kUnitDefs[building.trainingUnitDefId!]?.name ?? '?'} (${building.trainingTicksLeft}t)',
                          style: const TextStyle(
                            color: kColorGold,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else
                        Text(
                          '${building.health}/${building.maxHealth} HP',
                          style: const TextStyle(
                            color: kColorMuted,
                            fontSize: 9,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Train buttons
            if (d.unlocks.isNotEmpty && !building.isConstructing)
              ...d.unlocks.map((uid) {
                final ud = kUnitDefs[uid];
                if (ud == null) return const SizedBox.shrink();
                final ok = n?.resources.canAfford(ud.cost) ?? false;
                return GestureDetector(
                  onTap: () {
                    if (building.trainingUnitDefId != null) return;
                    game.trainUnit(game.playerNationId!, building.id, uid);
                  },
                  child: Tooltip(
                    message: ud.name,
                    child: Container(
                      margin: const EdgeInsets.only(left: 5),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: ok
                            ? kColorGold.withValues(alpha: 0.12)
                            : Colors.transparent,
                        border: Border.all(
                          color: ok
                              ? kColorGold.withValues(alpha: 0.45)
                              : kColorBorder,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ud.emoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      );
    }

    // Building cards
    final defs = kBuildingDefs.values
        .where((d) => d.category == _types[widget.cat])
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?selInfo,
        // Category pill-tabs
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: const BoxDecoration(
            color: Color(0xFF080F1C),
            border: Border(top: BorderSide(color: kColorBorder, width: 1)),
          ),
          child: Row(
            children: [
              ...List.generate(
                5,
                (i) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => widget.onCat(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: widget.cat == i
                            ? kColorGold.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.04),
                        border: Border.all(
                          color: widget.cat == i
                              ? kColorGold
                              : kColorBorder.withValues(alpha: 0.55),
                          width: widget.cat == i ? 1.3 : 0.8,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_cats[i]} ${_labs[i]}',
                        style: TextStyle(
                          color: widget.cat == i ? kColorGold : kColorMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (game.pendingBuildDefId != null)
                GestureDetector(
                  onTap: () {
                    game.pendingBuildDefId = null;
                    game.rebuild();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: kColorAccent.withValues(alpha: 0.18),
                      border: Border.all(
                        color: kColorAccent.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      '✖ Cancel',
                      style: TextStyle(
                        color: kColorAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Building card row, with carousel nav arrows
        Container(
          height: 112,
          decoration: BoxDecoration(
            color: const Color(0xEE060C18),
            border: Border(
              top: BorderSide(
                color: kColorGold.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              _NavArrow(icon: '‹', onTap: () => _scrollBy(-220)),
              Expanded(
                child: ListView.builder(
                  controller: _buildScroll,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  itemCount: defs.length,
                  itemBuilder: (_, i) {
                    final d = defs[i];
                    final afford = n?.resources.canAfford(d.cost) == true;
                    final ageOk =
                        d.requiredAge.index2 <= (n?.currentAge.index2 ?? 0);
                    final sel = game.pendingBuildDefId == d.id;
                    return _BuildCard(
                      def: d,
                      selected: sel,
                      afford: afford,
                      ageOk: ageOk,
                      onTap: () {
                        if (!ageOk) {
                          game.addEvent(
                            '❌ Requires ${d.requiredAge.label}!',
                            color: kColorAccent,
                          );
                          return;
                        }
                        game.pendingBuildDefId = d.id;
                        game.addEvent(
                          '👆 Tap territory to place ${d.name}',
                          color: kColorGold,
                        );
                        game.rebuild();
                      },
                    );
                  },
                ),
              ),
              _NavArrow(icon: '›', onTap: () => _scrollBy(220)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Build Card (used by Bottom Toolbar) ─────────────────────────────────────

class _BuildCard extends StatelessWidget {
  final BuildingDef def;
  final bool selected, afford, ageOk;
  final VoidCallback onTap;
  const _BuildCard({
    required this.def,
    required this.selected,
    required this.afford,
    required this.ageOk,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locked = !ageOk;
    final labelCol = locked
        ? kColorMuted
        : (afford ? kColorText : kColorAccent);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 96,
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    kColorGold.withValues(alpha: 0.22),
                    kColorGoldDark.withValues(alpha: 0.10),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: locked ? 0.02 : 0.04),
                    Colors.white.withValues(alpha: 0.01),
                  ],
                ),
          border: Border.all(
            color: selected
                ? kColorGold
                : locked
                ? kColorBorder.withValues(alpha: 0.25)
                : afford
                ? kColorBorder.withValues(alpha: 0.55)
                : kColorAccent.withValues(alpha: 0.35),
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: kColorGold.withValues(alpha: 0.30),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon circle
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected
                        ? kColorGold.withValues(alpha: 0.18)
                        : kColorBorder.withValues(alpha: locked ? 0.08 : 0.22),
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(
                            color: kColorGold.withValues(alpha: 0.50),
                            width: 1,
                          )
                        : null,
                  ),
                  child: Center(
                    child: Opacity(
                      opacity: locked ? 0.35 : 1.0,
                      child: Text(
                        def.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Name
                Text(
                  def.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: labelCol,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                // Cost badge
                if (def.cost.containsKey('gold'))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (afford && !locked ? kColorGold : kColorAccent)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '💰 ${def.cost['gold']!.toInt()}',
                      style: TextStyle(
                        color: afford && !locked ? kColorGold : kColorAccent,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (locked)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E1A),
                    shape: BoxShape.circle,
                    border: Border.all(color: kColorBorder, width: 0.8),
                  ),
                  child: const Center(
                    child: Text('🔒', style: TextStyle(fontSize: 8)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 24,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      alignment: Alignment.center,
      child: Text(
        icon,
        style: const TextStyle(
          color: kColorGold,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

// ── Event Log Overlay ────────────────────────────────────────────────────────

class _EventLog extends StatelessWidget {
  final GameState game;
  const _EventLog({required this.game});
  @override
  Widget build(BuildContext context) {
    final recent = game.events.take(5).toList();
    if (recent.isEmpty) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(maxWidth: 320, maxHeight: 110),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF07101B).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(
            color: kColorGoldDark.withValues(alpha: 0.7),
            width: 2,
          ),
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recent.length,
        itemBuilder: (_, i) {
          final e = recent[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              e.message,
              style: TextStyle(
                color: e.color.withValues(alpha: 1.0 - i * 0.15),
                fontSize: 9,
                height: 1.2,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Action Rail (right side) ─────────────────────────────────────────────────

class _ActionRail extends StatelessWidget {
  final VoidCallback onCenter, onBuild, onTech, onDipl, onNations, onCancel;
  const _ActionRail({
    required this.onCenter,
    required this.onBuild,
    required this.onTech,
    required this.onDipl,
    required this.onNations,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    decoration: BoxDecoration(
      color: const Color(0xEE060C18),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: kColorGold.withValues(alpha: 0.18)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _rail('◎', onCenter, 'Center Camera'),
        _railDiv(),
        _rail('↔', onBuild, 'Build Mode'),
        _rail('✕', onCancel, 'Cancel / Deselect'),
        _railDiv(),
        _rail('⚔', onTech, 'Research'),
        _rail('👥', onNations, 'Nations'),
        _rail('💬', onDipl, 'Diplomacy'),
      ],
    ),
  );

  static Widget _railDiv() => Container(
    width: 28,
    height: 1,
    margin: const EdgeInsets.symmetric(vertical: 2),
    color: kColorGold.withValues(alpha: 0.12),
  );

  static Widget _rail(String icon, VoidCallback cb, String tip) => Tooltip(
    message: tip,
    preferBelow: false,
    child: InkWell(
      onTap: cb,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
        child: Center(
          child: Text(
            icon,
            style: const TextStyle(
              color: Color(0xFFD4C9A8),
              fontSize: 19,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 19B ▸ HUD SHARED WIDGETS — Cut-Corner Rank Badge System
// ══════════════════════════════════════════════════════════════════════════════
// A recurring clipped-corner silhouette (echoes a wax seal / rank insignia)
// reserved for identity elements: the Admiral portrait, the Age/Tier badge,
// and the #1 leaderboard crest. Everything else in the HUD stays plain
// rounded-rect so this motif keeps reading as a deliberate signature.

class _CutCornerClipper extends CustomClipper<Path> {
  final double cut;
  const _CutCornerClipper({this.cut = 9});
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height, c = cut;
    return Path()
      ..moveTo(c, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h - c)
      ..lineTo(w - c, h)
      ..lineTo(0, h)
      ..lineTo(0, c)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _CutCornerBorderPainter extends CustomPainter {
  final Color color;
  final double cut, strokeWidth;
  _CutCornerBorderPainter({
    required this.color,
    this.cut = 9,
    this.strokeWidth = 1.4,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, c = cut;
    final path = Path()
      ..moveTo(c, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h - c)
      ..lineTo(w - c, h)
      ..lineTo(0, h)
      ..lineTo(0, c)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _CutCornerBorderPainter old) =>
      old.color != color || old.cut != cut || old.strokeWidth != strokeWidth;
}

class _CutCornerFrame extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final Color fill;
  final double cut;
  final double borderWidth;
  const _CutCornerFrame({
    required this.child,
    this.borderColor = kColorGold,
    this.fill = kColorPanel,
    this.cut = 9.0,
  }) : borderWidth = 1.4;
  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: _CutCornerClipper(cut: cut),
    child: CustomPaint(
      painter: _CutCornerBorderPainter(
        color: borderColor,
        cut: cut,
        strokeWidth: borderWidth,
      ),
      child: Container(color: fill, child: child),
    ),
  );
}

class _VDiv extends StatelessWidget {
  final double height;
  const _VDiv() : height = 28.0;
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: height,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: kColorBorder,
  );
}

class _TopIconBtn extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;
  final String tip;
  final VoidCallback? onLongPress;
  const _TopIconBtn(this.icon, this.onTap, this.tip, {this.onLongPress});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tip,
    child: InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Center(child: Text(icon, style: const TextStyle(fontSize: 15))),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 20 ▸ TOP RESOURCE BAR
// ══════════════════════════════════════════════════════════════════════════════

class TopBar extends StatelessWidget {
  final GameState game;
  final VoidCallback onNations, onTech, onDipl;
  const TopBar({
    super.key,
    required this.game,
    required this.onNations,
    required this.onTech,
    required this.onDipl,
  });

  @override
  Widget build(BuildContext context) {
    final r = game.playerNation?.resources;
    final n = game.playerNation;
    final col = n?.color ?? kColorGold;
    final name = n?.name ?? 'Admiral';
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xE6080F1C),
        border: Border(
          bottom: BorderSide(
            color: kColorGold.withValues(alpha: 0.28),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Nation accent strip
          Container(width: 3, height: 62, color: col),
          const SizedBox(width: 12),
          // Resource group — left
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ResPill('💰', r?.gold.floor() ?? 0, kColorGold),
                  _ResPill('🌾', r?.food.floor() ?? 0, kColorSuccess),
                  _ResPill('🪵', r?.wood.floor() ?? 0, const Color(0xFFBD9A60)),
                  _ResPill(
                    '🪨',
                    r?.stone.floor() ?? 0,
                    const Color(0xFF94A3B8),
                  ),
                  _ResPill('⚙️', r?.iron.floor() ?? 0, const Color(0xFF93A8C2)),
                  _ResPill('🛢️', r?.oil.floor() ?? 0, const Color(0xFF9CA3AF)),
                  _ResPillCapped(
                    '👥',
                    r?.population ?? 0,
                    r?.populationCap ?? 20,
                    kColorText,
                  ),
                  _ResPill(
                    '🔬',
                    r?.researchPoints ?? 0,
                    const Color(0xFF60A5FA),
                  ),
                ],
              ),
            ),
          ),
          // Age badge — tap to advance
          if (n != null)
            GestureDetector(
              onTap: () => game.advanceAge(game.playerNationId!),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: kColorGoldDark.withValues(alpha: 0.20),
                  border: Border.all(color: kColorGold.withValues(alpha: 0.60)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${n.tier.label} · ${n.currentAge.label}',
                  style: const TextStyle(
                    color: kColorGold,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          // Research button
          GestureDetector(
            onTap: onTech,
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: kColorGold.withValues(alpha: 0.12),
                border: Border.all(color: kColorGold.withValues(alpha: 0.50)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Research',
                style: TextStyle(
                  color: kColorGold,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          // Settings icon
          _TopIconBtn(
            '⚙️',
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings — coming soon'),
                  duration: Duration(seconds: 1),
                  backgroundColor: kColorPanel,
                ),
              );
            },
            'Settings',
            onLongPress: () => showDialog(
              context: context,
              builder: (_) => AdminLoginDialog(game: game),
            ),
          ),
          const SizedBox(width: 6),
          // Admiral portrait + name block
          Container(
            margin: const EdgeInsets.only(right: 10, left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: col.withValues(alpha: 0.12),
              border: Border.all(color: col.withValues(alpha: 0.45)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar frame
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: col.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: col.withValues(alpha: 0.65)),
                  ),
                  child: Center(
                    child: Text(
                      _admiralEmoji(name),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: col,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '− ${n?.currentAge.label ?? "Ancient Age"}',
                      style: const TextStyle(color: kColorMuted, fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _f(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }
}

class _ResPill extends StatelessWidget {
  final String icon;
  final int val;
  final Color tint;
  const _ResPill(this.icon, this.val, this.tint);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            TopBar._f(val),
            style: const TextStyle(
              color: kColorText,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// Capped resource pill (for population)
class _ResPillCapped extends StatelessWidget {
  final String icon;
  final int val, cap;
  final Color tint;
  const _ResPillCapped(this.icon, this.val, this.cap, this.tint);
  @override
  Widget build(BuildContext context) {
    final capped = val >= cap;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '$val/$cap',
            style: TextStyle(
              color: capped ? kColorAccent : kColorText,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 21 ▸ GAME MAP
// ══════════════════════════════════════════════════════════════════════════════

String _admiralEmoji(String nationName) {
  final n = nationName.toLowerCase();
  if (n.contains('azure') || n.contains('british')) return '🧭';
  if (n.contains('jade') || n.contains('dynasty')) return '🎎';
  if (n.contains('horde') || n.contains('viking')) return '🪓';
  if (n.contains('sultan') || n.contains('ottoman')) return '🕌';
  if (n.contains('crimson') || n.contains('roman')) return '🛡️';
  return '🧑‍✈️';
}

class GameMapWidget extends StatefulWidget {
  final GameState game;
  const GameMapWidget({super.key, required this.game});
  @override
  State<GameMapWidget> createState() => _GameMapWidgetState();
}

class _GameMapWidgetState extends State<GameMapWidget>
    with TickerProviderStateMixin {
  final TransformationController _tc = TransformationController();
  double _admiralX = kMapW / 2;
  double _admiralY = kMapH / 2;
  double _cameraYaw = 0;
  // Sprint & Jump
  double _jumpHeight = 0;
  bool _isSprinting = false;
  Timer? _animTimer;
  // Drag-to-attack
  Offset? _dragStart, _dragCurrent;
  bool _isDragAttacking = false;
  // Selection box
  Offset? _selBoxStart, _selBoxEnd;
  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = MediaQuery.of(context).size;
      final sc =
          math.min(
            s.width / (kMapW * kTileSize),
            (s.height - 160) / (kMapH * kTileSize),
          ) *
          0.72;
      final matrix = _tc.value.clone()
        ..setIdentity()
        ..translate(s.width * 0.34, 50.0)
        ..scale(sc);
      _tc.value = matrix;
    });
    // Animation timer for jump decay
    _animTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      bool changed = false;
      if (_jumpHeight > 0.1) {
        _jumpHeight *= 0.88;
        changed = true;
      } else if (_jumpHeight > 0) {
        _jumpHeight = 0;
        changed = true;
      }
      // Track sprint state
      final sprinting = HardwareKeyboard.instance.isShiftPressed;
      if (sprinting != _isSprinting) {
        _isSprinting = sprinting;
        changed = true;
      }
      if (changed) setState(() {});
    });
  }

  @override
  void dispose() {
    _tc.dispose();
    _animTimer?.cancel();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails d) {
    final pos = _tc.toScene(d.localPosition);
    final tile = MapPainter.sceneToTile(pos);
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    // Check if dragging from a selected unit
    final selUnit = widget.game.selUnitId != null
        ? widget.game.units[widget.game.selUnitId!]
        : null;
    if (!isShift &&
        selUnit != null &&
        (selUnit.x - tile.$1).abs() <= 1 &&
        (selUnit.y - tile.$2).abs() <= 1) {
      _isDragAttacking = true;
      _dragStart = pos;
      _dragCurrent = pos;
    } else if (isShift) {
      _isSelecting = true;
      _selBoxStart = pos;
      _selBoxEnd = pos;
    }
  }

  void _handleDragUpdate(DragUpdateDetails d) {
    final pos = _tc.toScene(d.localPosition);
    setState(() {
      if (_isDragAttacking) {
        _dragCurrent = pos;
      } else if (_isSelecting) {
        _selBoxEnd = pos;
      } else if (d.delta.dx.abs() > d.delta.dy.abs()) {
        _cameraYaw += d.delta.dx * 0.0008;
      }
    });
  }

  void _handleDragEnd(DragEndDetails d) {
    if (_isDragAttacking && _dragStart != null && _dragCurrent != null) {
      final endTile = MapPainter.sceneToTile(_dragCurrent!);
      if (widget.game.map.isValid(endTile.$1, endTile.$2)) {
        widget.game.handleTileAction(endTile.$1, endTile.$2);
      }
    }
    if (_isSelecting && _selBoxStart != null && _selBoxEnd != null) {
      final s = MapPainter.sceneToTile(_selBoxStart!);
      final e = MapPainter.sceneToTile(_selBoxEnd!);
      widget.game.selectUnitsInRect(
        s.$1.toDouble(),
        s.$2.toDouble(),
        e.$1.toDouble(),
        e.$2.toDouble(),
      );
      widget.game.rebuild();
    }
    setState(() {
      _isDragAttacking = false;
      _dragStart = null;
      _dragCurrent = null;
      _isSelecting = false;
      _selBoxStart = null;
      _selBoxEnd = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        final sprint = HardwareKeyboard.instance.isShiftPressed;
        final step = sprint ? 0.7 : 0.35;
        setState(() {
          if (key == LogicalKeyboardKey.keyW) _admiralY -= step;
          if (key == LogicalKeyboardKey.keyS) _admiralY += step;
          if (key == LogicalKeyboardKey.keyA) _admiralX -= step;
          if (key == LogicalKeyboardKey.keyD) _admiralX += step;
          if (key == LogicalKeyboardKey.keyQ) _cameraYaw -= 0.04;
          if (key == LogicalKeyboardKey.keyE) _cameraYaw += 0.04;
          if (key == LogicalKeyboardKey.space) {
            _jumpHeight = 35.0;
          }
          _admiralX = _admiralX.clamp(1, kMapW - 2);
          _admiralY = _admiralY.clamp(1, kMapH - 2);
        });
        return KeyEventResult.handled;
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF76BFE7), Color(0xFF345A44), Color(0xFF07101B)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _tc,
                minScale: 0.24,
                maxScale: 3.8,
                constrained: false,
                child: GestureDetector(
                  onTapUp: (d) {
                    final pos = _tc.toScene(d.localPosition);
                    final tile = MapPainter.sceneToTile(pos);
                    if (widget.game.map.isValid(tile.$1, tile.$2)) {
                      setState(() {
                        _admiralX = tile.$1 + 0.5;
                        _admiralY = tile.$2 + 0.5;
                      });
                      widget.game.handleTileAction(tile.$1, tile.$2);
                    }
                  },
                  onPanStart: _handleDragStart,
                  onPanUpdate: _handleDragUpdate,
                  onPanEnd: _handleDragEnd,
                  child: SizedBox(
                    width: MapPainter.sceneWidth,
                    height: MapPainter.sceneHeight,
                    child: ListenableBuilder(
                      listenable: widget.game,
                      builder: (_, _) => CustomPaint(
                        painter: MapPainter(
                          game: widget.game,
                          admiralX: _admiralX,
                          admiralY: _admiralY,
                          cameraYaw: _cameraYaw,
                          jumpHeight: _jumpHeight,
                          dragStart: _dragStart,
                          dragCurrent: _dragCurrent,
                          selBoxStart: _selBoxStart,
                          selBoxEnd: _selBoxEnd,
                        ),
                        size: const Size(
                          MapPainter.sceneWidth,
                          MapPainter.sceneHeight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 268,
              bottom: 120,
              child: _AdmiralHint(game: widget.game),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdmiralHint extends StatelessWidget {
  final GameState game;
  const _AdmiralHint({required this.game});

  @override
  Widget build(BuildContext context) {
    final tile = (game.selX != null && game.selY != null)
        ? game.map.at(game.selX!, game.selY!)
        : null;
    final label = tile == null
        ? 'Admiral Command'
        : '${tile.terrain.name.toUpperCase()}  (${tile.x},${tile.y})';
    final sub = tile?.ownerNationId == null
        ? 'Unclaimed'
        : game.nations[tile!.ownerNationId!]?.name ?? 'Controlled';
    return Container(
      constraints: const BoxConstraints(minWidth: 210, maxWidth: 300),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF07101B).withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: kColorGoldDark.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: kColorGold.withValues(alpha: 0.65)),
            ),
            child: const Center(
              child: Text('🧭', style: TextStyle(fontSize: 25)),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kColorText,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  sub,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kColorMuted, fontSize: 10),
                ),
                const Text(
                  'WASD move · Q/E rotate · wheel zoom',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFFB7C2CF), fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MapPainter extends CustomPainter {
  final GameState game;
  final double admiralX, admiralY, cameraYaw, jumpHeight;
  final Offset? dragStart, dragCurrent, selBoxStart, selBoxEnd, hoverTile;
  MapPainter({
    required this.game,
    this.admiralX = kMapW / 2,
    this.admiralY = kMapH / 2,
    this.cameraYaw = 0,
    this.jumpHeight = 0,
    this.dragStart,
    this.dragCurrent,
    this.selBoxStart,
    this.selBoxEnd,
    this.hoverTile,
  });

  static const double tileW = 64;
  static const double tileH = 34;
  static const double sceneWidth = 2200;
  static const double sceneHeight = 1320;

  static Offset tileToScene(num x, num y, [double z = 0]) {
    final sx = sceneWidth / 2 + (x - y) * tileW / 2;
    final sy = 150 + (x + y) * tileH / 2 - z;
    return Offset(sx.toDouble(), sy.toDouble());
  }

  static (int, int) sceneToTile(Offset p) {
    final dx = p.dx - sceneWidth / 2;
    final dy = p.dy - 150;
    final x = (dy / tileH + dx / tileW).floor();
    final y = (dy / tileH - dx / tileW).floor();
    return (x.clamp(0, kMapW - 1), y.clamp(0, kMapH - 1));
  }

  @override
  void paint(Canvas canvas, Size size) {
    _sky(canvas, size);
    canvas.save();
    canvas.translate(sceneWidth / 2, 690);
    canvas.rotate(cameraYaw);
    canvas.translate(-sceneWidth / 2, -690);
    _isoTerrain(canvas);
    _isoTerritory(canvas);
    _isoHighlights(canvas);
    _isoBuildings(canvas);
    _isoUnits(canvas);
    _isoAdmiral(canvas);
    _isoSelection(canvas);
    _multiUnitHighlights(canvas);
    _pathOverlay(canvas);
    _commandArrow(canvas);
    _selectionBox(canvas);
    canvas.restore();
    _combatEffects(canvas);
  }

  double _heightFor(MapTile t) {
    switch (t.terrain) {
      case TerrainType.mountain:
        return 34;
      case TerrainType.forest:
        return 12;
      case TerrainType.tundra:
        return 10;
      case TerrainType.desert:
        return 5;
      case TerrainType.water:
        return -8;
      case TerrainType.plains:
        return 7;
    }
  }

  Path _diamond(num x, num y, [double z = 0]) {
    final top = tileToScene(x + 0.5, y, z);
    final right = tileToScene(x + 1, y + 0.5, z);
    final bottom = tileToScene(x + 0.5, y + 1, z);
    final left = tileToScene(x, y + 0.5, z);
    return Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..lineTo(left.dx, left.dy)
      ..close();
  }

  Offset _center(num x, num y, [double z = 0]) =>
      tileToScene(x + 0.5, y + 0.5, z);

  void _sky(Canvas c, Size size) {
    final haze = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFD2F0FF), Color(0xFF7FB86B), Color(0xFF0B141E)],
      ).createShader(Offset.zero & size);
    c.drawRect(Offset.zero & size, haze);
    c.drawCircle(
      const Offset(sceneWidth - 280, 150),
      42,
      Paint()..color = const Color(0xFFFFD274).withValues(alpha: 0.75),
    );
  }

  void _isoTerrain(Canvas c) {
    final stroke = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    for (int y = 0; y < kMapH; y++) {
      for (int x = 0; x < kMapW; x++) {
        final t = game.map.at(x, y);
        final h = _heightFor(t);
        final tile = _diamond(x, y, h);
        final base = Paint()..color = _terrainColor(t.terrain);
        c.drawPath(tile, base);
        c.drawPath(tile, stroke);
        if (t.terrain == TerrainType.forest) _treeCluster(c, x, y, h);
        if (t.terrain == TerrainType.mountain) _mountain(c, x, y, h);
        if (t.terrain == TerrainType.water) _waterLines(c, x, y, h);
      }
    }
  }

  Color _terrainColor(TerrainType terrain) {
    switch (terrain) {
      case TerrainType.plains:
        return const Color(0xFF79AF52);
      case TerrainType.forest:
        return const Color(0xFF2F7D3B);
      case TerrainType.mountain:
        return const Color(0xFF817A6F);
      case TerrainType.water:
        return const Color(0xFF2C7DA9);
      case TerrainType.desert:
        return const Color(0xFFD9B56A);
      case TerrainType.tundra:
        return const Color(0xFFDCE8E7);
    }
  }

  void _isoTerritory(Canvas c) {
    for (int y = 0; y < kMapH; y++) {
      for (int x = 0; x < kMapW; x++) {
        final t = game.map.at(x, y);
        if (t.ownerNationId == null) continue;
        final color = game.nations[t.ownerNationId!]?.color ?? Colors.grey;
        c.drawPath(
          _diamond(x, y, _heightFor(t) + 1),
          Paint()..color = color.withValues(alpha: 0.28),
        );
        // Nation-colored borders at territory edges
        final h = _heightFor(t) + 2;
        final bp = Paint()
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..color = color.withValues(alpha: 0.8);
        final ns = [
          [-1, 0],
          [1, 0],
          [0, -1],
          [0, 1],
        ];
        final edges = [
          [tileToScene(x + 0.5, y, h), tileToScene(x, y + 0.5, h)],
          [tileToScene(x + 1, y + 0.5, h), tileToScene(x + 0.5, y + 1, h)],
          [tileToScene(x + 0.5, y, h), tileToScene(x + 1, y + 0.5, h)],
          [tileToScene(x, y + 0.5, h), tileToScene(x + 0.5, y + 1, h)],
        ];
        for (int i = 0; i < 4; i++) {
          final nx = x + ns[i][0], ny = y + ns[i][1];
          final no = game.map.isValid(nx, ny)
              ? game.map.at(nx, ny).ownerNationId
              : null;
          if (no != t.ownerNationId) {
            c.drawLine(edges[i][0], edges[i][1], bp);
          }
        }
      }
    }
  }

  void _isoHighlights(Canvas c) {
    void draw(List<List<int>> points, Color color) {
      for (final h in points) {
        if (!game.map.isValid(h[0], h[1])) continue;
        final t = game.map.at(h[0], h[1]);
        c.drawPath(
          _diamond(h[0], h[1], _heightFor(t) + 3),
          Paint()
            ..color = color.withValues(alpha: 0.35)
            ..style = PaintingStyle.fill,
        );
      }
    }

    draw(game.moveHighlights, kColorSuccess);
    draw(game.attackHighlights, kColorAccent);
  }

  void _isoBuildings(Canvas c) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final b in game.buildings.values) {
      final tile = game.map.at(b.x, b.y);
      final z = _heightFor(tile) + 8;
      final o = _center(b.x, b.y, z);
      final owner = game.nations[b.nationId]?.color ?? kColorGold;
      c.drawOval(
        Rect.fromCenter(center: o.translate(0, 18), width: 54, height: 20),
        Paint()..color = Colors.black.withValues(alpha: 0.24),
      );
      final body = RRect.fromRectAndRadius(
        Rect.fromCenter(center: o.translate(0, 2), width: 42, height: 34),
        const Radius.circular(5),
      );
      c.drawRRect(body, Paint()..color = const Color(0xFFB4A28C));
      c.drawRRect(
        body,
        Paint()
          ..color = owner.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      tp.text = TextSpan(
        text: b.def.emoji,
        style: const TextStyle(fontSize: 25),
      );
      tp.layout();
      tp.paint(c, Offset(o.dx - tp.width / 2, o.dy - tp.height / 2 - 2));
      _health(c, o.translate(-22, 27), 44, b.health / b.maxHealth);
      if (b.isConstructing) {
        c.drawPath(
          _diamond(b.x, b.y, z + 1),
          Paint()..color = kColorGold.withValues(alpha: 0.24),
        );
      }
    }
  }

  void _isoUnits(Canvas c) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final u in game.units.values) {
      final tile = game.map.at(u.x, u.y);
      final o = _center(u.x, u.y, _heightFor(tile) + 12);
      final col = game.nations[u.nationId]?.color ?? Colors.grey;
      c.drawOval(
        Rect.fromCenter(center: o.translate(0, 18), width: 38, height: 14),
        Paint()..color = Colors.black.withValues(alpha: 0.28),
      );
      c.drawCircle(o, 17, Paint()..color = col.withValues(alpha: 0.65));
      c.drawCircle(
        o,
        19,
        Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      tp.text = TextSpan(
        text: u.def.emoji,
        style: const TextStyle(fontSize: 21),
      );
      tp.layout();
      tp.paint(c, Offset(o.dx - tp.width / 2, o.dy - tp.height / 2));
      _health(c, o.translate(-18, 24), 36, u.health / u.maxHealth);
    }
  }

  void _isoAdmiral(Canvas c) {
    final nation = game.playerNation;
    final tx = admiralX.clamp(0, kMapW - 1).floor();
    final ty = admiralY.clamp(0, kMapH - 1).floor();
    final tile = game.map.at(tx, ty);
    final jh = jumpHeight;
    final o = _center(
      admiralX - 0.5,
      admiralY - 0.5,
      _heightFor(tile) + 18 + jh,
    );
    final col = nation?.color ?? kColorGold;
    // Shadow (smaller when jumping)
    c.drawOval(
      Rect.fromCenter(
        center: o.translate(0, 54 - jh * 0.5),
        width: 82 - jh * 0.4,
        height: 26 - jh * 0.2,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.32 - jh * 0.004),
    );
    // Glow ring
    c.drawCircle(
      o.translate(0, 44),
      35,
      Paint()
        ..color = col.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    // Body
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: o.translate(0, 5), width: 38, height: 80),
        const Radius.circular(14),
      ),
      Paint()..color = const Color(0xFF264D38),
    );
    // Head
    c.drawCircle(
      o.translate(0, -44),
      20,
      Paint()..color = const Color(0xFFC98A5A),
    );
    // Hat
    c.drawRect(
      Rect.fromCenter(center: o.translate(0, -64), width: 42, height: 18),
      Paint()..color = col,
    );
    // Emoji
    final tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(
      text: _admiralEmoji(nation?.name ?? ''),
      style: const TextStyle(fontSize: 32),
    );
    tp.layout();
    tp.paint(c, Offset(o.dx - tp.width / 2, o.dy - 67));
    _label(
      c,
      o.translate(0, -92),
      '${nation?.name ?? 'Admiral'} Commander',
      col,
    );
  }

  void _isoSelection(Canvas c) {
    if (game.selX == null || game.selY == null) return;
    final tile = game.map.at(game.selX!, game.selY!);
    c.drawPath(
      _diamond(game.selX!, game.selY!, _heightFor(tile) + 5),
      Paint()
        ..color = kColorGold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  void _health(Canvas c, Offset o, double w, double pct) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(o.dx, o.dy, w, 5),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.58),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(o.dx, o.dy, w * pct.clamp(0, 1), 5),
        const Radius.circular(3),
      ),
      Paint()..color = pct > 0.45 ? kColorSuccess : kColorAccent,
    );
  }

  void _label(Canvas c, Offset o, String text, Color color) {
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    )..layout(maxWidth: 180);
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: o, width: tp.width + 18, height: 26),
      const Radius.circular(5),
    );
    c.drawRRect(
      r,
      Paint()..color = const Color(0xFF07101B).withValues(alpha: 0.76),
    );
    c.drawRRect(
      r,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    tp.paint(c, Offset(o.dx - tp.width / 2, o.dy - tp.height / 2));
  }

  void _treeCluster(Canvas c, int x, int y, double z) {
    final positions = [
      _center(x + .1, y, z + 11),
      _center(x - .1, y + .15, z + 8),
    ];
    for (final o in positions) {
      c.drawRect(
        Rect.fromCenter(center: o.translate(0, 13), width: 5, height: 16),
        Paint()..color = const Color(0xFF5A3925),
      );
      c.drawPath(
        Path()
          ..moveTo(o.dx, o.dy - 18)
          ..lineTo(o.dx + 16, o.dy + 15)
          ..lineTo(o.dx - 16, o.dy + 15)
          ..close(),
        Paint()..color = const Color(0xFF145A2E),
      );
    }
  }

  void _mountain(Canvas c, int x, int y, double z) {
    final o = _center(x, y, z + 12);
    c.drawPath(
      Path()
        ..moveTo(o.dx, o.dy - 34)
        ..lineTo(o.dx + 30, o.dy + 20)
        ..lineTo(o.dx - 30, o.dy + 20)
        ..close(),
      Paint()..color = const Color(0xFF6E6A63),
    );
    c.drawPath(
      Path()
        ..moveTo(o.dx, o.dy - 34)
        ..lineTo(o.dx + 10, o.dy - 5)
        ..lineTo(o.dx - 8, o.dy - 4)
        ..close(),
      Paint()..color = const Color(0xFFE7E2D6),
    );
  }

  void _waterLines(Canvas c, int x, int y, double z) {
    final o = _center(x, y, z);
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.26)
      ..strokeWidth = 1.2;
    c.drawLine(o.translate(-18, 0), o.translate(18, 0), p);
    c.drawLine(o.translate(-10, 8), o.translate(12, 8), p);
  }

  void _multiUnitHighlights(Canvas c) {
    if (game.selectedUnitIds.isEmpty) return;
    for (final id in game.selectedUnitIds) {
      final u = game.units[id];
      if (u == null) continue;
      final tile = game.map.at(u.x, u.y);
      final o = _center(u.x, u.y, _heightFor(tile) + 12);
      c.drawCircle(
        o,
        22,
        Paint()
          ..color = kColorGold.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  void _pathOverlay(Canvas c) {
    if (game.pendingPath.isEmpty) return;
    final selUnit = game.selUnitId != null ? game.units[game.selUnitId!] : null;
    if (selUnit == null) return;
    final p = Paint()
      ..color = kColorSuccess.withValues(alpha: 0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    Offset? prev;
    for (final pt in game.pendingPath) {
      if (!game.map.isValid(pt[0], pt[1])) continue;
      final tile = game.map.at(pt[0], pt[1]);
      final o = _center(pt[0], pt[1], _heightFor(tile) + 8);
      if (prev != null) c.drawLine(prev, o, p);
      c.drawCircle(o, 4, Paint()..color = kColorSuccess.withValues(alpha: 0.8));
      prev = o;
    }
  }

  void _commandArrow(Canvas c) {
    if (dragStart == null || dragCurrent == null) return;
    final angle = (dragCurrent! - dragStart!).direction;
    final len = (dragCurrent! - dragStart!).distance;
    if (len < 10) return;
    final endTile = sceneToTile(dragCurrent!);
    final isEnemy =
        game.map.isValid(endTile.$1, endTile.$2) &&
        game.map.at(endTile.$1, endTile.$2).ownerNationId != null &&
        game.map.at(endTile.$1, endTile.$2).ownerNationId !=
            game.playerNationId;
    final color = isEnemy ? kColorAccent : kColorSuccess;
    final glow = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    final line = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    c.drawLine(dragStart!, dragCurrent!, glow);
    c.drawLine(dragStart!, dragCurrent!, line);
    final hl = 18.0;
    c.drawLine(
      dragCurrent!,
      dragCurrent! -
          Offset.fromDirection(angle, hl) +
          Offset.fromDirection(angle - 0.5, hl * 0.4),
      line,
    );
    c.drawLine(
      dragCurrent!,
      dragCurrent! -
          Offset.fromDirection(angle, hl) -
          Offset.fromDirection(angle - 0.5, hl * 0.4),
      line,
    );
    c.drawCircle(dragStart!, 8, Paint()..color = color.withValues(alpha: 0.5));
    c.drawCircle(dragCurrent!, 6, Paint()..color = color);
  }

  void _selectionBox(Canvas c) {
    if (selBoxStart == null || selBoxEnd == null) return;
    final rect = Rect.fromPoints(selBoxStart!, selBoxEnd!);
    c.drawRect(rect, Paint()..color = kColorSuccess.withValues(alpha: 0.15));
    c.drawRect(
      rect,
      Paint()
        ..color = kColorSuccess.withValues(alpha: 0.7)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  void _combatEffects(Canvas c) {
    final now = DateTime.now();
    game.combatEffects.removeWhere(
      (e) => now.difference(e.spawned).inMilliseconds > 2000,
    );
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final e in game.combatEffects) {
      final age = now.difference(e.spawned).inMilliseconds;
      final progress = age / 2000.0;
      if (!game.map.isValid(e.x, e.y)) continue;
      final tile = game.map.at(e.x, e.y);
      final base = _center(e.x, e.y, _heightFor(tile) + 20 + progress * 45);
      final alpha = (1.0 - progress).clamp(0.0, 1.0);
      final txt = e.isKill
          ? '💀'
          : (e.isCrit ? '💥${e.damage}' : '-${e.damage}');
      tp.text = TextSpan(
        text: txt,
        style: TextStyle(
          color: e.color.withValues(alpha: alpha),
          fontSize: e.isKill ? 22.0 : (e.isCrit ? 18.0 : 14.0),
          fontWeight: FontWeight.bold,
        ),
      );
      tp.layout();
      tp.paint(c, Offset(base.dx - tp.width / 2, base.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 22 ▸ BUILD PANEL (LEFT)
// ══════════════════════════════════════════════════════════════════════════════

class BuildPanel extends StatelessWidget {
  final GameState game;
  final int cat;
  final ValueChanged<int> onCat;
  const BuildPanel({
    super.key,
    required this.game,
    required this.cat,
    required this.onCat,
  });

  static const _cats = ['💰', '⚔️', '🛡️', '🔬', '⭐'];
  static const _labs = ['Eco', 'Mil', 'Def', 'Tech', 'Spec'];
  static const _types = [
    BuildingCat.economic,
    BuildingCat.military,
    BuildingCat.defensive,
    BuildingCat.technology,
    BuildingCat.special,
  ];

  @override
  Widget build(BuildContext context) {
    final n = game.playerNation;
    final defs = kBuildingDefs.values
        .where((d) => d.category == _types[cat])
        .toList();
    return Container(
      width: 256,
      color: kColorPanel,
      child: Column(
        children: [
          Container(
            height: 38,
            color: kColorBg,
            child: Row(
              children: List.generate(
                5,
                (i) => Expanded(
                  child: GestureDetector(
                    onTap: () => onCat(i),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: cat == i ? kColorGold : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        '${_cats[i]}\n${_labs[i]}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cat == i ? kColorGold : kColorMuted,
                          fontSize: 7,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(7),
              itemCount: defs.length,
              itemBuilder: (_, i) {
                final d = defs[i];
                final afford = n?.resources.canAfford(d.cost) == true;
                final ageOk =
                    d.requiredAge.index2 <= (n?.currentAge.index2 ?? 0);
                final sel = game.pendingBuildDefId == d.id;
                return GestureDetector(
                  onTap: () {
                    if (!ageOk) {
                      game.addEvent(
                        '❌ Requires ${d.requiredAge.label}!',
                        color: kColorAccent,
                      );
                      return;
                    }
                    game.pendingBuildDefId = d.id;
                    game.addEvent(
                      '👆 Tap territory to place ${d.name}',
                      color: kColorGold,
                    );
                    game.rebuild();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 5),
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: sel
                          ? kColorGoldDark.withValues(alpha: 0.28)
                          : kColorBg,
                      border: Border.all(
                        color: sel
                            ? kColorGold
                            : !ageOk
                            ? kColorBorder.withValues(alpha: 0.25)
                            : afford
                            ? kColorBorder
                            : kColorAccent.withValues(alpha: 0.25),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(d.emoji, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.name,
                                    style: TextStyle(
                                      color: !ageOk
                                          ? kColorMuted
                                          : afford
                                          ? kColorText
                                          : kColorAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    !ageOk
                                        ? '🔒 ${d.requiredAge.label}'
                                        : '🕐${d.buildTicks}t ❤️${d.health}',
                                    style: const TextStyle(
                                      color: kColorMuted,
                                      fontSize: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (d.cost.isNotEmpty) const SizedBox(height: 3),
                        if (d.cost.isNotEmpty)
                          _CostLine(cost: d.cost, nation: n),
                        if (d.production.isNotEmpty)
                          Text(
                            '+${d.production.entries.map((e) => '${e.value.toInt()}${e.key}').join(' ')}',
                            style: const TextStyle(
                              color: kColorSuccess,
                              fontSize: 8,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (game.pendingBuildDefId != null)
            GestureDetector(
              onTap: () {
                game.pendingBuildDefId = null;
                game.rebuild();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(9),
                color: kColorAccent.withValues(alpha: 0.18),
                child: const Text(
                  '✖ Cancel Placement',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kColorAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CostLine extends StatelessWidget {
  final Map<String, double> cost;
  final Nation? nation;
  const _CostLine({required this.cost, required this.nation});
  static const _e = {
    'gold': '💰',
    'food': '🌾',
    'wood': '🪵',
    'stone': '🪨',
    'iron': '⚙️',
    'oil': '🛢️',
  };
  double _get(String k) {
    if (nation == null) return 0;
    switch (k) {
      case 'gold':
        return nation!.resources.gold;
      case 'food':
        return nation!.resources.food;
      case 'wood':
        return nation!.resources.wood;
      case 'stone':
        return nation!.resources.stone;
      case 'iron':
        return nation!.resources.iron;
      case 'oil':
        return nation!.resources.oil;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 5,
    children: cost.entries.map((e) {
      final ok = _get(e.key) >= e.value;
      return Text(
        '${_e[e.key] ?? '?'}${e.value.toInt()}',
        style: TextStyle(color: ok ? kColorMuted : kColorAccent, fontSize: 8),
      );
    }).toList(),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 23 ▸ BOTTOM SELECTION PANEL
// ══════════════════════════════════════════════════════════════════════════════

class SelectionPanel extends StatelessWidget {
  final GameState game;
  const SelectionPanel({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final unit = game.selUnitId != null ? game.units[game.selUnitId!] : null;
    final building = game.selBuildingId != null
        ? game.buildings[game.selBuildingId!]
        : null;
    final tile = (game.selX != null && game.selY != null)
        ? game.map.at(game.selX!, game.selY!)
        : null;

    return Container(
      height: 94,
      color: kColorPanel,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: unit != null
          ? _UnitPanel(unit: unit, game: game)
          : building != null
          ? _BldgPanel(building: building, game: game)
          : tile != null
          ? _TilePanel(tile: tile, game: game)
          : _DefaultPanel(game: game),
    );
  }
}

class _UnitPanel extends StatelessWidget {
  final GameUnit unit;
  final GameState game;
  const _UnitPanel({required this.unit, required this.game});
  @override
  Widget build(BuildContext context) {
    final d = unit.def;
    final n = game.nations[unit.nationId];
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: (n?.color ?? Colors.grey).withValues(alpha: 0.18),
            border: Border.all(color: n?.color ?? Colors.grey),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(d.emoji, style: const TextStyle(fontSize: 34)),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                d.name,
                style: TextStyle(
                  color: n?.color ?? kColorText,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                n?.name ?? '',
                style: const TextStyle(color: kColorMuted, fontSize: 9),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Text(
                    'HP ',
                    style: TextStyle(color: kColorMuted, fontSize: 9),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: unit.health / unit.maxHealth,
                      backgroundColor: kColorBorder,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        unit.health > unit.maxHealth * 0.5
                            ? kColorSuccess
                            : kColorAccent,
                      ),
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${unit.health}/${unit.maxHealth}',
                    style: const TextStyle(color: kColorText, fontSize: 8),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _S('⚔️', 'ATK', d.attack),
            _S('🛡️', 'DEF', d.defense),
            _S('🏃', 'SPD', d.speed),
            _S('🎯', 'RNG', d.range),
          ],
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              unit.hasMoved ? '✅ Moved' : '🏃 Can Move',
              style: TextStyle(
                color: unit.hasMoved ? kColorMuted : kColorSuccess,
                fontSize: 9,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              unit.hasAttacked ? '✅ Attacked' : '⚔️ Can Atk',
              style: TextStyle(
                color: unit.hasAttacked ? kColorMuted : kColorAccent,
                fontSize: 9,
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: game.clearSelection,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: kColorBorder),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  '✖ Desel',
                  style: TextStyle(color: kColorMuted, fontSize: 8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _S(String ic, String l, int v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(ic, style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 3),
        Text('$l:$v', style: const TextStyle(color: kColorText, fontSize: 9)),
      ],
    ),
  );
}

class _BldgPanel extends StatelessWidget {
  final Building building;
  final GameState game;
  const _BldgPanel({required this.building, required this.game});
  @override
  Widget build(BuildContext context) {
    final d = building.def;
    final n = game.nations[building.nationId];
    final isPlayer = building.nationId == game.playerNationId;
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: (n?.color ?? Colors.grey).withValues(alpha: 0.18),
            border: Border.all(color: n?.color ?? Colors.grey),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(d.emoji, style: const TextStyle(fontSize: 34)),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                d.name,
                style: const TextStyle(
                  color: kColorText,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                n?.name ?? '',
                style: const TextStyle(color: kColorMuted, fontSize: 9),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Text(
                    'HP ',
                    style: TextStyle(color: kColorMuted, fontSize: 9),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: building.health / building.maxHealth,
                      backgroundColor: kColorBorder,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        building.health > building.maxHealth * 0.5
                            ? kColorSuccess
                            : kColorAccent,
                      ),
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${building.health}/${building.maxHealth}',
                    style: const TextStyle(color: kColorText, fontSize: 8),
                  ),
                ],
              ),
              if (building.isConstructing)
                Text(
                  '⏳ Building: ${building.buildTicksLeft}t',
                  style: const TextStyle(color: kColorGold, fontSize: 8),
                ),
              if (building.trainingUnitDefId != null)
                Text(
                  '🎯 Training ${kUnitDefs[building.trainingUnitDefId!]?.name}: ${building.trainingTicksLeft}t',
                  style: const TextStyle(color: kColorGold, fontSize: 8),
                ),
            ],
          ),
        ),
        if (isPlayer && d.unlocks.isNotEmpty && !building.isConstructing) ...[
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'TRAIN',
                style: TextStyle(
                  color: kColorMuted,
                  fontSize: 8,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: d.unlocks.map((uid) {
                  final ud = kUnitDefs[uid];
                  if (ud == null) return const SizedBox.shrink();
                  final ok = n?.resources.canAfford(ud.cost) ?? false;
                  return GestureDetector(
                    onTap: () {
                      if (building.trainingUnitDefId != null) {
                        game.addEvent(
                          '❌ Already training!',
                          color: kColorAccent,
                        );
                        return;
                      }
                      game.trainUnit(game.playerNationId!, building.id, uid);
                    },
                    child: Tooltip(
                      message:
                          '${ud.name}\n${ud.cost.entries.map((e) => '${e.key}:${e.value.toInt()}').join(', ')}',
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: ok ? kColorGoldDark : kColorBorder,
                          ),
                          borderRadius: BorderRadius.circular(3),
                          color: ok
                              ? kColorGoldDark.withValues(alpha: 0.12)
                              : Colors.transparent,
                        ),
                        child: Text(
                          ud.emoji,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TilePanel extends StatelessWidget {
  final MapTile tile;
  final GameState game;
  const _TilePanel({required this.tile, required this.game});
  @override
  Widget build(BuildContext context) {
    final owner = tile.ownerNationId != null
        ? game.nations[tile.ownerNationId!]
        : null;
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: tile.baseColor.withValues(alpha: 0.4),
            border: Border.all(color: kColorBorder),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(tile.emoji, style: const TextStyle(fontSize: 30)),
          ),
        ),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              tile.terrain.name.toUpperCase(),
              style: const TextStyle(
                color: kColorText,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            Text(
              'Pos: (${tile.x},${tile.y})',
              style: const TextStyle(color: kColorMuted, fontSize: 9),
            ),
            if (owner != null)
              Text(
                'Owner: ${owner.name}',
                style: TextStyle(color: owner.color, fontSize: 10),
              ),
            if (owner == null)
              const Text(
                'Unclaimed',
                style: TextStyle(color: kColorMuted, fontSize: 10),
              ),
          ],
        ),
      ],
    );
  }
}

class _DefaultPanel extends StatelessWidget {
  final GameState game;
  const _DefaultPanel({required this.game});
  @override
  Widget build(BuildContext context) {
    final n = game.playerNation;
    return Row(
      children: [
        if (n != null) ...[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: n.color.withValues(alpha: 0.18),
              border: Border.all(color: n.color),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Text('🏛️', style: TextStyle(fontSize: 34)),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  n.name,
                  style: TextStyle(
                    color: n.color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${n.tier.label} · ${n.currentAge.label}',
                  style: const TextStyle(color: kColorMuted, fontSize: 9),
                ),
                Text(
                  '🗺️${n.ownedTiles.length} tiles · 🏗️${n.buildingIds.length} bldgs · ⚔️${n.unitIds.length} units',
                  style: const TextStyle(color: kColorText, fontSize: 9),
                ),
              ],
            ),
          ),
        ],
        const Expanded(
          child: Center(
            child: Text(
              '👆 Tap the map to select',
              style: TextStyle(color: kColorMuted, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 24 ▸ RIGHT NATION PANEL
// ══════════════════════════════════════════════════════════════════════════════

class NationPanel extends StatelessWidget {
  final GameState game;
  const NationPanel({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final alive = game.aliveNations;
    final sorted = List<Nation>.from(alive)
      ..sort(
        (a, b) => (b.economyScore + b.militaryScore + b.influenceScore)
            .compareTo(a.economyScore + a.militaryScore + a.influenceScore),
      );
    return Container(
      width: 210,
      decoration: BoxDecoration(
        color: const Color(0xEE080F1C),
        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(10)),
        border: Border(
          right: BorderSide(
            color: kColorGold.withValues(alpha: 0.20),
            width: 1,
          ),
          bottom: BorderSide(
            color: kColorGold.withValues(alpha: 0.20),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 18,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: kColorGold.withValues(alpha: 0.22),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'NATIONS',
                  style: TextStyle(
                    color: kColorGold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Text(
                  '▾',
                  style: TextStyle(
                    color: kColorGold.withValues(alpha: 0.60),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Nation cards
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: sorted.length,
              itemBuilder: (_, i) {
                final n = sorted[i];
                final isP = n.id == game.playerNationId;
                return Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isP
                        ? n.color.withValues(alpha: 0.10)
                        : Colors.white.withValues(alpha: 0.025),
                    border: Border.all(
                      color: isP
                          ? n.color.withValues(alpha: 0.50)
                          : kColorBorder.withValues(alpha: 0.50),
                      width: isP ? 1.2 : 0.8,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: dot + name + badge
                      Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: n.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              n.name,
                              style: TextStyle(
                                color: isP ? n.color : kColorText,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isP)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: n.color.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'YOU',
                                style: TextStyle(
                                  color: n.color,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else if (n.isAI)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: kColorMuted.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'AI',
                                style: TextStyle(
                                  color: kColorMuted,
                                  fontSize: 8,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Row 2: compact stats
                      Row(
                        children: [
                          _NationStat(
                            '♥',
                            n.militaryScore,
                            const Color(0xFFE57373),
                          ),
                          const SizedBox(width: 12),
                          _NationStat('💰', n.economyScore, kColorGold),
                          const SizedBox(width: 12),
                          _NationStat(
                            '♥',
                            n.resources.population,
                            const Color(0xFF81C784),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NationStat extends StatelessWidget {
  final String icon;
  final int val;
  final Color color;
  const _NationStat(this.icon, this.val, this.color);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        icon,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(width: 3),
      Text(_NS._f(val), style: const TextStyle(color: kColorText, fontSize: 9)),
    ],
  );
}

class _NS extends StatelessWidget {
  final String icon;
  final int val;
  const _NS(this.icon, this.val);
  static String _f(int v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return '$v';
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(icon, style: const TextStyle(fontSize: 9)),
      Text(_f(val), style: const TextStyle(color: kColorText, fontSize: 8)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 25 ▸ TECH DIALOG
// ══════════════════════════════════════════════════════════════════════════════

class TechDialog extends StatefulWidget {
  final GameState game;
  const TechDialog({super.key, required this.game});
  @override
  State<TechDialog> createState() => _TechDialogState();
}

class _TechDialogState extends State<TechDialog> {
  Age _age = Age.ancient;
  @override
  Widget build(BuildContext context) {
    final n = widget.game.playerNation;
    final techs = kTechDefs.values.where((t) => t.era == _age).toList();
    return Dialog(
      backgroundColor: kColorBg,
      child: SizedBox(
        width: 660,
        height: 480,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              color: kColorPanel,
              child: Row(
                children: [
                  const Text(
                    '🔬 TECH TREE',
                    style: TextStyle(
                      color: kColorGold,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(width: 14),
                  if (n?.activeResearchId != null)
                    Text(
                      'Researching: ${kTechDefs[n!.activeResearchId!]?.name ?? '?'}',
                      style: const TextStyle(color: kColorGold, fontSize: 10),
                    ),
                  const Spacer(),
                  Text(
                    '🔬 ${n?.resources.researchPoints ?? 0} RP',
                    style: const TextStyle(color: kColorText, fontSize: 11),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      '✖',
                      style: TextStyle(color: kColorMuted, fontSize: 17),
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: Age.values.map((age) {
                  final ok = age.index2 <= (n?.currentAge.index2 ?? 0);
                  return GestureDetector(
                    onTap: () => setState(() => _age = age),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _age == age
                                ? kColorGold
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        color: _age == age ? kColorPanel : Colors.transparent,
                      ),
                      child: Text(
                        age.label.replaceAll(' Age', ''),
                        style: TextStyle(
                          color: !ok
                              ? kColorMuted
                              : _age == age
                              ? kColorGold
                              : kColorText,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(14),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 7,
                  crossAxisSpacing: 7,
                  childAspectRatio: 1.85,
                ),
                itemCount: techs.length,
                itemBuilder: (_, i) {
                  final t = techs[i];
                  final done = n?.hasCompletedTech(t.id) == true;
                  final busy = n?.activeResearchId == t.id;
                  final prog = n?.research[t.id]?.progress ?? 0.0;
                  final prereq = t.prerequisites.every(
                    (p) => n?.hasCompletedTech(p) == true,
                  );
                  final ageOk = t.era.index2 <= (n?.currentAge.index2 ?? 0);
                  final can = ageOk && prereq && !done && !busy;
                  return GestureDetector(
                    onTap: can
                        ? () {
                            widget.game.startResearch(
                              widget.game.playerNationId!,
                              t.id,
                            );
                            setState(() {});
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: done
                            ? kColorSuccess.withValues(alpha: 0.08)
                            : busy
                            ? kColorGoldDark.withValues(alpha: 0.18)
                            : kColorPanel,
                        border: Border.all(
                          color: done
                              ? kColorSuccess.withValues(alpha: 0.45)
                              : busy
                              ? kColorGold
                              : !ageOk || !prereq
                              ? kColorBorder.withValues(alpha: 0.3)
                              : kColorBorder,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                t.emoji,
                                style: const TextStyle(fontSize: 15),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  t.name,
                                  style: TextStyle(
                                    color: done ? kColorSuccess : kColorText,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (done)
                                const Text(
                                  '✓',
                                  style: TextStyle(
                                    color: kColorSuccess,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                          Expanded(
                            child: Text(
                              t.description,
                              style: const TextStyle(
                                color: kColorMuted,
                                fontSize: 7,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '${t.cost} RP',
                                style: TextStyle(
                                  color: !ageOk ? kColorBorder : kColorGold,
                                  fontSize: 8,
                                ),
                              ),
                              const Spacer(),
                              if (busy)
                                Text(
                                  '${(prog * 100).toInt()}%',
                                  style: const TextStyle(
                                    color: kColorGold,
                                    fontSize: 8,
                                  ),
                                ),
                            ],
                          ),
                          if (busy)
                            LinearProgressIndicator(
                              value: prog,
                              backgroundColor: kColorBorder,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                kColorGold,
                              ),
                              minHeight: 3,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 26 ▸ DIPLOMACY DIALOG
// ══════════════════════════════════════════════════════════════════════════════

class DiplomacyDialog extends StatelessWidget {
  final GameState game;
  const DiplomacyDialog({super.key, required this.game});
  @override
  Widget build(BuildContext context) {
    final pn = game.playerNation;
    final others = game.aliveNations
        .where((n) => n.id != game.playerNationId)
        .toList();
    return Dialog(
      backgroundColor: kColorBg,
      child: SizedBox(
        width: 540,
        height: 400,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              color: kColorPanel,
              child: Row(
                children: [
                  const Text(
                    '🤝 DIPLOMACY',
                    style: TextStyle(
                      color: kColorGold,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      '✖',
                      style: TextStyle(color: kColorMuted, fontSize: 17),
                    ),
                  ),
                ],
              ),
            ),
            if (pn != null)
              Expanded(
                child: others.isEmpty
                    ? const Center(
                        child: Text(
                          'No other nations.',
                          style: TextStyle(color: kColorMuted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: others.length,
                        itemBuilder: (_, i) {
                          final o = others[i];
                          final rel = pn.diplomacy[o.id];
                          final ally = rel?.isAllied == true;
                          final war = rel?.atWar == true;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: war
                                    ? kColorAccent.withValues(alpha: 0.4)
                                    : ally
                                    ? kColorSuccess.withValues(alpha: 0.4)
                                    : kColorBorder,
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: o.color.withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: o.color),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '🏛️',
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        o.name,
                                        style: TextStyle(
                                          color: o.color,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        o.tier.label,
                                        style: const TextStyle(
                                          color: kColorMuted,
                                          fontSize: 8,
                                        ),
                                      ),
                                      Text(
                                        war
                                            ? '⚔️ At War'
                                            : ally
                                            ? '🤝 Allied'
                                            : '😐 Neutral',
                                        style: TextStyle(
                                          color: war
                                              ? kColorAccent
                                              : ally
                                              ? kColorSuccess
                                              : kColorMuted,
                                          fontSize: 8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (!ally && !war)
                                      _DB('🤝 Ally', kColorSuccess, () {
                                        game.performDiplomacy(
                                          game.playerNationId!,
                                          o.id,
                                          DiplomacyAction.ally,
                                        );
                                        Navigator.pop(context);
                                      }),
                                    if (!ally && !war) const SizedBox(width: 5),
                                    if (!war)
                                      _DB('⚔️ War', kColorAccent, () {
                                        game.performDiplomacy(
                                          game.playerNationId!,
                                          o.id,
                                          DiplomacyAction.declareWar,
                                        );
                                        Navigator.pop(context);
                                      }),
                                    if (war)
                                      _DB('🕊️ Peace', kColorText, () {
                                        game.performDiplomacy(
                                          game.playerNationId!,
                                          o.id,
                                          DiplomacyAction.makePeace,
                                        );
                                        Navigator.pop(context);
                                      }),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DB extends StatelessWidget {
  final String l;
  final Color c;
  final VoidCallback t;
  const _DB(this.l, this.c, this.t);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: t,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(3),
        color: c.withValues(alpha: 0.1),
      ),
      child: Text(
        l,
        style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 27 ▸ VICTORY DIALOG
// ══════════════════════════════════════════════════════════════════════════════

class VictoryDialog extends StatefulWidget {
  final GameState game;
  final VoidCallback onExit;
  const VictoryDialog({super.key, required this.game, required this.onExit});
  @override
  State<VictoryDialog> createState() => _VictoryState();
}

class _VictoryState extends State<VictoryDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _sc;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _sc = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.elasticOut));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final winner = widget.game.winnerNationId != null
        ? widget.game.nations[widget.game.winnerNationId!]
        : null;
    final isP = winner?.id == widget.game.playerNationId;
    const vl = {
      VictoryType.military: ('⚔️', 'Military Conquest'),
      VictoryType.economic: ('💰', 'Economic Dominance'),
      VictoryType.territorial: ('🗺️', 'Territorial Control'),
      VictoryType.technological: ('🔬', 'Technological Ascension'),
      VictoryType.diplomatic: ('🤝', 'Diplomatic Victory'),
    };
    final vt = vl[widget.game.victoryType] ?? ('🏆', 'Victory');
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _sc,
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: kColorBg,
            border: Border.all(
              color: isP ? kColorGold : kColorAccent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: (isP ? kColorGold : kColorAccent).withValues(
                  alpha: 0.28,
                ),
                blurRadius: 36,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isP ? '🏆' : '💀', style: const TextStyle(fontSize: 60)),
              const SizedBox(height: 10),
              Text(
                isP ? 'VICTORY!' : 'DEFEATED',
                style: TextStyle(
                  color: isP ? kColorGold : kColorAccent,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${vt.$1} ${vt.$2}',
                style: const TextStyle(
                  color: kColorText,
                  fontSize: 13,
                  letterSpacing: 2,
                ),
              ),
              if (winner != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: winner.color.withValues(alpha: 0.45),
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: winner.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        winner.name,
                        style: TextStyle(
                          color: winner.color,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: kColorPanel,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _VS('⏱️', 'Turns', '${widget.game.tick}'),
                    _VS(
                      '🗺️',
                      'Territory',
                      '${winner?.ownedTiles.length ?? 0}',
                    ),
                    _VS(
                      '🏗️',
                      'Buildings',
                      '${winner?.buildingIds.length ?? 0}',
                    ),
                    _VS('💰', 'Economy', '${winner?.economyScore ?? 0}'),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: widget.onExit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isP
                      ? kColorGoldDark
                      : kColorAccent.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 13,
                  ),
                ),
                child: const Text(
                  'RETURN TO MENU',
                  style: TextStyle(letterSpacing: 2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VS extends StatelessWidget {
  final String icon, label, val;
  const _VS(this.icon, this.label, this.val);
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(icon, style: const TextStyle(fontSize: 17)),
      Text(
        val,
        style: const TextStyle(
          color: kColorGold,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(label, style: const TextStyle(color: kColorMuted, fontSize: 8)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 28 ▸ ADMIN PANEL (hidden — long-press the ⚙️ Settings icon)
// ══════════════════════════════════════════════════════════════════════════════

class AdminLoginDialog extends StatefulWidget {
  final GameState game;
  const AdminLoginDialog({super.key, required this.game});
  @override
  State<AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<AdminLoginDialog> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _attempt() {
    if (_userCtrl.text.trim() == kAdminUsername &&
        _passCtrl.text == kAdminPassword) {
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (_) => AdminPanelDialog(game: widget.game),
      );
    } else {
      setState(() => _error = 'Access denied — invalid credentials');
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: kColorBg,
    child: SizedBox(
      width: 320,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CutCornerFrame(
                  cut: 6,
                  borderColor: kColorGold,
                  fill: kColorGoldDark.withValues(alpha: 0.25),
                  child: const SizedBox(
                    width: 30,
                    height: 30,
                    child: Center(
                      child: Text('🔐', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'RESTRICTED ACCESS',
                    style: TextStyle(
                      color: kColorGold,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    '✖',
                    style: TextStyle(color: kColorMuted, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _field('Username', _userCtrl, obscure: false),
            const SizedBox(height: 10),
            _field('Password', _passCtrl, obscure: true),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  color: kColorAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _attempt,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: kColorGold.withValues(alpha: 0.18),
                    border: Border.all(color: kColorGold),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'AUTHENTICATE',
                    style: TextStyle(
                      color: kColorGold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _field(
    String label,
    TextEditingController c, {
    required bool obscure,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: kColorMuted,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 4),
      Container(
        decoration: BoxDecoration(
          color: kColorPanel,
          border: Border.all(color: kColorBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: TextField(
          controller: c,
          obscureText: obscure,
          style: const TextStyle(color: kColorText, fontSize: 12),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: InputBorder.none,
          ),
        ),
      ),
    ],
  );
}

class AdminPanelDialog extends StatefulWidget {
  final GameState game;
  const AdminPanelDialog({super.key, required this.game});
  @override
  State<AdminPanelDialog> createState() => _AdminPanelDialogState();
}

class _AdminPanelDialogState extends State<AdminPanelDialog> {
  String _query = '';
  Nation? _target;
  final _goldCtrl = TextEditingController();
  final _foodCtrl = TextEditingController();
  final _woodCtrl = TextEditingController();
  final _stoneCtrl = TextEditingController();
  final _ironCtrl = TextEditingController();
  final _oilCtrl = TextEditingController();
  final _rpCtrl = TextEditingController();
  String? _flash;

  @override
  void dispose() {
    for (final c in [
      _goldCtrl,
      _foodCtrl,
      _woodCtrl,
      _stoneCtrl,
      _ironCtrl,
      _oilCtrl,
      _rpCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _grant() {
    final t = _target;
    if (t == null) return;
    double parse(TextEditingController c) =>
        double.tryParse(c.text.trim()) ?? 0;
    t.resources.gold += parse(_goldCtrl);
    t.resources.food += parse(_foodCtrl);
    t.resources.wood += parse(_woodCtrl);
    t.resources.stone += parse(_stoneCtrl);
    t.resources.iron += parse(_ironCtrl);
    t.resources.oil += parse(_oilCtrl);
    t.resources.researchPoints += parse(_rpCtrl).toInt();
    widget.game.addEvent(
      '🛡️ Admin granted resources to ${t.name}',
      color: kColorGold,
    );
    widget.game.rebuild();
    setState(() => _flash = 'Granted to ${t.name}');
  }

  void _setWeather(WeatherType w) {
    widget.game.currentWeather = w;
    widget.game.addEvent(
      '🌦️ Admin set weather to ${w.label}',
      color: kColorGold,
    );
    widget.game.rebuild();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final results = widget.game.nations.values
        .where(
          (n) =>
              _query.isEmpty ||
              n.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return Dialog(
      backgroundColor: kColorBg,
      child: SizedBox(
        width: 480,
        height: 580,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              color: kColorPanel,
              child: Row(
                children: [
                  _CutCornerFrame(
                    cut: 6,
                    borderColor: kColorGold,
                    fill: kColorGold.withValues(alpha: 0.18),
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Center(
                        child: Text('🗡️', style: TextStyle(fontSize: 17)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ZORO',
                        style: TextStyle(
                          color: kColorGold,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'Administrator · Hajinwoo',
                        style: TextStyle(color: kColorMuted, fontSize: 9),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      '✖',
                      style: TextStyle(color: kColorMuted, fontSize: 17),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SEARCH PLAYER / NATION',
                      style: TextStyle(
                        color: kColorMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: kColorPanel,
                        border: Border.all(color: kColorBorder),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        style: const TextStyle(color: kColorText, fontSize: 12),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Type a nation / player name…',
                          hintStyle: TextStyle(
                            color: kColorMuted,
                            fontSize: 11,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 130),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (_, i) {
                          final n = results[i];
                          final sel = _target?.id == n.id;
                          return GestureDetector(
                            onTap: () => setState(() => _target = n),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: sel
                                    ? kColorGold.withValues(alpha: 0.1)
                                    : kColorPanel,
                                border: Border.all(
                                  color: sel ? kColorGold : kColorBorder,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: n.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      n.name,
                                      style: TextStyle(
                                        color: n.color,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${n.tier.label} · ${n.currentAge.label}',
                                    style: const TextStyle(
                                      color: kColorMuted,
                                      fontSize: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_target != null) ...[
                      Text(
                        'GRANT RESOURCES — ${_target!.name}',
                        style: const TextStyle(
                          color: kColorMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _resInput('💰 Gold', _goldCtrl),
                          _resInput('🌾 Food', _foodCtrl),
                          _resInput('🪵 Wood', _woodCtrl),
                          _resInput('🪨 Stone', _stoneCtrl),
                          _resInput('⚙️ Iron', _ironCtrl),
                          _resInput('🛢️ Oil', _oilCtrl),
                          _resInput('🔬 Research', _rpCtrl),
                        ],
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _grant,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: kColorGold.withValues(alpha: 0.18),
                            border: Border.all(color: kColorGold),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'GRANT',
                            style: TextStyle(
                              color: kColorGold,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                      if (_flash != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _flash!,
                            style: const TextStyle(
                              color: kColorSuccess,
                              fontSize: 9,
                            ),
                          ),
                        ),
                    ] else
                      const Text(
                        'Select a nation above to grant resources.',
                        style: TextStyle(color: kColorMuted, fontSize: 10),
                      ),
                    const SizedBox(height: 20),
                    const Text(
                      'WEATHER CONTROL',
                      style: TextStyle(
                        color: kColorMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: WeatherType.values.map((w) {
                        final active = widget.game.currentWeather == w;
                        return GestureDetector(
                          onTap: () => _setWeather(w),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? kColorGold.withValues(alpha: 0.16)
                                  : kColorPanel,
                              border: Border.all(
                                color: active ? kColorGold : kColorBorder,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  w.icon,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  w.label,
                                  style: TextStyle(
                                    color: active ? kColorGold : kColorMuted,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kColorPanel,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: kColorBorder),
                      ),
                      child: const Text(
                        'Item / loot granting isn\'t wired up yet — this client has no inventory model to hook into. Resources and weather above are fully live.',
                        style: TextStyle(
                          color: kColorMuted,
                          fontSize: 9,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resInput(String label, TextEditingController c) => SizedBox(
    width: 130,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: kColorMuted, fontSize: 9)),
        const SizedBox(height: 3),
        Container(
          decoration: BoxDecoration(
            color: kColorPanel,
            border: Border.all(color: kColorBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: kColorText, fontSize: 11),
            decoration: const InputDecoration(
              isDense: true,
              hintText: '0',
              hintStyle: TextStyle(color: kColorMuted, fontSize: 11),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    ),
  );
}
