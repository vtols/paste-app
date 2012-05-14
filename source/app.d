module app;

import vibe.d;
import std.conv;
import std.file;
import std.stdio;
import std.array;
import std.format;

int counter = 0;

string[string] languages;
                        
void initLanguages() {
    languages["lang-cpp"]       =   "C++";
    languages["lang-java"]      =   "Java";
    languages["lang-pascal"]    =   "Pascal";
    languages["text"]           =   "Plain text";
}

struct PasteData {
    
    public {
        string[] lines;
        string hind, time, raw, lang;
        int linec, charc;
    }
    
    this(string strIndex) {
        string fname = "data/paste/" ~ strIndex,
               pfname = fname ~ ".p";
        File f = File(fname, "r");
        hind = "#" ~ strIndex;
        raw = "";
        linec = charc = 0;
        lines = [];
        foreach (string line; std.stdio.lines(f)) {
            linec++;
            charc += line.length;
            raw ~= line;
            lines ~= [prepareLine(line)];
        }
        time = timeLastModified(fname)
                        .toSimpleString();
        if (exists(pfname))
            f = File(pfname, "r");
        else
            f = File("data/default.p", "r");
        string[string] params;
        foreach (string line; std.stdio.lines(f)) {
            string[] kv = split(line);
            params[kv[0]] = kv[1];
        }
        lang = params.get("lang", "text");
    }
    
    string prepareLine(string line) {
        line = replace(line, "\n", "");
        line = replace(line, "\r", "");
        if (line == "")
            return "<br>";
        line = vibe.textfilter.html.htmlEscape(line);
        string result = "";
        int k = 0;
        foreach (char c; line) {
            switch (c) {
                case '\n':
                case '\r':
                    break;
                case ' ':
                    result ~= "&nbsp;";
                    k++;
                    break;
                case '\t':
                    result ~= replicate("&nbsp;", 4 - k % 4);
                    k += 4 - k % 4;
                    break;
                default:
                    result ~= c;
                    k++;
            }
        }
        return "<div>" ~ result ~ "</div>";
    }
    
}

void handleIndex(HttpServerRequest req, 
                   HttpServerResponse res) {
    res.render!("index.dt", counter, languages);
}

void handleNewPaste(HttpServerRequest req, 
                 HttpServerResponse res) {
    string text = req.form["text"],
           lang = req.form["lang"];
    string fn = "paste/" ~ to!string(counter++);
    try {
        mkdir("data/paste");
    } 
    catch(Exception) { }
    std.file.write("data/" ~ fn, text);
    std.file.write("data/" ~ fn ~ ".p", "lang " ~ lang);
    std.file.write("data/counter", to!string(counter));
    res.redirect("/" ~ fn);
}

void handlePaste(HttpServerRequest req, 
                 HttpServerResponse res) {
    string n = req.params["num"];
    PasteData p = PasteData(n);
    res.render!("paste.dt", p, languages);
}

static this() {
    setLogLevel(LogLevel.Trace);
    auto settings = new HttpServerSettings;
    settings.port = 8080;
    try {
        string s = to!string(read("data/counter"));
        formattedRead(s, "%d", &counter);
    } catch (Exception) { }
    initLanguages();
    auto router = new UrlRouter;
    router.get("/", &handleIndex);
    logInfo("route /");
    router.get("*", serveStaticFiles("./public/"));
    router.post("/newpaste", &handleNewPaste);
    router.get("/paste/:num", &handlePaste);
    listenHttp(settings, router);
}
