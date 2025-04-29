# lua-nats-client

A minimalist NATS client written in pure Lua 🐾  
Supports basic operations like CONNECT, PUB, SUB, UNSUB, PING, PONG, and a simple message read loop.

---

## ✨ Features

- ✅ Connect to a NATS server  
- 📬 Publish messages  
- 📡 Subscribe with callbacks  
- 🔁 Message polling and read loop (`read_loop`)  
- 🪝 Hook support for events like `ping`, `ok`, etc.  
- 🧪 Unit and integration tests (no external dependencies)

---

## 📦 Installation

**Requirements:**  
- Lua 5.1+  
- LuaSocket  

Install dependencies:

    luarocks install luasocket

Clone the repo:

    git clone https://github.com/Barnabur/lua-nats-client.git
    cd lua-nats-client

---

## ⚡ Quick Start

    local NATS = require("nats.nats_cli")

    local client = NATS.new("localhost", {}, 4222)

    client:connect()
    client:subscribe("hello", function(subject, msg)
        print("Received on:", subject, "msg:", msg)
    end)

    client:publish("hello", "world!")

    client:read_loop()

---

## 🧪 Running Tests

Unit and integration tests are included in the `tests/` folder.  
Run them using the test runner:

    lua ./test_runner.lua

---

## 📋 TODO

- [ ] Reconnect support  
- [ ] Queue group support  
- [ ] Parse server INFO message (e.g. JSON)  
- [ ] Graceful shutdown of `read_loop`  
- [ ] Error handling and recovery tests
- [ ] Auth
- [ ] JetStream

---

## 📜 License

MIT License
