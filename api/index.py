from flask import Flask
from app import app as application

# Vercel Python serverless requires the WSGI app to be called `application`.

# The root Flask app is imported from the repo root app.py

if __name__ == "__main__":
    application.run(host="0.0.0.0", port=5000)
