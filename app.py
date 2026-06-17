import os
import random
from datetime import datetime, timedelta

from flask import Flask, request, jsonify, session, redirect, url_for, render_template_string
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash

app = Flask(__name__)
app.permanent_session_lifetime = timedelta(days=30)
app.secret_key = os.environ.get("SECRET_KEY", "gd_imperial_secret_key_9921")

# Database initialization
# Use DATABASE_URL when provided, otherwise fall back to local SQLite.
# The app import must not crash if the external database is unavailable.
db_url = os.environ.get("DATABASE_URL")
if not db_url:
    db_url = "sqlite:///global_dominion.db"
elif db_url.startswith("postgres://"):
    db_url = db_url.replace("postgres://", "postgresql://", 1)
app.config['SQLALCHEMY_DATABASE_URI'] = db_url
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {
    'pool_pre_ping': True,
}

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
    <link rel="icon" type="image/png" href="{{ url_for('static', filename='img/favicon-32.png') }}">
    <link rel="apple-touch-icon" href="{{ url_for('static', filename='img/favicon-180.png') }}">
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Cinzel:wght@400;600;700;900&family=Cinzel+Decorative:wght@700;900&family=Inter:wght@300;400;500;600;700&display=swap');

        :root {
            --ink: #050b14; --void: #02050a; --navy: #0c1a30; --navy-2: #112340;
            --gold: #d4af37; --gold-bright: #f3d27a; --gold-dim: #a8842c; --bronze: #8c6239;
            --crimson: #9a2530; --crimson-bright: #c0392b; --ember: #d2691e;
            --parchment: #e7ecf3; --muted: #8fa1b8; --line: rgba(212,175,55,0.25);
        }
        * { box-sizing: border-box; }
        body {
            margin: 0; min-height: 100vh;
            background: radial-gradient(ellipse 900px 600px at 50% -10%, rgba(212,175,55,0.10), transparent 60%),
                        radial-gradient(ellipse 700px 500px at 90% 110%, rgba(154,37,48,0.12), transparent 60%),
                        linear-gradient(180deg, #0a1422 0%, var(--void) 100%);
            color: var(--parchment);
            font-family: 'Inter', sans-serif;
            display: flex; align-items: center; justify-content: center;
            padding: 40px 20px; position: relative; overflow-x: hidden;
        }
        .embers { position: fixed; inset: 0; pointer-events: none; z-index: 0; overflow: hidden; }
        .ember-mote {
            position: absolute; bottom: -10px; width: 4px; height: 4px; border-radius: 50%;
            background: var(--ember); box-shadow: 0 0 8px 2px rgba(210,105,30,0.7);
            opacity: 0; animation: drift 9s linear infinite;
        }
        @keyframes drift {
            0% { opacity: 0; transform: translateY(0) translateX(0); }
            10% { opacity: 0.85; } 90% { opacity: 0.4; }
            100% { opacity: 0; transform: translateY(-94vh) translateX(20px); }
        }
        @media (prefers-reduced-motion: reduce) { .ember-mote { animation: none; display: none; } }

        .frame-outer {
            position: relative; z-index: 1; width: 100%; max-width: 440px;
            border: 1px solid var(--bronze); border-radius: 16px; padding: 3px;
            background: linear-gradient(160deg, rgba(212,175,55,0.16), rgba(0,0,0,0) 40%);
            box-shadow: 0 30px 70px rgba(0,0,0,0.55), 0 0 0 1px rgba(0,0,0,0.4);
        }
        .frame-inner {
            border: 1px solid var(--line); border-radius: 13px; padding: 38px 36px 34px;
            background: linear-gradient(165deg, rgba(17,35,64,0.92), rgba(5,11,20,0.97) 55%);
            text-align: center;
        }
        .crest {
            width: 96px; margin: 0 auto 10px; display: block;
            filter: drop-shadow(0 6px 16px rgba(212,175,55,0.3));
            -webkit-mask-image: radial-gradient(circle, #000 62%, transparent 100%);
            mask-image: radial-gradient(circle, #000 62%, transparent 100%);
        }
        .wordmark {
            font-family: 'Cinzel Decorative', 'Cinzel', serif; font-weight: 700;
            font-size: 1.65rem; line-height: 1.15; margin: 6px 0 2px;
            background: linear-gradient(180deg, var(--gold-bright) 10%, var(--gold) 55%, var(--gold-dim) 90%);
            -webkit-background-clip: text; background-clip: text; color: transparent;
            letter-spacing: 0.02em;
        }
        .ribbon {
            position: relative; display: inline-block; margin: 10px 0 26px; padding: 7px 26px;
            font-family: 'Cinzel', serif; font-weight: 600; font-size: 0.7rem;
            letter-spacing: 0.22em; text-transform: uppercase; color: var(--ink);
            background: linear-gradient(180deg, var(--gold-bright), var(--gold) 60%, var(--bronze));
            clip-path: polygon(3% 0%, 97% 0%, 100% 50%, 97% 100%, 3% 100%, 0% 50%);
            box-shadow: 0 8px 18px rgba(0,0,0,0.35);
        }
        .alert-banner {
            background: rgba(154,37,48,0.16); border: 1px solid rgba(192,57,43,0.45);
            color: #ff9b8a; font-size: 0.82rem; font-weight: 600; padding: 10px 14px;
            border-radius: 8px; margin-bottom: 20px; text-align: left;
        }
        .field { margin-bottom: 18px; text-align: left; }
        .field label {
            display: block; font-size: 0.7rem; letter-spacing: 0.12em; text-transform: uppercase;
            color: var(--bronze); margin-bottom: 7px; font-weight: 600;
        }
        .input-shell {
            position: relative; display: flex; align-items: center;
            background: rgba(2,5,10,0.65); border: 1px solid rgba(140,98,57,0.55); border-radius: 7px;
            transition: border-color 0.2s, box-shadow 0.2s;
        }
        .input-shell:focus-within { border-color: var(--gold); box-shadow: 0 0 0 3px rgba(212,175,55,0.14); }
        .input-shell .icon { width: 40px; height: 46px; display: flex; align-items: center; justify-content: center; color: var(--bronze); flex-shrink: 0; }
        .input-shell input {
            flex: 1; background: none; border: none; outline: none; color: #fff;
            font-size: 0.95rem; padding: 13px 14px 13px 0; font-family: 'Inter', sans-serif; min-width: 0;
        }
        .row-between { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; font-size: 0.8rem; flex-wrap: wrap; gap: 8px; }
        .remember { display: flex; align-items: center; gap: 7px; color: var(--muted); cursor: pointer; }
        .remember input { accent-color: var(--gold); }
        a.link { color: var(--gold); text-decoration: none; }
        a.link:hover { text-decoration: underline; }
        .btn-gold {
            position: relative; width: 100%; border: none; padding: 15px; border-radius: 7px;
            font-family: 'Cinzel', serif; font-weight: 700; font-size: 0.92rem; letter-spacing: 0.1em;
            text-transform: uppercase; color: var(--ink);
            background: linear-gradient(180deg, var(--gold-bright) 0%, var(--gold) 55%, var(--bronze) 100%);
            cursor: pointer; box-shadow: 0 12px 26px rgba(212,175,55,0.22), inset 0 1px 0 rgba(255,255,255,0.4);
            transition: transform 0.15s ease, box-shadow 0.15s ease;
        }
        .btn-gold:hover { transform: translateY(-1px); box-shadow: 0 16px 30px rgba(212,175,55,0.3), inset 0 1px 0 rgba(255,255,255,0.4); }
        .btn-gold:focus-visible { outline: 2px solid var(--gold-bright); outline-offset: 3px; }
        .divider { display: flex; align-items: center; gap: 12px; margin: 22px 0 18px; color: var(--muted); font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.1em; }
        .divider::before, .divider::after { content: ''; flex: 1; height: 1px; background: var(--line); }
        .footer-note { font-size: 0.85rem; color: var(--muted); }
        @media (max-width: 480px) {
            .frame-inner { padding: 30px 22px 26px; }
        }
    </style>
</head>
<body>
    <div class="embers">
        <span class="ember-mote" style="left:8%; animation-delay:0s;"></span>
        <span class="ember-mote" style="left:18%; animation-delay:2.4s;"></span>
        <span class="ember-mote" style="left:30%; animation-delay:1.1s;"></span>
        <span class="ember-mote" style="left:46%; animation-delay:3.6s;"></span>
        <span class="ember-mote" style="left:62%; animation-delay:0.6s;"></span>
        <span class="ember-mote" style="left:74%; animation-delay:2.9s;"></span>
        <span class="ember-mote" style="left:85%; animation-delay:1.8s;"></span>
        <span class="ember-mote" style="left:93%; animation-delay:4.2s;"></span>
    </div>

    <div class="frame-outer">
        <div class="frame-inner">
            <img class="crest" src="{{ url_for('static', filename='img/emblem.jpg') }}" alt="Global Dominion crest">
            <div class="wordmark">GLOBAL DOMINION</div>
            <div class="ribbon">Rise of Nations &middot; Login</div>

            {% if error %}
                <div class="alert-banner">{{ error }}</div>
            {% endif %}

            <form action="/login" method="POST">
                <div class="field">
                    <label>Commander Identity</label>
                    <div class="input-shell">
                        <span class="icon"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg></span>
                        <input type="text" name="identifier" placeholder="Username or Email" required>
                    </div>
                </div>
                <div class="field">
                    <label>Access Cipher</label>
                    <div class="input-shell">
                        <span class="icon"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="11" width="16" height="9" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg></span>
                        <input type="password" name="password" placeholder="Password" required>
                    </div>
                </div>
                <div class="row-between">
                    <label class="remember"><input type="checkbox" name="remember"> Remember Me</label>
                    <a href="/forgot_password" class="link">Forgot Password?</a>
                </div>
                <button type="submit" class="btn-gold">Enter the War Room</button>
            </form>

            <div class="divider">New Commander</div>
            <div class="footer-note">Need an account? <a href="/register" class="link">Register Here</a></div>
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
    <link rel="icon" type="image/png" href="{{ url_for('static', filename='img/favicon-32.png') }}">
    <link rel="apple-touch-icon" href="{{ url_for('static', filename='img/favicon-180.png') }}">
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Cinzel:wght@400;600;700;900&family=Cinzel+Decorative:wght@700;900&family=Inter:wght@300;400;500;600;700&display=swap');

        :root {
            --ink: #050b14; --void: #02050a; --navy: #0c1a30; --navy-2: #112340;
            --gold: #d4af37; --gold-bright: #f3d27a; --gold-dim: #a8842c; --bronze: #8c6239;
            --crimson: #9a2530; --crimson-bright: #c0392b; --ember: #d2691e;
            --parchment: #e7ecf3; --muted: #8fa1b8; --line: rgba(212,175,55,0.25);
        }
        * { box-sizing: border-box; }
        body {
            margin: 0; min-height: 100vh;
            background: radial-gradient(ellipse 900px 600px at 50% -10%, rgba(212,175,55,0.10), transparent 60%),
                        radial-gradient(ellipse 700px 500px at 90% 110%, rgba(154,37,48,0.12), transparent 60%),
                        linear-gradient(180deg, #0a1422 0%, var(--void) 100%);
            color: var(--parchment);
            font-family: 'Inter', sans-serif;
            display: flex; align-items: center; justify-content: center;
            padding: 40px 20px; position: relative; overflow-x: hidden;
        }
        .embers { position: fixed; inset: 0; pointer-events: none; z-index: 0; overflow: hidden; }
        .ember-mote {
            position: absolute; bottom: -10px; width: 4px; height: 4px; border-radius: 50%;
            background: var(--ember); box-shadow: 0 0 8px 2px rgba(210,105,30,0.7);
            opacity: 0; animation: drift 9s linear infinite;
        }
        @keyframes drift {
            0% { opacity: 0; transform: translateY(0) translateX(0); }
            10% { opacity: 0.85; } 90% { opacity: 0.4; }
            100% { opacity: 0; transform: translateY(-94vh) translateX(20px); }
        }
        @media (prefers-reduced-motion: reduce) { .ember-mote { animation: none; display: none; } }

        .frame-outer {
            position: relative; z-index: 1; width: 100%; max-width: 460px;
            border: 1px solid var(--bronze); border-radius: 16px; padding: 3px;
            background: linear-gradient(160deg, rgba(212,175,55,0.16), rgba(0,0,0,0) 40%);
            box-shadow: 0 30px 70px rgba(0,0,0,0.55), 0 0 0 1px rgba(0,0,0,0.4);
        }
        .frame-inner {
            border: 1px solid var(--line); border-radius: 13px; padding: 34px 36px 30px;
            background: linear-gradient(165deg, rgba(17,35,64,0.92), rgba(5,11,20,0.97) 55%);
            text-align: center;
        }
        .crest {
            width: 80px; margin: 0 auto 8px; display: block;
            filter: drop-shadow(0 6px 16px rgba(212,175,55,0.3));
            -webkit-mask-image: radial-gradient(circle, #000 62%, transparent 100%);
            mask-image: radial-gradient(circle, #000 62%, transparent 100%);
        }
        .wordmark {
            font-family: 'Cinzel Decorative', 'Cinzel', serif; font-weight: 700;
            font-size: 1.5rem; line-height: 1.15; margin: 4px 0 2px;
            background: linear-gradient(180deg, var(--gold-bright) 10%, var(--gold) 55%, var(--gold-dim) 90%);
            -webkit-background-clip: text; background-clip: text; color: transparent;
            letter-spacing: 0.02em;
        }
        .ribbon {
            position: relative; display: inline-block; margin: 10px 0 22px; padding: 7px 26px;
            font-family: 'Cinzel', serif; font-weight: 600; font-size: 0.7rem;
            letter-spacing: 0.2em; text-transform: uppercase; color: var(--ink);
            background: linear-gradient(180deg, var(--gold-bright), var(--gold) 60%, var(--bronze));
            clip-path: polygon(3% 0%, 97% 0%, 100% 50%, 97% 100%, 3% 100%, 0% 50%);
            box-shadow: 0 8px 18px rgba(0,0,0,0.35);
        }
        .alert-banner {
            background: rgba(154,37,48,0.16); border: 1px solid rgba(192,57,43,0.45);
            color: #ff9b8a; font-size: 0.82rem; font-weight: 600; padding: 10px 14px;
            border-radius: 8px; margin-bottom: 18px; text-align: left;
        }
        .field { margin-bottom: 15px; text-align: left; }
        .field label {
            display: block; font-size: 0.68rem; letter-spacing: 0.12em; text-transform: uppercase;
            color: var(--bronze); margin-bottom: 6px; font-weight: 600;
        }
        .input-shell {
            position: relative; display: flex; align-items: center;
            background: rgba(2,5,10,0.65); border: 1px solid rgba(140,98,57,0.55); border-radius: 7px;
            transition: border-color 0.2s, box-shadow 0.2s;
        }
        .input-shell:focus-within { border-color: var(--gold); box-shadow: 0 0 0 3px rgba(212,175,55,0.14); }
        .input-shell .icon { width: 38px; height: 42px; display: flex; align-items: center; justify-content: center; color: var(--bronze); flex-shrink: 0; }
        .input-shell input {
            flex: 1; background: none; border: none; outline: none; color: #fff;
            font-size: 0.92rem; padding: 11px 14px 11px 0; font-family: 'Inter', sans-serif; min-width: 0;
        }
        .terms-row { display: flex; align-items: flex-start; gap: 9px; margin: 4px 0 22px; text-align: left; font-size: 0.8rem; color: var(--muted); }
        .terms-row input { margin-top: 3px; accent-color: var(--gold); flex-shrink: 0; }
        a.link { color: var(--gold); text-decoration: none; }
        a.link:hover { text-decoration: underline; }
        .btn-gold {
            position: relative; width: 100%; border: none; padding: 15px; border-radius: 7px;
            font-family: 'Cinzel', serif; font-weight: 700; font-size: 0.9rem; letter-spacing: 0.08em;
            text-transform: uppercase; color: var(--ink);
            background: linear-gradient(180deg, var(--gold-bright) 0%, var(--gold) 55%, var(--bronze) 100%);
            cursor: pointer; box-shadow: 0 12px 26px rgba(212,175,55,0.22), inset 0 1px 0 rgba(255,255,255,0.4);
            transition: transform 0.15s ease, box-shadow 0.15s ease;
        }
        .btn-gold:hover { transform: translateY(-1px); box-shadow: 0 16px 30px rgba(212,175,55,0.3), inset 0 1px 0 rgba(255,255,255,0.4); }
        .btn-gold:focus-visible { outline: 2px solid var(--gold-bright); outline-offset: 3px; }
        .divider { display: flex; align-items: center; gap: 12px; margin: 20px 0 16px; color: var(--muted); font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.1em; }
        .divider::before, .divider::after { content: ''; flex: 1; height: 1px; background: var(--line); }
        .footer-note { font-size: 0.85rem; color: var(--muted); }
        @media (max-width: 480px) {
            .frame-inner { padding: 26px 22px 22px; }
        }
    </style>
</head>
<body>
    <div class="embers">
        <span class="ember-mote" style="left:8%; animation-delay:0s;"></span>
        <span class="ember-mote" style="left:20%; animation-delay:2.4s;"></span>
        <span class="ember-mote" style="left:34%; animation-delay:1.1s;"></span>
        <span class="ember-mote" style="left:50%; animation-delay:3.6s;"></span>
        <span class="ember-mote" style="left:66%; animation-delay:0.6s;"></span>
        <span class="ember-mote" style="left:80%; animation-delay:2.9s;"></span>
        <span class="ember-mote" style="left:92%; animation-delay:1.8s;"></span>
    </div>

    <div class="frame-outer">
        <div class="frame-inner">
            <img class="crest" src="{{ url_for('static', filename='img/emblem.jpg') }}" alt="Global Dominion crest">
            <div class="wordmark">GLOBAL DOMINION</div>
            <div class="ribbon">New Commander Enlistment</div>

            {% if error %}
                <div class="alert-banner">{{ error }}</div>
            {% endif %}

            <form action="/register" method="POST">
                <div class="field">
                    <label>Callsign / Username</label>
                    <div class="input-shell">
                        <span class="icon"><svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg></span>
                        <input type="text" name="username" placeholder="Choose a callsign" required>
                    </div>
                </div>
                <div class="field">
                    <label>Email Address</label>
                    <div class="input-shell">
                        <span class="icon"><svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="m22 7-10 6L2 7"/></svg></span>
                        <input type="email" name="email" placeholder="you@example.com" required>
                    </div>
                </div>
                <div class="field">
                    <label>Access Cipher</label>
                    <div class="input-shell">
                        <span class="icon"><svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="11" width="16" height="9" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg></span>
                        <input type="password" name="password" placeholder="Create a password" required>
                    </div>
                </div>
                <div class="field">
                    <label>Confirm Cipher</label>
                    <div class="input-shell">
                        <span class="icon"><svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg></span>
                        <input type="password" name="confirm_password" placeholder="Re-enter password" required>
                    </div>
                </div>
                <label class="terms-row">
                    <input type="checkbox" name="terms" required>
                    <span>I agree to the <a href="#" class="link">Terms &amp; Conditions</a> of service</span>
                </label>
                <button type="submit" class="btn-gold">Register &amp; Enlist</button>
            </form>

            <div class="divider">Already Serving</div>
            <div class="footer-note">Already registered? <a href="/login" class="link">Return to Command Center</a></div>
        </div>
    </div>
</body>
</html>
"""

FORGOT_PASSWORD_HTML = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Global Dominion - Recover Access</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            background: radial-gradient(circle, #0F1E36 0%, #050B14 100%);
            color: #E2E8F0;
            font-family: 'Cinzel', serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
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
            margin-bottom: 20px;
            letter-spacing: 2px;
            text-transform: uppercase;
        }
        .message {
            color: #94A3B8;
            margin-bottom: 20px;
            font-size: 0.95rem;
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
        input[type="email"] {
            width: 100%;
            padding: 12px;
            background-color: #0A1220;
            border: 1px solid #8C6239;
            color: #FFF;
            border-radius: 4px;
            font-size: 0.95rem;
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
        .footer-link {
            margin-top: 20px;
            font-size: 0.85rem;
        }
        .footer-link a {
            color: #D4AF37;
            text-decoration: none;
        }
    </style>
</head>
<body>
    <div class="container">
        <h2>Recover Your Command</h2>
        <p class="message">Enter your registered email address. A recovery link will be sent if the account exists.</p>
        {% if message %}
            <div class="message" style="color:#A7F3D0;">{{ message }}</div>
        {% endif %}
        <form action="/forgot_password" method="POST">
            <div class="input-group">
                <label>Email Address</label>
                <input type="email" name="email" required>
            </div>
            <button type="submit" class="btn">Send Recovery Link</button>
        </form>
        <div class="footer-link">
            Remembered your access? <a href="/login">Return to Login</a>
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

        :root {
            --bg: #050B14;
            --surface: rgba(10, 18, 32, 0.92);
            --panel: rgba(10, 18, 32, 0.86);
            --panel-border: rgba(212, 175, 55, 0.22);
            --accent: #D4AF37;
            --accent-dark: #8C6239;
            --text: #E2E8F0;
            --muted: #94A3B8;
            --shadow: rgba(0, 0, 0, 0.55);
        }

        * {
            box-sizing: border-box;
            user-select: none;
        }
        body {
            margin: 0;
            padding: 0;
            background: radial-gradient(circle at top left, rgba(212, 175, 55, 0.08), transparent 25%),
                        radial-gradient(circle at bottom right, rgba(56, 189, 248, 0.08), transparent 18%),
                        linear-gradient(180deg, #050b14 0%, #02050a 100%);
            color: var(--text);
            font-family: 'Inter', sans-serif;
            overflow-x: hidden;
        }
        h1, h2, h3, h4, .imperial-font {
            font-family: 'Cinzel', serif;
            letter-spacing: 1px;
            color: var(--accent);
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

        .hero-banner {
            margin: 90px 0 30px;
            padding: 24px 28px;
            background: linear-gradient(135deg, rgba(13, 20, 40, 0.95), rgba(5, 11, 20, 0.95));
            border: 1px solid rgba(212, 175, 55, 0.2);
            border-radius: 12px;
            display: grid;
            grid-template-columns: 1fr auto;
            gap: 20px;
            align-items: center;
            box-shadow: 0 0 40px rgba(212, 175, 55, 0.12);
            position: relative;
            overflow: hidden;
        }
        .hero-banner::before {
            content: '';
            position: absolute;
            inset: 0;
            background: radial-gradient(circle at top left, rgba(212, 175, 55, 0.08), transparent 20%),
                        radial-gradient(circle at bottom right, rgba(255, 255, 255, 0.04), transparent 16%);
            pointer-events: none;
        }
        .hero-banner .hero-copy {
            position: relative;
            z-index: 1;
        }
        .hero-banner h1 {
            font-size: clamp(2rem, 2.6vw, 3.4rem);
            line-height: 1.05;
            margin-bottom: 12px;
        }
        .hero-banner p {
            margin: 0;
            color: var(--muted);
            max-width: 720px;
            font-size: 1rem;
            line-height: 1.7;
        }
        .hero-crest {
            position: relative;
            width: 220px;
            min-height: 160px;
            background: linear-gradient(180deg, rgba(21, 37, 63, 0.95), rgba(8, 14, 26, 0.95));
            border: 1px solid rgba(212, 175, 55, 0.22);
            border-radius: 18px;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
            box-shadow: inset 0 0 30px rgba(212, 175, 55, 0.08);
            z-index: 1;
        }
        .hero-crest::before {
            content: '';
            position: absolute;
            inset: 18px;
            border: 1px solid rgba(212, 175, 55, 0.18);
            border-radius: 14px;
        }
        .hero-crest h2 {
            font-size: 1rem;
            letter-spacing: 0.2em;
            text-transform: uppercase;
            margin-bottom: 10px;
            color: #F8E16C;
        }
        .hero-crest .crest-icon {
            width: 100%;
            height: 88px;
            display: grid;
            place-items: center;
            color: var(--accent);
            font-size: 5.3rem;
            text-shadow: 0 0 20px rgba(212, 175, 55, 0.35);
        }

        .app-wrapper {
            margin-top: 70px;
            display: flex;
            min-height: calc(100vh - 70px);
            gap: 20px;
            padding: 0 20px 40px;
        }
        .sidebar {
            width: 280px;
            background-color: #070D18;
            border-right: 1px solid var(--panel-border);
            padding: 24px 18px;
            display: flex;
            flex-direction: column;
            gap: 16px;
            box-shadow: inset 0 0 24px rgba(0, 0, 0, 0.25);
        }
        .sidebar::before {
            content: 'COMMAND HUD';
            display: block;
            font-size: 0.75rem;
            letter-spacing: 0.2em;
            color: var(--muted);
            margin-bottom: 8px;
        }
        .sidebar-btn {
            background: linear-gradient(180deg, rgba(13, 20, 40, 0.98), rgba(5, 11, 20, 0.98));
            border: 1px solid transparent;
            color: #CBD5E1;
            padding: 14px 16px;
            text-align: left;
            width: 100%;
            cursor: pointer;
            font-size: 0.95rem;
            border-radius: 10px;
            transition: all 0.25s ease;
            text-transform: uppercase;
            font-family: 'Cinzel', serif;
            box-shadow: 0 2px 18px rgba(0, 0, 0, 0.15);
        }
        .sidebar-btn:hover, .sidebar-btn.active {
            border-color: var(--accent);
            color: var(--accent);
            background: linear-gradient(180deg, rgba(19, 26, 44, 0.98), rgba(10, 15, 25, 0.98));
        }
        .main-stage {
            flex-grow: 1;
            padding: 24px;
            background: linear-gradient(180deg, rgba(5, 11, 20, 0.92), rgba(4, 8, 14, 0.98));
            border: 1px solid rgba(212, 175, 55, 0.12);
            border-radius: 20px;
            overflow-y: auto;
            box-shadow: 0 0 60px rgba(0, 0, 0, 0.35);
            position: relative;
            min-width: 0;
        }
        .main-stage::before {
            content: '';
            position: absolute;
            top: 20px;
            right: 20px;
            width: 240px;
            height: 240px;
            border-radius: 50%;
            background: rgba(212, 175, 55, 0.03);
            pointer-events: none;
        }

        /* MAP VISUAL SYSTEM */
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
            background: linear-gradient(180deg, rgba(7, 13, 24, 0.92), rgba(3, 7, 13, 0.96));
            border: 1px solid rgba(212, 175, 55, 0.18);
            border-radius: 18px;
            padding: 24px;
            position: relative;
            box-shadow: inset 0 0 35px rgba(212, 175, 55, 0.08), 0 25px 50px rgba(0, 0, 0, 0.16);
        }
        .world-svg {
            width: 100%;
            height: auto;
            max-height: 520px;
            background-color: #04080e;
            border-radius: 14px;
            border: 1px solid rgba(255,255,255,0.05);
            box-shadow: inset 0 0 32px rgba(255,255,255,0.02);
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
            background: rgba(7, 13, 24, 0.94);
            border: 1px solid rgba(212, 175, 55, 0.16);
            border-radius: 18px;
            padding: 24px;
            margin-bottom: 28px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.18);
        }
        .g-header {
            border-bottom: 1px solid rgba(212, 175, 55, 0.12);
            padding-bottom: 14px;
            margin-bottom: 18px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 16px;
        }
        .g-header h2,
        .g-header h3 {
            color: var(--accent);
            font-size: 1.4rem;
            letter-spacing: 0.08em;
        }
        .g-header span {
            font-size: 0.85rem;
            color: var(--text);
            background: rgba(10, 18, 32, 0.88);
            border: 1px solid rgba(212, 175, 55, 0.12);
            padding: 8px 12px;
            border-radius: 999px;
        }

        /* GRID CONFIGURATIONS */
        .unit-grid, .tech-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
            gap: 24px;
        }
        .unit-card, .tech-card {
            background: rgba(7, 13, 24, 0.88);
            border: 1px solid rgba(212, 175, 55, 0.12);
            border-radius: 16px;
            padding: 22px;
            transition: transform 0.2s ease, border-color 0.2s ease, box-shadow 0.2s ease;
            box-shadow: 0 12px 24px rgba(0,0,0,0.12);
        }
        .unit-card:hover, .tech-card:hover {
            border-color: var(--accent);
            transform: translateY(-2px);
            box-shadow: 0 18px 30px rgba(212, 175, 55, 0.15);
        }

        /* BUTTONS */
        .g-btn {
            background: linear-gradient(180deg, #D4AF37 0%, #8C6239 100%);
            color: #0A1220;
            border: none;
            padding: 12px 18px;
            font-weight: 700;
            font-size: 0.9rem;
            cursor: pointer;
            border-radius: 999px;
            text-transform: uppercase;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
            box-shadow: 0 10px 18px rgba(212, 175, 55, 0.18);
        }
        .g-btn:hover {
            transform: translateY(-1px);
            box-shadow: 0 14px 22px rgba(212, 175, 55, 0.24);
        }
        .g-btn-sec {
            background: rgba(13, 20, 40, 0.95);
            border: 1px solid rgba(212, 175, 55, 0.14);
            color: var(--accent);
            padding: 12px 18px;
            font-size: 0.9rem;
            cursor: pointer;
            border-radius: 999px;
            text-transform: uppercase;
            transition: all 0.2s ease;
        }
        .g-btn-sec:hover {
            background-color: rgba(212, 175, 55, 0.08);
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
            background: linear-gradient(135deg, rgba(13, 20, 40, 0.98), rgba(5, 11, 20, 0.98));
            border: 1px solid rgba(212, 175, 55, 0.22);
            border-radius: 18px;
            width: 100%;
            max-width: 520px;
            padding: 28px;
            box-shadow: 0 0 35px rgba(212,175,55,0.28);
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

    <section class="hero-banner">
        <div class="hero-copy">
            <h1>Global Dominion</h1>
            <p>Forge your empire under a gilded banner. Command continents, deploy elite divisions, and harness ancient relics while the world trembles beneath your rise.</p>
        </div>
        <div class="hero-crest">
            <h2>Rise of Nations</h2>
            <div class="crest-icon">⚜</div>
        </div>
    </section>

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
# DATABASE MODELS
# -------------------------------------------------------------------------

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
        "units": ["Marine Infantry", "Abrams Tank", "F-35 Fighter", "Aircraft Carrier"],
        "color": "#2563EB"
    },
    "China": {
        "bonus": "+12% Production Efficiency",
        "units": ["Guard Infantry", "Type 99 Tank", "J-20 Fighter", "Carrier Task Force"],
        "color": "#DB2777"
    },
    "Japan": {
        "bonus": "+15% Tactical Attack Power",
        "units": ["Samurai Guard", "Modern Infantry", "Type-10 Tank", "Drone Squadron"],
        "color": "#DC2626"
    },
    "Germany": {
        "bonus": "+18% Defense and Armor",
        "units": ["Panzer Infantry", "Leopard Tank", "Stealth Fighter", "Railgun Cruiser"],
        "color": "#EAB308"
    },
    "Russia": {
        "bonus": "+20% Defensive Unit Fortification",
        "units": ["Spetsnaz", "T-90 Tank", "Missile Launcher", "Attack Helicopter"],
        "color": "#16A34A"
    },
    "United Kingdom": {
        "bonus": "+10% Naval Command",
        "units": ["Royal Guards", "Challenger Tank", "Typhoon Jet", "Battle Carrier"],
        "color": "#4F46E5"
    },
    "France": {
        "bonus": "+12% Mobility and Precision",
        "units": ["Legion Infantry", "Leclerc Tank", "Rafale Fighter", "Submarine Fleet"],
        "color": "#0EA5E9"
    },
    "India": {
        "bonus": "+14% Resource Gathering",
        "units": ["Mountain Infantry", "Arjun Tank", "Tejas Jet", "Ocean Frigate"],
        "color": "#F97316"
    },
    "Brazil": {
        "bonus": "+10% Territory Growth",
        "units": ["Jungle Rangers", "Armored Cavalry", "Falcon Fighter", "River Monitor"],
        "color": "#84CC16"
    },
    "Philippines": {
        "bonus": "+15% Unit Speed & Magic Resistance",
        "units": ["Scout Infantry", "Marine Battalion", "Jungle Rangers", "Coastal Defense Unit"],
        "color": "#D97706"
    },
    "South Korea": {
        "bonus": "+16% Technology Advancement",
        "units": ["Cyber Infantry", "K2 Tank", "FA-50 Fighter", "Stealth Corvette"],
        "color": "#A855F7"
    },
    "Canada": {
        "bonus": "+12% Resource Stability",
        "units": ["Arctic Infantry", "Armored Recon", "Aurora Jet", "Polar Cruiser"],
        "color": "#06B6D4"
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

        hashed = generate_password_hash(password, method='pbkdf2:sha256')
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
            if request.form.get('remember'):
                session.permanent = True
            if not user.country:
                return redirect(url_for('country_selection'))
            return redirect(url_for('home'))
        return render_template_string(LOGIN_HTML, error="Invalid credentials submitted.")
    
    return render_template_string(LOGIN_HTML)

@app.route('/forgot_password', methods=['GET', 'POST'])
def forgot_password():
    if request.method == 'POST':
        email = request.form.get('email')
        return render_template_string(FORGOT_PASSWORD_HTML, message="If this email exists, a recovery link has been sent.")
    return render_template_string(FORGOT_PASSWORD_HTML)

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
# DATABASE BOOTSTRAP
# -------------------------------------------------------------------------
# Runs at import time -- NOT only under `if __name__ == "__main__"`.
# Vercel (and any WSGI server) imports this module directly; it never runs
# it as the main script. With bootstrap gated behind `__main__`, the
# users/territories/units/research tables were never created against the
# production Postgres database, so the very first query in register() or
# login() failed with "relation does not exist" -> the blank 500 page.
with app.app_context():
    try:
        db.create_all()
        seed_database()
    except Exception as boot_error:
        # A transient hiccup here shouldn't take down the whole app at cold
        # start -- log it so it's visible in Vercel's function logs instead
        # of silently resurfacing as an unexplained 500 on the next request.
        app.logger.error(f"Database bootstrap failed: {boot_error}")


# -------------------------------------------------------------------------
# APPLICATION ENTRYPOINT
# -------------------------------------------------------------------------

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)