import os
import random
from datetime import datetime
from flask import Flask, request, jsonify, session, redirect, url_for, render_template_string
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash

# -------------------------------------------------------------------------
# HTML TEMPLATE STRINGS (INLINED)
# -------------------------------------------------------------------------

LOGIN_HTML = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Global Dominion: Rise of Nations - Login</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            background: radial-gradient(circle, #0F1E36 0%, #050B14 100%);
            color: #E2E8F0;
            font-family: 'Cinzel', 'Georgia', serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            overflow: hidden;
        }
        .container {
            background: linear-gradient(135deg, #0d1a30, #050b14);
            border: 2px solid #8c6239;
            box-shadow: 0 0 25px rgba(212, 175, 55, 0.2);
            padding: 40px;
            border-radius: 8px;
            width: 100%;
            max-width: 420px;
            text-align: center;
        }
        h2 {
            color: #D4AF37;
            font-size: 1.8rem;
            letter-spacing: 2px;
            margin-bottom: 25px;
            text-transform: uppercase;
            text-shadow: 0 0 8px rgba(212, 175, 55, 0.4);
        }
        .error {
            color: #C24A1D;
            font-size: 0.9rem;
            margin-bottom: 15px;
            font-weight: bold;
        }
        .input-group {
            margin-bottom: 20px;
            text-align: left;
        }
        label {
            display: block;
            font-size: 0.8rem;
            color: #8C6239;
            margin-bottom: 5px;
            text-transform: uppercase;
        }
        input[type="text"], input[type="password"] {
            width: 100%;
            padding: 12px;
            background-color: #0A1220;
            border: 1px solid #8C6239;
            color: #FFF;
            border-radius: 4px;
            box-sizing: border-box;
            font-size: 0.95rem;
        }
        input[type="text"]:focus, input[type="password"]:focus {
            border-color: #D4AF37;
            outline: none;
            box-shadow: 0 0 8px rgba(212, 175, 55, 0.3);
        }
        .btn {
            background: linear-gradient(180deg, #D4AF37 0%, #8C6239 100%);
            color: #0A1220;
            border: none;
            width: 100%;
            padding: 14px;
            font-weight: bold;
            font-size: 1rem;
            cursor: pointer;
            border-radius: 4px;
            text-transform: uppercase;
            transition: all 0.2s ease-in-out;
        }
        .btn:hover {
            box-shadow: 0 0 15px rgba(212, 175, 55, 0.6);
            transform: translateY(-1px);
        }
        .footer-link {
            margin-top: 20px;
            font-size: 0.85rem;
        }
        .footer-link a {
            color: #D4AF37;
            text-decoration: none;
        }
        .footer-link a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <h2>Global Dominion</h2>
        <p style="color:#8C6239; font-size:0.8rem; margin-top:-20px; margin-bottom:30px; letter-spacing:1px;">RISE OF NATIONS</p>
        
        {% if error %}
            <div class="error">{{ error }}</div>
        {% endif %}

        <form action="/login" method="POST">
            <div class="input-group">
                <label>Username / Email</label>
                <input type="text" name="identifier" required>
            </div>
            <div class="input-group">
                <label>Password</label>
                <input type="password" name="password" required>
            </div>
            <button type="submit" class="btn">Login</button>
        </form>
        <div class="footer-link">
            Need an account? <a href="/register">Register Here</a>
        </div>
    </div>
</body>
</html>
"""

REGISTER_HTML = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Global Dominion - Establish Command</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            background: radial-gradient(circle, #0F1E36 0%, #050B14 100%);
            color: #E2E8F0;
            font-family: 'Cinzel', 'Georgia', serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            overflow: hidden;
        }
        .container {
            background: linear-gradient(135deg, #0d1a30, #050b14);
            border: 2px solid #8c6239;
            box-shadow: 0 0 25px rgba(212, 175, 55, 0.2);
            padding: 35px;
            border-radius: 8px;
            width: 100%;
            max-width: 440px;
            text-align: center;
        }
        h2 {
            color: #D4AF37;
            font-size: 1.6rem;
            letter-spacing: 2px;
            margin-bottom: 5px;
            text-transform: uppercase;
        }
        .subtitle {
            color: #8C6239;
            font-size: 0.8rem;
            margin-bottom: 25px;
            letter-spacing: 1px;
        }
        .error {
            color: #C24A1D;
            font-size: 0.9rem;
            margin-bottom: 15px;
            font-weight: bold;
        }
        .input-group {
            margin-bottom: 15px;
            text-align: left;
        }
        label {
            display: block;
            font-size: 0.75rem;
            color: #8C6239;
            margin-bottom: 4px;
            text-transform: uppercase;
        }
        input[type="text"], input[type="email"], input[type="password"] {
            width: 100%;
            padding: 10px;
            background-color: #0A1220;
            border: 1px solid #8C6239;
            color: #FFF;
            border-radius: 4px;
            box-sizing: border-box;
            font-size: 0.9rem;
        }
        input:focus {
            border-color: #D4AF37;
            outline: none;
            box-shadow: 0 0 8px rgba(212, 175, 55, 0.3);
        }
        .btn {
            background: linear-gradient(180deg, #D4AF37 0%, #8C6239 100%);
            color: #0A1220;
            border: none;
            width: 100%;
            padding: 12px;
            font-weight: bold;
            font-size: 0.95rem;
            cursor: pointer;
            border-radius: 4px;
            text-transform: uppercase;
            transition: all 0.2s ease;
        }
        .btn:hover {
            box-shadow: 0 0 15px rgba(212, 175, 55, 0.5);
        }
        .footer-link {
            margin-top: 20px;
            font-size: 0.85rem;
        }
        .footer-link a {
            color: #D4AF37;
            text-decoration: none;
        }
        .footer-link a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <h2>Global Dominion</h2>
        <div class="subtitle">ESTABLISH YOUR COALITION SECURELY</div>
        
        {% if error %}
            <div class="error">{{ error }}</div>
        {% endif %}

        <form action="/register" method="POST">
            <div class="input-group">
                <label>Username</label>
                <input type="text" name="username" required>
            </div>
            <div class="input-group">
                <label>Email Address</label>
                <input type="email" name="email" required>
            </div>
            <div class="input-group">
                <label>Password</label>
                <input type="password" name="password" required>
            </div>
            <div class="input-group">
                <label>Confirm Password</label>
                <input type="password" name="confirm_password" required>
            </div>
            <button type="submit" class="btn">Register & Enlist</button>
        </form>
        <div class="footer-link">
            Already registered? <a href="/login">Return to Command Center</a>
        </div>
    </div>
</body>
</html>
"""

COUNTRY_SELECTION_HTML = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Global Dominion - Choose Faction</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            background: radial-gradient(circle, #0F1E36 0%, #050B14 100%);
            color: #E2E8F0;
            font-family: 'Cinzel', 'Georgia', serif;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            padding: 20px;
            box-sizing: border-box;
        }
        h2 {
            color: #D4AF37;
            font-size: 2rem;
            margin-bottom: 5px;
            text-transform: uppercase;
            letter-spacing: 2px;
            text-align: center;
        }
        .subtitle {
            color: #8C6239;
            margin-bottom: 40px;
            font-size: 0.95rem;
            text-align: center;
            max-width: 600px;
            line-height: 1.4;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
            gap: 20px;
            width: 100%;
            max-width: 1100px;
        }
        .card {
            background: linear-gradient(135deg, #0d1a30 0%, #050b14 100%);
            border: 1px solid #8C6239;
            border-radius: 6px;
            padding: 25px;
            text-align: center;
            cursor: pointer;
            transition: all 0.25s ease;
            position: relative;
            overflow: hidden;
        }
        .card:hover {
            border-color: #D4AF37;
            transform: translateY(-5px);
            box-shadow: 0 10px 20px rgba(212, 175, 55, 0.15);
        }
        .card h3 {
            color: #D4AF37;
            margin: 0 0 15px 0;
            font-size: 1.4rem;
            letter-spacing: 1px;
        }
        .bonus-badge {
            background-color: #0A1220;
            border: 1px solid #8C6239;
            color: #D4AF37;
            display: inline-block;
            padding: 4px 10px;
            font-size: 0.75rem;
            border-radius: 12px;
            margin-bottom: 15px;
        }
        .unit-list {
            text-align: left;
            margin-top: 15px;
            font-size: 0.85rem;
            color: #94A3B8;
        }
        .unit-list li {
            margin-bottom: 6px;
        }
        .btn-select {
            background: linear-gradient(180deg, #D4AF37 0%, #8C6239 100%);
            color: #0A1220;
            border: none;
            padding: 10px 20px;
            font-weight: bold;
            font-size: 0.85rem;
            cursor: pointer;
            border-radius: 4px;
            margin-top: 20px;
            text-transform: uppercase;
            width: 100%;
            transition: opacity 0.2s;
        }
        .btn-select:hover {
            opacity: 0.9;
        }
    </style>
</head>
<body>
    <h2>Select Your Nation</h2>
    <div class="subtitle">
        Your choice is permanent. You will ally with citizens of this nation, unlocking tailored tactical units and distinct bonuses designed for global dominion.
    </div>

    <div class="grid">
        {% for c_name, data in countries.items() %}
            <div class="card">
                <h3>{{ c_name }}</h3>
                <span class="bonus-badge">{{ data.bonus }}</span>
                <div class="unit-list">
                    <strong style="color: #E2E8F0; font-size: 0.8rem; text-transform: uppercase;">Exclusive Deployable Forces:</strong>
                    <ul style="list-style-type: square; padding-left: 15px; margin: 8px 0 0 0;">
                        {% for unit in data.units %}
                            <li>{{ unit }}</li>
                        {% endfor %}
                    </ul>
                </div>
                <form action="/country_selection" method="POST">
                    <input type="hidden" name="country" value="{{ c_name }}">
                    <button type="submit" class="btn-select">Establish Rule</button>
                </form>
            </div>
        {% endfor %}
    </div>
</body>
</html>
"""

INDEX_HTML = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Global Dominion: Rise of Nations</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Cinzel:wght@400;700&family=Inter:wght@300;400;600&display=swap');

        * {
            box-sizing: border-box;
            user-select: none;
        }
        body {
            margin: 0;
            padding: 0;
            background-color: #050B14;
            color: #E2E8F0;
            font-family: 'Inter', sans-serif;
            overflow-x: hidden;
        }
        h1, h2, h3, h4, .imperial-font {
            font-family: 'Cinzel', serif;
            letter-spacing: 1px;
            color: #D4AF37;
            margin: 0;
        }

        /* TOP STATUS NAVIGATION BAR */
        .top-navbar {
            background: linear-gradient(180deg, #0d1a30 0%, #050b14 100%);
            border-bottom: 2px solid #8C6239;
            height: 70px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 0 20px;
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            z-index: 100;
        }
        .nav-logo {
            font-size: 1.25rem;
            font-weight: 700;
            text-transform: uppercase;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .resources-container {
            display: flex;
            gap: 20px;
            align-items: center;
        }
        .resource-node {
            display: flex;
            align-items: center;
            gap: 8px;
            background-color: #0A1220;
            border: 1px solid #8C6239;
            padding: 6px 12px;
            border-radius: 4px;
            font-size: 0.85rem;
        }
        .resource-node span {
            font-weight: bold;
            color: #FFF;
        }
        .resource-label {
            color: #D4AF37;
            font-size: 0.75rem;
            text-transform: uppercase;
        }
        .logout-link {
            color: #C24A1D;
            text-decoration: none;
            font-size: 0.85rem;
            text-transform: uppercase;
            font-weight: bold;
            border: 1px solid #C24A1D;
            padding: 6px 12px;
            border-radius: 4px;
            transition: all 0.2s;
        }
        .logout-link:hover {
            background-color: #C24A1D;
            color: #FFF;
        }

        /* MAIN CONTENT LAYOUT */
        .app-wrapper {
            margin-top: 70px;
            display: flex;
            min-height: calc(100vh - 70px);
        }
        .sidebar {
            width: 260px;
            background-color: #070D18;
            border-right: 1px solid #8C6239;
            padding: 20px;
            display: flex;
            flex-direction: column;
            gap: 10px;
        }
        .sidebar-btn {
            background: none;
            border: 1px solid transparent;
            color: #94A3B8;
            padding: 12px 15px;
            text-align: left;
            width: 100%;
            cursor: pointer;
            font-size: 0.9rem;
            border-radius: 4px;
            transition: all 0.2s;
            text-transform: uppercase;
            font-family: 'Cinzel', serif;
        }
        .sidebar-btn:hover, .sidebar-btn.active {
            border-color: #D4AF37;
            color: #D4AF37;
            background-color: #0d1a30;
        }
        .main-stage {
            flex-grow: 1;
            padding: 30px;
            background: radial-gradient(circle, #0F1E36 0%, #050B14 100%);
            overflow-y: auto;
        }

        /* MAP VISUAL SYSTEM */
        .map-wrapper {
            background: rgba(10, 18, 32, 0.85);
            border: 2px solid #8C6239;
            border-radius: 8px;
            padding: 20px;
            position: relative;
            box-shadow: inset 0 0 20px rgba(0, 0, 0, 0.8);
        }
        .world-svg {
            width: 100%;
            height: auto;
            max-height: 520px;
            background-color: #04080e;
            border-radius: 4px;
            border: 1px solid #1e293b;
        }
        .map-node {
            cursor: pointer;
            transition: filter 0.2s;
        }
        .map-node:hover {
            filter: drop-shadow(0px 0px 8px #D4AF37);
        }

        /* GLASSMETALLIC PANELS */
        .g-card {
            background: linear-gradient(135deg, #0d1a30 0%, #050b14 100%);
            border: 1px solid #8C6239;
            border-radius: 6px;
            padding: 20px;
            margin-bottom: 25px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.5);
        }
        .g-header {
            border-bottom: 1px solid #8C6239;
            padding-bottom: 10px;
            margin-bottom: 15px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        /* GRID CONFIGURATIONS */
        .unit-grid, .tech-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 20px;
        }
        .unit-card, .tech-card {
            background: rgba(10, 18, 32, 0.6);
            border: 1px solid #1e293b;
            border-radius: 4px;
            padding: 15px;
            transition: all 0.2s;
        }
        .unit-card:hover, .tech-card:hover {
            border-color: #D4AF37;
        }

        /* BUTTONS */
        .g-btn {
            background: linear-gradient(180deg, #D4AF37 0%, #8C6239 100%);
            color: #0A1220;
            border: none;
            padding: 8px 16px;
            font-weight: bold;
            font-size: 0.8rem;
            cursor: pointer;
            border-radius: 4px;
            text-transform: uppercase;
            transition: opacity 0.2s;
        }
        .g-btn:hover {
            opacity: 0.9;
        }
        .g-btn-sec {
            background: none;
            border: 1px solid #8C6239;
            color: #D4AF37;
            padding: 8px 16px;
            font-size: 0.8rem;
            cursor: pointer;
            border-radius: 4px;
            text-transform: uppercase;
            transition: all 0.2s;
        }
        .g-btn-sec:hover {
            background-color: rgba(212, 175, 55, 0.1);
        }

        /* TACTICAL ACTION MODAL */
        .modal-overlay {
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            background: rgba(0,0,0,0.85);
            z-index: 110;
            display: flex;
            align-items: center;
            justify-content: center;
            opacity: 0;
            pointer-events: none;
            transition: opacity 0.3s ease;
        }
        .modal-overlay.active {
            opacity: 1;
            pointer-events: auto;
        }
        .modal-box {
            background: linear-gradient(135deg, #0d1a30 0%, #050b14 100%);
            border: 2px solid #D4AF37;
            border-radius: 6px;
            width: 100%;
            max-width: 500px;
            padding: 25px;
            box-shadow: 0 0 30px rgba(212,175,55,0.3);
            position: relative;
        }
        .close-modal-btn {
            position: absolute;
            top: 15px; right: 15px;
            background: none; border: none;
            color: #8C6239; font-size: 1.5rem;
            cursor: pointer;
        }
        .close-modal-btn:hover {
            color: #D4AF37;
        }

        /* GAME LOG PANEL */
        .log-display {
            background-color: #03070d;
            border: 1px solid #1e293b;
            border-radius: 4px;
            height: 180px;
            overflow-y: auto;
            padding: 10px;
            font-family: monospace;
            font-size: 0.85rem;
            color: #A7F3D0;
        }

        /* RECRUITMENT AND TRAINING INPUT */
        .quant-input {
            width: 60px;
            background: #0A1220;
            border: 1px solid #8C6239;
            color: #FFF;
            padding: 4px;
            text-align: center;
            border-radius: 4px;
            margin-right: 8px;
        }
    </style>
</head>
<body>

    <!-- TOP NAVIGATION BAR -->
    <header class="top-navbar">
        <div class="nav-logo">
            <span style="color:#D4AF37;">🔱 Global Dominion:</span> 
            <span style="color:#FFF; font-size: 0.95rem;">Rise of Nations</span>
        </div>
        
        <div class="resources-container">
            <div class="resource-node">
                <span class="resource-label">Gold</span>
                <span id="gold-value">0</span>
            </div>
            <div class="resource-node">
                <span class="resource-label">Supplies</span>
                <span id="supplies-value">0</span>
            </div>
            <div class="resource-node">
                <span class="resource-label">Ore</span>
                <span id="ore-value">0</span>
            </div>
            <div class="resource-node">
                <span class="resource-label">Crystals</span>
                <span id="crystals-value">0</span>
            </div>
        </div>

        <div>
            <span style="margin-right: 15px; font-size:0.85rem; color:#8C6239;">RANK: <strong id="user-rank" style="color:#D4AF37;">Loading...</strong></span>
            <a href="/logout" class="logout-link">Stand Down</a>
        </div>
    </header>

    <!-- WRAPPER -->
    <div class="app-wrapper">
        <!-- SIDEBAR -->
        <aside class="sidebar">
            <button class="sidebar-btn active" onclick="switchView('map-view', this)">World Conquest</button>
            <button class="sidebar-btn" onclick="switchView('barracks-view', this)">Military Barracks</button>
            <button class="sidebar-btn" onclick="switchView('lab-view', this)">Research Laboratory</button>
            <button class="sidebar-btn" onclick="switchView('hq-view', this)">General's HQ</button>
        </aside>

        <!-- MAIN STAGE -->
        <main class="main-stage">

            <!-- WORLD CONQUEST VIEW -->
            <section id="map-view" class="view-panel">
                <div class="g-card">
                    <div class="g-header">
                        <h2>War Room Strategic Map</h2>
                        <span id="country-badge" style="background-color: #0A1220; border: 1px solid #8C6239; padding: 4px 10px; border-radius: 4px; color:#D4AF37; font-size:0.8rem;"></span>
                    </div>
                    <p style="font-size: 0.9rem; color: #94A3B8; margin-top:-10px; margin-bottom: 20px;">
                        Plan and coordinate maneuvers across sectors. Highlight a marked node to calculate territorial parameters and execute tactical assaults or explore local ruins.
                    </p>
                    
                    <div class="map-wrapper">
                        <svg class="world-svg" viewBox="0 0 1000 500" id="world-map">
                            <defs>
                                <pattern id="map-grid" width="40" height="40" patternUnits="userSpaceOnUse">
                                    <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#0f1e33" stroke-width="1"/>
                                </pattern>
                            </defs>
                            <rect width="1000" height="500" fill="url(#map-grid)" />
                            
                            <path d="M 120 100 Q 180 80 280 120 T 320 200 T 260 280 T 150 220 Z" fill="#0c1729" stroke="#122542" stroke-width="2"/>
                            <path d="M 190 300 Q 250 320 290 390 T 230 450 T 180 380 Z" fill="#0c1729" stroke="#122542" stroke-width="2"/>
                            <path d="M 420 120 Q 550 60 750 100 T 880 180 T 820 300 T 600 280 T 450 200 Z" fill="#0c1729" stroke="#122542" stroke-width="2"/>
                            <path d="M 720 350 Q 820 340 850 420 T 750 460 Z" fill="#0c1729" stroke="#122542" stroke-width="2"/>

                            <g id="map-markers-group"></g>
                        </svg>
                    </div>
                </div>

                <div class="g-card">
                    <div class="g-header">
                        <h3>Battlefield Operations Logs</h3>
                    </div>
                    <div id="battle-log" class="log-display">
                        SYSTEM DETECTED: Awaiting operations input from high command...
                    </div>
                </div>
            </section>

            <!-- MILITARY BARRACKS VIEW -->
            <section id="barracks-view" class="view-panel" style="display: none;">
                <div class="g-card">
                    <div class="g-header">
                        <h2>Military Barracks</h2>
                        <span>Force Level: <strong id="total-combat-force" style="color:#D4AF37;">0</strong></span>
                    </div>
                    <p style="font-size:0.9rem; color:#94A3B8; margin-top:-10px; margin-bottom:20px;">
                        Incorporate structural reinforcements to field units. High-tier evolutions require crystalline payloads to optimize specialized loadouts.
                    </p>

                    <div class="unit-grid" id="barracks-unit-list"></div>
                </div>
            </section>

            <!-- RESEARCH LABORATORY VIEW -->
            <section id="lab-view" class="view-panel" style="display: none;">
                <div class="g-card">
                    <div class="g-header">
                        <h2>Technology Research Laboratory</h2>
                    </div>
                    <p style="font-size:0.9rem; color:#94A3B8; margin-top:-10px; margin-bottom:20px;">
                        Unlock persistent force combat advantages. Leveling technology matrices increases passive yield structures across all active military assets.
                    </p>

                    <div class="tech-grid">
                        <div class="tech-card">
                            <h4 id="tech-infantry-title">Infantry Tactics (Lvl 1)</h4>
                            <p style="font-size: 0.8rem; color: #94A3B8; margin: 10px 0;">Boosts standard deployable infantry damage output by 10% per tier.</p>
                            <button class="g-btn" onclick="upgradeTech('infantry')">Initiate Research</button>
                        </div>
                        <div class="tech-card">
                            <h4 id="tech-vehicle-title">Armored Shell Operations (Lvl 1)</h4>
                            <p style="font-size: 0.8rem; color: #94A3B8; margin: 10px 0;">Escalates mechanized unit armor profiles by 15% per tier.</p>
                            <button class="g-btn" onclick="upgradeTech('vehicle')">Initiate Research</button>
                        </div>
                        <div class="tech-card">
                            <h4 id="tech-magic-title">Arcane Catalyst Rites (Lvl 1)</h4>
                            <p style="font-size: 0.8rem; color: #94A3B8; margin: 10px 0;">Magnifies structural explosive outcomes from spellcasting arrays.</p>
                            <button class="g-btn" onclick="upgradeTech('magic')">Initiate Research</button>
                        </div>
                        <div class="tech-card">
                            <h4 id="tech-resource-title">Industrial Excavation (Lvl 1)</h4>
                            <p style="font-size: 0.8rem; color: #94A3B8; margin: 10px 0;">Enables improved extraction rates across captured resource zones.</p>
                            <button class="g-btn" onclick="upgradeTech('resource')">Initiate Research</button>
                        </div>
                    </div>
                </div>
            </section>

            <!-- GENERAL'S HQ VIEW -->
            <section id="hq-view" class="view-panel" style="display: none;">
                <div class="g-card">
                    <div class="g-header">
                        <h2>Coalition Command Headquarters</h2>
                    </div>
                    <div style="display: flex; flex-wrap: wrap; gap: 30px; margin-top:15px;">
                        <div style="flex: 1; min-width: 280px; background: rgba(10,18,32,0.5); padding:20px; border-radius:4px;">
                            <h3 style="font-size:1.1rem; border-bottom:1px solid #8C6239; padding-bottom:10px;">General Profile</h3>
                            <ul style="list-style-type:none; padding:0; line-height:2.2; font-size:0.9rem;">
                                <li><strong>Designation:</strong> <span id="hq-username" style="color:#FFF;"></span></li>
                                <li><strong>National Alignment:</strong> <span id="hq-country" style="color:#D4AF37;"></span></li>
                                <li><strong>Passive Advantage:</strong> <span id="hq-passive" style="color:#94A3B8; font-size:0.85rem;"></span></li>
                                <li><strong>General's Rank:</strong> <span id="hq-rank" style="color:#FFF;"></span></li>
                                <li><strong>Dominion Score:</strong> <span id="hq-score" style="color:#D4AF37;"></span></li>
                            </ul>
                        </div>

                        <div style="flex: 1; min-width: 280px; background: rgba(10,18,32,0.5); padding:20px; border-radius:4px;">
                            <h3 style="font-size:1.1rem; border-bottom:1px solid #8C6239; padding-bottom:10px;">Global Leaderboard</h3>
                            <table style="width:100%; text-align:left; font-size:0.85rem; border-collapse: collapse; margin-top:10px;">
                                <thead>
                                    <tr style="border-bottom: 1px solid #8C6239; color:#8C6239;">
                                        <th style="padding: 6px 0;">GENERAL</th>
                                        <th>COALITION</th>
                                        <th style="text-align:right;">POWER</th>
                                    </tr>
                                </thead>
                                <tbody id="leaderboard-body"></tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </section>

        </main>
    </div>

    <!-- STRATEGIC ENGAGEMENT MODAL -->
    <div class="modal-overlay" id="tactical-modal">
        <div class="modal-box">
            <button class="close-modal-btn" onclick="closeTacticalModal()">&times;</button>
            <h3 id="modal-territory-title" style="margin-bottom: 10px;">Sector Command Console</h3>
            <p id="modal-territory-details" style="font-size: 0.85rem; color: #94A3B8; line-height: 1.4; margin-bottom: 20px;"></p>
            
            <div id="battle-prep-controls">
                <div style="background-color: #0A1220; border: 1px solid #1e293b; padding: 12px; border-radius:4px; margin-bottom:20px;">
                    <label style="font-size: 0.75rem; color:#8C6239; display:block; margin-bottom:6px; text-transform:uppercase;">Deploy Special Magic Support</label>
                    <select id="spell-selection" style="width:100%; padding:8px; background-color:#050B14; border:1px solid #8C6239; color:#FFF; border-radius:4px;">
                        <option value="">No Spell Allocation</option>
                        <option value="Meteor Strike">Meteor Strike (Cost: 30 Crystals)</option>
                        <option value="Earthquake">Earthquake (Cost: 25 Crystals)</option>
                        <option value="Lightning Storm">Lightning Storm (Cost: 20 Crystals)</option>
                    </select>
                </div>
                
                <div style="display: flex; gap: 10px;">
                    <button class="g-btn" style="flex:1;" id="btn-execute-assault">Launch Assault Force</button>
                    <button class="g-btn-sec" style="flex:1;" id="btn-explore-ruins">Explore Ruins Sector</button>
                </div>
            </div>
        </div>
    </div>

    <script>
        let gameState = {};
        let activeSelectedTerritoryId = null;

        setInterval(() => {
            if (gameState.profile) {
                let activeSecMult = 1 / 60.0;
                let addGold = 5.0 * activeSecMult;
                let addSupplies = 3.0 * activeSecMult;
                let addOre = 1.0 * activeSecMult;
                let addCrystals = 0.2 * activeSecMult;

                if (gameState.territories) {
                    gameState.territories.forEach(t => {
                        if (t.controlling_country === gameState.profile.country) {
                            let yieldVal = t.resource_rate * activeSecMult;
                            if (t.resource_type === 'gold') addGold += yieldVal;
                            else if (t.resource_type === 'supplies') addSupplies += yieldVal;
                            else if (t.resource_type === 'ore') addOre += yieldVal;
                            else if (t.resource_type === 'crystals') addCrystals += yieldVal;
                        }
                    });
                }

                if (gameState.profile.country === "USA") {
                    addGold *= 1.10; addSupplies *= 1.10; addOre *= 1.10; addCrystals *= 1.10;
                }

                if (gameState.research) {
                    let rMult = 1.0 + (gameState.research.resource - 1) * 0.08;
                    addGold *= rMult; addSupplies *= rMult; addOre *= rMult; addCrystals *= rMult;
                }

                gameState.profile.gold += addGold;
                gameState.profile.supplies += addSupplies;
                gameState.profile.ore += addOre;
                gameState.profile.crystals += addCrystals;

                updateUIResourceCounters();
            }
        }, 1000);

        setInterval(fetchGameState, 12000);

        function updateUIResourceCounters() {
            if (gameState.profile) {
                document.getElementById('gold-value').innerText = Math.floor(gameState.profile.gold);
                document.getElementById('supplies-value').innerText = Math.floor(gameState.profile.supplies);
                document.getElementById('ore-value').innerText = Math.floor(gameState.profile.ore);
                document.getElementById('crystals-value').innerText = Math.floor(gameState.profile.crystals);
            }
        }

        async function fetchGameState() {
            try {
                const response = await fetch('/api/state');
                if (response.status === 401) {
                    window.location.href = '/login';
                    return;
                }
                gameState = await response.json();
                renderUI();
            } catch (err) {
                console.warn("Retrying database synchronization...", err);
            }
        }

        function switchView(viewId, element) {
            document.querySelectorAll('.view-panel').forEach(panel => panel.style.display = 'none');
            document.getElementById(viewId).style.display = 'block';

            document.querySelectorAll('.sidebar-btn').forEach(btn => btn.classList.remove('active'));
            element.classList.add('active');
        }

        function renderUI() {
            if (!gameState.profile) return;

            document.getElementById('user-rank').innerText = gameState.profile.rank;
            document.getElementById('country-badge').innerText = `Nation Command: ${gameState.profile.country}`;
            updateUIResourceCounters();

            const mapGroup = document.getElementById('map-markers-group');
            mapGroup.innerHTML = '';
            
            gameState.territories.forEach(t => {
                const colorMap = {
                    "Neutral": "#475569",
                    "USA": "#1D4ED8",
                    "Japan": "#B91C1C",
                    "Russia": "#15803D",
                    "Philippines": "#D97706"
                };
                let markerColor = colorMap[t.controlling_country] || "#8C6239";
                if (t.controlling_country === gameState.profile.country) {
                     markerColor = "#D4AF37";
                }

                const nodeGroup = document.createElementNS("http://www.w3.org/2000/svg", "g");
                nodeGroup.setAttribute("class", "map-node");
                nodeGroup.setAttribute("transform", `translate(${t.x}, ${t.y})`);
                nodeGroup.onclick = () => openTacticalModal(t);

                const circle = document.createElementNS("http://www.w3.org/2000/svg", "circle");
                circle.setAttribute("r", "14");
                circle.setAttribute("fill", markerColor);
                circle.setAttribute("stroke", "#000");
                circle.setAttribute("stroke-width", "2");
                nodeGroup.appendChild(circle);

                const innerCore = document.createElementNS("http://www.w3.org/2000/svg", "circle");
                innerCore.setAttribute("r", "5");
                innerCore.setAttribute("fill", t.has_ruins ? "#C24A1D" : "#FFF");
                nodeGroup.appendChild(innerCore);

                const text = document.createElementNS("http://www.w3.org/2000/svg", "text");
                text.setAttribute("y", "-20");
                text.setAttribute("text-anchor", "middle");
                text.setAttribute("fill", "#E2E8F0");
                text.style.fontSize = "10px";
                text.style.fontFamily = "Cinzel, serif";
                text.style.fontWeight = "bold";
                text.textContent = t.name;
                nodeGroup.appendChild(text);

                mapGroup.appendChild(nodeGroup);
            });

            const barracksList = document.getElementById('barracks-unit-list');
            barracksList.innerHTML = '';
            let combinedPower = 0;

            gameState.units.forEach(u => {
                combinedPower += (u.quantity * u.level * 10);
                const card = document.createElement('div');
                card.className = 'unit-card';
                card.innerHTML = `
                    <div style="display:flex; justify-content:space-between; align-items:center;">
                        <h4 style="margin:0; font-size:1.1rem; color:#FFF;">${u.name}</h4>
                        <span style="color:#D4AF37; font-size:0.75rem; text-transform:uppercase;">[${u.rank_title}]</span>
                    </div>
                    <p style="font-size:0.8rem; color:#94A3B8; margin: 8px 0;">Strategic Tier: Lvl ${u.level} | Power: ${u.attack_power} AP</p>
                    <div style="font-size:1rem; margin-bottom:15px; color:#E2E8F0;">Active In Barracks: <strong style="color:#D4AF37;">${u.quantity}</strong></div>
                    
                    <div style="border-top:1px solid #1e293b; padding-top:12px; display:flex; flex-direction:column; gap:8px;">
                        <div style="display:flex; align-items:center;">
                            <input type="number" class="quant-input" id="quant-${u.type}" value="5" min="1">
                            <button class="g-btn" style="flex:1;" onclick="recruitUnit('${u.type}')">Recruit (+400g)</button>
                        </div>
                        <button class="g-btn-sec" onclick="evolveUnit('${u.type}')">Evolve Tier (Lvl ${u.level + 1})</button>
                    </div>
                `;
                barracksList.appendChild(card);
            });
            document.getElementById('total-combat-force').innerText = combinedPower;

            document.getElementById('tech-infantry-title').innerText = `Infantry Tactics (Lvl ${gameState.research.infantry})`;
            document.getElementById('tech-vehicle-title').innerText = `Armored Shell Operations (Lvl ${gameState.research.vehicle})`;
            document.getElementById('tech-magic-title').innerText = `Arcane Catalyst Rites (Lvl ${gameState.research.magic})`;
            document.getElementById('tech-resource-title').innerText = `Industrial Excavation (Lvl ${gameState.research.resource})`;

            document.getElementById('hq-username').innerText = gameState.profile.username;
            document.getElementById('hq-country').innerText = gameState.profile.country;
            document.getElementById('hq-passive').innerText = gameState.profile.country_bonus;
            document.getElementById('hq-rank').innerText = gameState.profile.rank;
            document.getElementById('hq-score').innerText = gameState.profile.power_level;

            const leaderboard = document.getElementById('leaderboard-body');
            leaderboard.innerHTML = '';
            gameState.leaderboard.forEach(entry => {
                const tr = document.createElement('tr');
                tr.style.borderBottom = '1px solid #1e293b';
                tr.innerHTML = `
                    <td style="padding:10px 0; font-weight:bold; color:#FFF;">${entry.username}</td>
                    <td><span style="background-color:#0A1220; border:1px solid #8C6239; padding:2px 8px; border-radius:3px; font-size:0.75rem;">${entry.country}</span></td>
                    <td style="text-align:right; color:#D4AF37; font-weight:bold;">${entry.power}</td>
                `;
                leaderboard.appendChild(tr);
            });
        }

        function openTacticalModal(territory) {
            activeSelectedTerritoryId = territory.id;
            const modal = document.getElementById('tactical-modal');
            const title = document.getElementById('modal-territory-title');
            const details = document.getElementById('modal-territory-details');

            title.innerText = `${territory.name}`;
            details.innerHTML = `
                <strong>Strategic Control:</strong> ${territory.owner} (${territory.controlling_country})<br>
                <strong>Environmental Yield:</strong> +${territory.resource_rate} ${territory.resource_type.toUpperCase()} / min<br>
                <strong>Unexplored Ruins Found:</strong> ${territory.has_ruins ? "DETECTED" : "COMPLETED"}<br><br>
                Verify battle preparations or deploy arcane interventions before initiating terminal tactical combat maneuvers.
            `;

            const isOwned = (territory.controlling_country === gameState.profile.country);
            document.getElementById('btn-execute-assault').style.display = isOwned ? 'none' : 'block';
            document.getElementById('btn-explore-ruins').style.display = (isOwned && territory.has_ruins) ? 'block' : 'none';
            document.getElementById('spell-selection').disabled = isOwned;

            modal.classList.add('active');
        }

        function closeTacticalModal() {
            document.getElementById('tactical-modal').classList.remove('active');
            activeSelectedTerritoryId = null;
        }

        async function recruitUnit(unitType) {
            const qtyInput = document.getElementById(`quant-${unitType}`);
            const qty = qtyInput ? qtyInput.value : 5;
            
            try {
                const res = await fetch('/api/recruit_unit', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({ unit_type: unitType, quantity: qty })
                });
                const data = await res.json();
                alert(data.message);
                fetchGameState();
            } catch (err) {
                console.error(err);
            }
        }

        async function evolveUnit(unitType) {
            try {
                const res = await fetch('/api/evolve_unit', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({ unit_type: unitType })
                });
                const data = await res.json();
                alert(data.message);
                fetchGameState();
            } catch (err) {
                console.error(err);
            }
        }

        async function upgradeTech(techName) {
            try {
                const res = await fetch('/api/research_upgrade', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({ tech: techName })
                });
                const data = await res.json();
                alert(data.message);
                fetchGameState();
            } catch (err) {
                console.error(err);
            }
        }

        document.getElementById('btn-execute-assault').onclick = async () => {
            if (!activeSelectedTerritoryId) return;
            const spell = document.getElementById('spell-selection').value;

            try {
                const res = await fetch('/api/attack', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({ territory_id: activeSelectedTerritoryId, spell: spell })
                });
                const data = await res.json();
                closeTacticalModal();

                const log = document.getElementById('battle-log');
                const timestamp = new Date().toLocaleTimeString();
                let outputLogHTML = `<div style="margin-bottom:8px; border-bottom:1px solid #101f35; padding-bottom:4px;">
                    <span style="color:#D4AF37;">[${timestamp}] OPERATIONS:</span> ${data.message}<br>`;
                
                if (data.stats) {
                    outputLogHTML += `Deployed Force AP Roll: <strong style="color:#FFF;">${data.stats.player_roll}</strong> | Adversary defensive roll: <strong style="color:#C24A1D;">${data.stats.enemy_roll}</strong> | Battlefield Attrition Losses: <strong style="color:#EF4444;">${data.stats.losses}</strong><br>`;
                }
                if (data.loot && data.loot.gold) {
                    outputLogHTML += `Loot Gained: <span style="color:#F59E0B;">+${data.loot.gold} Gold</span> | <span style="color:#3B82F6;">+${data.loot.supplies} Supplies</span> | <span style="color:#A855F7;">+${data.loot.crystals} Crystals</span><br>`;
                    if (data.loot.crate) {
                        outputLogHTML += `High Tier Crate Unlocked: <strong style="color:#10B981;">${data.loot.crate}</strong><br>`;
                    }
                }
                outputLogHTML += `</div>`;

                log.innerHTML = outputLogHTML + log.innerHTML;
                fetchGameState();
            } catch (err) {
                console.error(err);
            }
        };

        document.getElementById('btn-explore-ruins').onclick = async () => {
            if (!activeSelectedTerritoryId) return;

            try {
                const res = await fetch('/api/explore_ruins', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({ territory_id: activeSelectedTerritoryId })
                });
                const data = await res.json();
                closeTacticalModal();
                alert(data.message);
                fetchGameState();
            } catch (err) {
                console.error(err);
            }
        };

        fetchGameState();
    </script>
</body>
</html>
"""


# -------------------------------------------------------------------------
# FLASK BACKEND CONFIGURATION
# -------------------------------------------------------------------------

app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", "gd_imperial_secret_key_9921")

# Database initialization
db_url = os.environ.get("DATABASE_URL", "sqlite:///global_dominion.db")
if db_url.startswith("postgres://"):
    db_url = db_url.replace("postgres://", "postgresql://", 1)
app.config['SQLALCHEMY_DATABASE_URI'] = db_url
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

# -------------------------------------------------------------------------
# DATABASE MODELS
# -------------------------------------------------------------------------

class User(db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(120), nullable=False)
    country = db.Column(db.String(50), nullable=True)
    rank = db.Column(db.String(50), default="Recruit General")
    power_level = db.Column(db.Integer, default=100)
    
    # Resources
    gold = db.Column(db.Float, default=1000.0)
    supplies = db.Column(db.Float, default=500.0)
    ore = db.Column(db.Float, default=200.0)
    crystals = db.Column(db.Float, default=50.0)
    last_tick_time = db.Column(db.DateTime, default=datetime.utcnow)

    units = db.relationship('Unit', backref='owner', lazy=True)
    research = db.relationship('Research', backref='owner', uselist=False, lazy=True)
    territories = db.relationship('Territory', backref='owner', lazy=True)

class Territory(db.Model):
    __tablename__ = 'territories'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), unique=True, nullable=False)
    owner_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)
    controlling_country = db.Column(db.String(50), default="Neutral")
    x_coord = db.Column(db.Integer, nullable=False)
    y_coord = db.Column(db.Integer, nullable=False)
    has_ruins = db.Column(db.Boolean, default=True)
    resource_type = db.Column(db.String(20), default="gold")
    resource_rate = db.Column(db.Float, default=10.0)

class Unit(db.Model):
    __tablename__ = 'units'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    unit_type = db.Column(db.String(50), nullable=False)
    level = db.Column(db.Integer, default=1)
    quantity = db.Column(db.Integer, default=0)

class Research(db.Model):
    __tablename__ = 'research'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    infantry_level = db.Column(db.Integer, default=1)
    vehicle_level = db.Column(db.Integer, default=1)
    magic_level = db.Column(db.Integer, default=1)
    resource_level = db.Column(db.Integer, default=1)


# -------------------------------------------------------------------------
# METADATA & CONFIG
# -------------------------------------------------------------------------

COUNTRY_DATA = {
    "USA": {
        "bonus": "+10% Resource Production",
        "units": ["Marine Infantry", "Abrams Tank", "F-35 Fighter", "Aircraft Carrier"]
    },
    "Japan": {
        "bonus": "+15% Tactical Attack Power",
        "units": ["Samurai Guard", "Modern Infantry", "Type-10 Tank", "Drone Squadron"]
    },
    "Russia": {
        "bonus": "+20% Defensive Unit Fortification",
        "units": ["Spetsnaz", "T-90 Tank", "Missile Launcher", "Attack Helicopter"]
    },
    "Philippines": {
        "bonus": "+15% Unit Speed & Magic Resistance",
        "units": ["Scout Infantry", "Marine Battalion", "Jungle Rangers", "Coastal Defense Unit"]
    }
}


# -------------------------------------------------------------------------
# GAME ENGINE LOGIC & UTILITIES
# -------------------------------------------------------------------------

def process_resource_generation(user):
    now = datetime.utcnow()
    elapsed = (now - user.last_tick_time).total_seconds()
    minutes = elapsed / 60.0

    if minutes <= 0:
        return

    # Standard base accumulation rates
    gold_gain = 5.0 * minutes
    supplies_gain = 3.0 * minutes
    ore_gain = 1.0 * minutes
    crystals_gain = 0.2 * minutes

    # Append conquered territory outputs
    for t in user.territories:
        gain = t.resource_rate * minutes
        if t.resource_type == 'gold':
            gold_gain += gain
        elif t.resource_type == 'supplies':
            supplies_gain += gain
        elif t.resource_type == 'ore':
            ore_gain += gain
        elif t.resource_type == 'crystals':
            crystals_gain += gain

    # Passive Faction Adjustments
    if user.country == "USA":
        gold_gain *= 1.10
        supplies_gain *= 1.10
        ore_gain *= 1.10
        crystals_gain *= 1.10

    # Tech laboratory rate adjustments
    if user.research:
        research_mult = 1.0 + (user.research.resource_level - 1) * 0.08
        gold_gain *= research_mult
        supplies_gain *= research_mult
        ore_gain *= research_mult
        crystals_gain *= research_mult

    user.gold += gold_gain
    user.supplies += supplies_gain
    user.ore += ore_gain
    user.crystals += crystals_gain
    user.last_tick_time = now
    
    total_units = sum([u.quantity * u.level * 10 for u in user.units])
    user.power_level = 100 + total_units + (len(user.territories) * 50) + (user.research.infantry_level * 15)

    db.session.commit()

def get_unit_rank_name(level):
    levels = {1: "Recruit", 2: "Veteran", 3: "Elite", 4: "Heroic", 5: "Legendary"}
    return levels.get(level, "Recruit")


# -------------------------------------------------------------------------
# FLASK ROUTING
# -------------------------------------------------------------------------

@app.route('/')
def home():
    if 'user_id' in session:
        user = User.query.get(session['user_id'])
        if user:
            if not user.country:
                return redirect(url_for('country_selection'))
            return render_template_string(INDEX_HTML, user=user)
    return redirect(url_for('login'))

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form.get('username')
        email = request.form.get('email')
        password = request.form.get('password')
        confirm_password = request.form.get('confirm_password')

        if not username or not email or not password:
            return render_template_string(REGISTER_HTML, error="All fields are required.")
        if password != confirm_password:
            return render_template_string(REGISTER_HTML, error="Passwords do not match.")

        existing_user = User.query.filter((User.username == username) | (User.email == email)).first()
        if existing_user:
            return render_template_string(REGISTER_HTML, error="Username or Email already exists.")

        hashed = generate_password_hash(password, method='sha256')
        new_user = User(username=username, email=email, password_hash=hashed)
        db.session.add(new_user)
        db.session.commit()

        new_research = Research(user_id=new_user.id)
        db.session.add(new_research)
        
        for utype in ['Infantry', 'Vehicle', 'Aircraft', 'Special']:
            db.session.add(Unit(user_id=new_user.id, unit_type=utype, quantity=0, level=1))
        
        db.session.commit()
        session['user_id'] = new_user.id
        return redirect(url_for('country_selection'))

    return render_template_string(REGISTER_HTML)

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        identifier = request.form.get('identifier')
        password = request.form.get('password')

        user = User.query.filter((User.username == identifier) | (User.email == identifier)).first()
        if user and check_password_hash(user.password_hash, password):
            session['user_id'] = user.id
            if not user.country:
                return redirect(url_for('country_selection'))
            return redirect(url_for('home'))
        return render_template_string(LOGIN_HTML, error="Invalid credentials submitted.")
    
    return render_template_string(LOGIN_HTML)

@app.route('/logout')
def logout():
    session.pop('user_id', None)
    return redirect(url_for('login'))

@app.route('/country_selection', methods=['GET', 'POST'])
def country_selection():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    user = User.query.get(session['user_id'])
    if not user:
        return redirect(url_for('login'))

    if user.country:
        return redirect(url_for('home'))

    if request.method == 'POST':
        selected_country = request.form.get('country')
        if selected_country in COUNTRY_DATA:
            user.country = selected_country
            units = Unit.query.filter_by(user_id=user.id).all()
            for u in units:
                u.quantity = 5
            db.session.commit()
            return redirect(url_for('home'))

    return render_template_string(COUNTRY_SELECTION_HTML, countries=COUNTRY_DATA)


# -------------------------------------------------------------------------
# API ROUTING
# -------------------------------------------------------------------------

@app.route('/api/state', methods=['GET'])
def get_state():
    if 'user_id' not in session:
        return jsonify({"error": "Unauthorized Access"}), 401
    
    user = User.query.get(session['user_id'])
    if not user:
         return jsonify({"error": "User record not found"}), 404

    process_resource_generation(user)

    units_data = []
    avail_units = COUNTRY_DATA[user.country]["units"]
    for u in user.units:
        idx = 0
        if u.unit_type == 'Vehicle': idx = 1
        elif u.unit_type == 'Aircraft': idx = 2
        elif u.unit_type == 'Special': idx = 3
        
        name = avail_units[idx] if idx < len(avail_units) else u.unit_type
        units_data.append({
            "id": u.id,
            "type": u.unit_type,
            "name": name,
            "level": u.level,
            "rank_title": get_unit_rank_name(u.level),
            "quantity": u.quantity,
            "attack_power": (10 * u.level) + (u.level * 5),
            "defense_power": (8 * u.level) + (u.level * 4)
        })

    global_territories = Territory.query.all()
    map_data = []
    for gt in global_territories:
        owner_name = "Neutral Forces"
        if gt.owner_id:
            owner_user = User.query.get(gt.owner_id)
            if owner_user:
                owner_name = owner_user.username

        map_data.append({
            "id": gt.id,
            "name": gt.name,
            "owner": owner_name,
            "controlling_country": gt.controlling_country,
            "x": gt.x_coord,
            "y": gt.y_coord,
            "has_ruins": gt.has_ruins,
            "resource_type": gt.resource_type,
            "resource_rate": gt.resource_rate
        })

    top_players = User.query.order_by(User.power_level.desc()).limit(10).all()
    leaderboard = [{
        "username": p.username,
        "country": p.country,
        "power": p.power_level,
        "territories": len(p.territories)
    } for p in top_players]

    return jsonify({
        "profile": {
            "username": user.username,
            "country": user.country,
            "rank": user.rank,
            "power_level": user.power_level,
            "gold": int(user.gold),
            "supplies": int(user.supplies),
            "ore": int(user.ore),
            "crystals": int(user.crystals),
            "country_bonus": COUNTRY_DATA[user.country]["bonus"]
        },
        "research": {
            "infantry": user.research.infantry_level if user.research else 1,
            "vehicle": user.research.vehicle_level if user.research else 1,
            "magic": user.research.magic_level if user.research else 1,
            "resource": user.research.resource_level if user.research else 1
        },
        "units": units_data,
        "territories": map_data,
        "leaderboard": leaderboard
    })

@app.route('/api/recruit_unit', methods=['POST'])
def recruit_unit():
    if 'user_id' not in session:
         return jsonify({"error": "Unauthorized Access"}), 401

    user = User.query.get(session['user_id'])
    data = request.json or {}
    unit_type = data.get('unit_type')
    amount = int(data.get('quantity', 1))

    if amount <= 0:
        return jsonify({"success": False, "message": "Invalid recruitment volume"}), 400

    cost_gold = 80 * amount
    cost_supplies = 40 * amount

    process_resource_generation(user)

    if user.gold < cost_gold or user.supplies < cost_supplies:
        return jsonify({"success": False, "message": "Insufficient Gold or Supplies."}), 400

    target_unit = Unit.query.filter_by(user_id=user.id, unit_type=unit_type).first()
    if not target_unit:
        return jsonify({"success": False, "message": "Unit parameters structural mismatch."}), 400

    user.gold -= cost_gold
    user.supplies -= cost_supplies
    target_unit.quantity += amount
    db.session.commit()

    return jsonify({"success": True, "message": f"Successfully recruited {amount} {unit_type} units."})

@app.route('/api/evolve_unit', methods=['POST'])
def evolve_unit():
    if 'user_id' not in session:
         return jsonify({"error": "Unauthorized Access"}), 401

    user = User.query.get(session['user_id'])
    data = request.json or {}
    unit_type = data.get('unit_type')

    process_resource_generation(user)

    target_unit = Unit.query.filter_by(user_id=user.id, unit_type=unit_type).first()
    if not target_unit:
        return jsonify({"success": False, "message": "Unit type not found."}), 400

    if target_unit.level >= 5:
        return jsonify({"success": False, "message": "Unit has already reached its terminal Legendary Evolution status."}), 400

    ore_cost = 100 * target_unit.level
    crystal_cost = 25 * target_unit.level

    if user.ore < ore_cost or user.crystals < crystal_cost:
        return jsonify({"success": False, "message": f"Upgrade requires {ore_cost} Ore and {crystal_cost} Crystals."}), 400

    user.ore -= ore_cost
    user.crystals -= crystal_cost
    target_unit.level += 1
    db.session.commit()

    return jsonify({"success": True, "message": f"Evolved {unit_type} to level {target_unit.level} ({get_unit_rank_name(target_unit.level)})."})

@app.route('/api/research_upgrade', methods=['POST'])
def research_upgrade():
    if 'user_id' not in session:
         return jsonify({"error": "Unauthorized Access"}), 401

    user = User.query.get(session['user_id'])
    data = request.json or {}
    tech = data.get('tech')

    process_resource_generation(user)
    
    current_level = 1
    if tech == 'infantry': current_level = user.research.infantry_level
    elif tech == 'vehicle': current_level = user.research.vehicle_level
    elif tech == 'magic': current_level = user.research.magic_level
    elif tech == 'resource': current_level = user.research.resource_level
    else:
        return jsonify({"success": False, "message": "Invalid technology categorization."}), 400

    gold_cost = 400 * current_level
    crystal_cost = 30 * current_level

    if user.gold < gold_cost or user.crystals < crystal_cost:
        return jsonify({"success": False, "message": f"Requires {gold_cost} Gold and {crystal_cost} Crystals."}), 400

    user.gold -= gold_cost
    user.crystals -= crystal_cost

    if tech == 'infantry': user.research.infantry_level += 1
    elif tech == 'vehicle': user.research.vehicle_level += 1
    elif tech == 'magic': user.research.magic_level += 1
    elif tech == 'resource': user.research.resource_level += 1

    db.session.commit()
    return jsonify({"success": True, "message": f"Successfully researched and leveled up {tech.capitalize()} to level {current_level + 1}."})

@app.route('/api/attack', methods=['POST'])
def attack_territory():
    if 'user_id' not in session:
         return jsonify({"error": "Unauthorized Access"}), 401

    user = User.query.get(session['user_id'])
    data = request.json or {}
    territory_id = data.get('territory_id')
    spell_casted = data.get('spell')

    target_territory = Territory.query.get(territory_id)
    if not target_territory:
        return jsonify({"success": False, "message": "Specified zone doesn't exist."}), 400

    if target_territory.owner_id == user.id:
        return jsonify({"success": False, "message": "This territory is already verified under your tactical control."}), 400

    process_resource_generation(user)

    if target_territory.controlling_country == user.country and target_territory.controlling_country != "Neutral":
        return jsonify({"success": False, "message": "Alliance Protocol: Active players in the same nation cannot engage in mutual combat."}), 400

    user_units = Unit.query.filter_by(user_id=user.id).all()
    total_attacking_power = 0
    total_deployed_units = 0
    for u in user_units:
        total_attacking_power += u.quantity * ((u.level * 12) + 5)
        total_deployed_units += u.quantity

    if total_deployed_units == 0:
        return jsonify({"success": False, "message": "You have no units available in your barracks to launch a military operation."}), 400

    tech_bonus_inf = 1.0 + (user.research.infantry_level - 1) * 0.1
    tech_bonus_veh = 1.0 + (user.research.vehicle_level - 1) * 0.15
    total_attacking_power *= ((tech_bonus_inf + tech_bonus_veh) / 1.8)

    if spell_casted:
        spell_costs = {"Meteor Strike": 30, "Earthquake": 25, "Lightning Storm": 20}
        cost = spell_costs.get(spell_casted, 0)
        if user.crystals < cost:
            return jsonify({"success": False, "message": f"Insufficient crystal mana to channel {spell_casted}."}), 400
        user.crystals -= cost
        total_attacking_power += (cost * 8)

    if target_territory.owner_id is not None:
        base_enemy_defense = 400 + (target_territory.id * 40)
    else:
        base_enemy_defense = 100 + (target_territory.id * 20)

    player_roll = total_attacking_power * random.uniform(0.75, 1.25)
    enemy_roll = base_enemy_defense * random.uniform(0.8, 1.2)

    battle_won = player_roll > enemy_roll
    loss_rate = random.uniform(0.1, 0.25) if battle_won else random.uniform(0.4, 0.6)

    for u in user_units:
        u.quantity = max(0, int(u.quantity - (u.quantity * loss_rate)))

    loot_gained = {}
    if battle_won:
        target_territory.owner_id = user.id
        target_territory.controlling_country = user.country

        loot_gold = random.randint(150, 450)
        loot_supplies = random.randint(80, 250)
        loot_crystals = random.randint(3, 10) if random.random() < 0.30 else 0

        user.gold += loot_gold
        user.supplies += loot_supplies
        user.crystals += loot_crystals

        loot_gained = {
            "gold": loot_gold,
            "supplies": loot_supplies,
            "crystals": loot_crystals
        }

        crate_roll = random.random()
        crate_type = "Common War Chest"
        if crate_roll <= 0.02:
            crate_type = "Imperial Relic (Legendary)"
            user.crystals += 40
        elif crate_roll <= 0.10:
            crate_type = "Dominion Crate (Epic)"
            user.ore += 100
        elif crate_roll <= 0.30:
            crate_type = "Combat Supply Crate (Rare)"
            user.supplies += 200

        loot_gained["crate"] = crate_type
        target_territory.has_ruins = True
        
        db.session.commit()
        return jsonify({
            "success": True,
            "battle_won": True,
            "message": f"Conquest Successful! You have established command over {target_territory.name}.",
            "stats": {"player_roll": int(player_roll), "enemy_roll": int(enemy_roll), "losses": f"{int(loss_rate * 100)}%"},
            "loot": loot_gained
        })
    else:
        db.session.commit()
        return jsonify({
            "success": True,
            "battle_won": False,
            "message": f"Defeat! Your strike force was repelled from securing {target_territory.name}.",
            "stats": {"player_roll": int(player_roll), "enemy_roll": int(enemy_roll), "losses": f"{int(loss_rate * 100)}%"},
            "loot": {}
        })

@app.route('/api/explore_ruins', methods=['POST'])
def explore_ruins():
    if 'user_id' not in session:
         return jsonify({"error": "Unauthorized Access"}), 401

    user = User.query.get(session['user_id'])
    data = request.json or {}
    territory_id = data.get('territory_id')

    target_territory = Territory.query.get(territory_id)
    if not target_territory or target_territory.owner_id != user.id:
        return jsonify({"success": False, "message": "You must hold dominion over this territory to inspect its ruins."}), 400

    if not target_territory.has_ruins:
        return jsonify({"success": False, "message": "These ruins have already been thoroughly excavated."}), 400

    process_resource_generation(user)

    exploration_outcomes = [
        {"type": "ore", "amount": 120, "text": "Discovered deep veins of Celestial Metal & Mythic Ore!"},
        {"type": "crystals", "amount": 15, "text": "Excavated glowing Arcane Crystals from the lost catacombs!"},
        {"type": "gold", "amount": 600, "text": "Uncovered a gold cache inside a forgotten vault!"},
        {"type": "spells", "amount": 0, "text": "Unearthed dynamic ancient technology blueprints! Unit capabilities enhanced."}
    ]

    outcome = random.choice(exploration_outcomes)
    
    if outcome["type"] == "ore":
        user.ore += outcome["amount"]
    elif outcome["type"] == "crystals":
        user.crystals += outcome["amount"]
    elif outcome["type"] == "gold":
        user.gold += outcome["amount"]
    elif outcome["type"] == "spells":
        if user.research:
            user.research.magic_level += 1

    target_territory.has_ruins = False
    db.session.commit()

    return jsonify({
        "success": True,
        "message": f"Exploration complete: {outcome['text']}"
    })


# -------------------------------------------------------------------------
# DATABASE SEEDING
# -------------------------------------------------------------------------

def seed_database():
    if Territory.query.count() == 0:
        default_territories = [
            ("North America East Coast", 190, 160, "gold", 25.0),
            ("Cascadia Plains", 110, 130, "supplies", 15.0),
            ("Andean Heights", 220, 360, "ore", 8.0),
            ("Western European Core", 440, 140, "gold", 30.0),
            ("Siberian Outpost", 680, 80, "ore", 12.0),
            ("East Asian Hub", 720, 180, "supplies", 25.0),
            ("Sahara Sector", 460, 240, "crystals", 1.5),
            ("Australian Outback", 810, 380, "ore", 10.0),
            ("Philippine Trench", 790, 250, "crystals", 2.0),
            ("Indian Ocean Archipelago", 640, 300, "gold", 18.0),
            ("Amazon Basin", 240, 310, "supplies", 20.0),
            ("Scandinavian Shield", 480, 80, "crystals", 1.0)
        ]
        for name, x, y, rtype, rate in default_territories:
            db.session.add(Territory(
                name=name,
                x_coord=x,
                y_coord=y,
                resource_type=rtype,
                resource_rate=rate,
                has_ruins=True
            ))
        db.session.commit()


# -------------------------------------------------------------------------
# APPLICATION ENTRYPOINT
# -------------------------------------------------------------------------

with app.app_context():
    db.create_all()
    seed_database()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)