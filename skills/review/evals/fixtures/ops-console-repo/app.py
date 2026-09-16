from flask import Flask, jsonify, request

import store

app = Flask(__name__)


def db():
    return store.open_db("console.db")


@app.route("/entries")
def entries():
    owner = request.args.get("owner", "ops")
    return jsonify([dict(zip(("id", "owner", "label", "state"), row))
                    for row in store.find_by_owner(db(), owner)])


@app.route("/entries/<int:entry_id>")
def one_entry(entry_id):
    row = store.entry(db(), entry_id)
    if row is None:
        return jsonify({"error": "not found"}), 404
    return jsonify(dict(zip(("id", "owner", "label", "state"), row)))
