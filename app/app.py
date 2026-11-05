from flask import Flask, jsonify


def create_app():
    app = Flask(__name__)

    @app.route("/", methods=["GET"])
    def home():
        return jsonify({
            "message": "Secure DevSecOps CI/CD Pipeline",
            "status": "running"
        }), 200

    @app.route("/health", methods=["GET"])
    def health():
        return jsonify({
            "service": "secure-devsecops-api",
            "status": "healthy"
        }), 200

    return app


app = create_app()
