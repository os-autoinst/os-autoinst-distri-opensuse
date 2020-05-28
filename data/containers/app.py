from flask import Flask, render_template
import os, sys, ssl
 
app = Flask(__name__)
message = ""

@app.route("/")
def index():
    return render_template("index.html", message = message)

if __name__ == "__main__":
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    
    if len(sys.argv) > 1:
        url = sys.argv[1]
    else:
        print("Program requires at least one argument!")
        sys.exit()

    cmd = "curl -I " + url
    response = os.system(cmd)
    if response == 0:
        message = "pass"
    else:
        message = "not pass"
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))
