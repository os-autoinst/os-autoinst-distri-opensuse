import tornado.httpserver
import tornado.websocket
import tornado.ioloop
import tornado.web

class UpperCaseWebSocketServer(tornado.websocket.WebSocketHandler):
    def open(self):
        print('New connection from client')
    def on_message(self, message):
        self.write_message(message.upper())
    def on_close(self):
        print('Closed connection')
    def check_origin(self, origin):
        return True

app = tornado.web.Application([(r'/websocket', UpperCaseWebSocketServer),])
http_server = tornado.httpserver.HTTPServer(app)
http_server.listen(8000)
tornado.ioloop.IOLoop.instance().start()
