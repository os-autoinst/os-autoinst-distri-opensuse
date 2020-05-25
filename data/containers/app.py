from flask import Flask, render_template
import os, sys, json, urllib.request, ssl
 
app = Flask(__name__)
version = ""
  
@app.route("/")
def index():
    return render_template("index.html", version = version)

if __name__ == "__main__":
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    
    if len(sys.argv) > 1:
        url = sys.argv[1]
    else:
        print("Program requires at least one argument!")
        sys.exit()

    request = urllib.request.urlopen(url, context=ctx)
    data = json.loads(request.read())
    version = (data["job"]["settings"]["VERSION"])
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))
