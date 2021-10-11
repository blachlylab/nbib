module nbib.fastcgi;

import nbib.types;
import nbib.transforms;

import arsd.cgi;

import std.array;
import std.algorithm : joiner, map, splitter, splitWhen, chunkBy, group;
import std.conv;
import std.string : strip, stripRight, lineSplitter;
import std.format : format;
import std.stdio;
import std.range.primitives : empty;
import mir.algebraic;
import asdf;

/** Define two endpoints, GET: `/health_check` and POST: `/*`

    The first always returns JSON status OK per IETF spec:
    <https://tools.ietf.org/id/draft-inadarei-api-health-check-01.html>

    The second handles a POST of `text/plain` to any URL path
    and treats the body as MEDLINE/Pubmed format .nbib bibliography.
    It returns transformed CSL-JSON
*/
void handler(Cgi cgi) {

    if (cgi.requestMethod == Cgi.RequestMethod.GET && cgi.requestUri == "/health_check") {
        cgi.writeJson(`{"status": "pass"}`);
        cgi.close();
        return;
    }

    if (cgi.requestMethod != Cgi.RequestMethod.POST ||
        !("content-type" in cgi.requestHeaders) ||
        cgi.requestHeaders["content-type"] != "text/plain") {
        
        cgi.setResponseStatus("400 Bad Request");
        cgi.close();
        return;
    }

    // Below handles nbib->CSL conversion
    cgi.setResponseContentType("application/json"); // writeJson can only be called once

    // OK, now parse the raw post body
    auto records = cgi.postBody
                    .lineSplitter
                    .map!stripRight
                    .array
                    .splitter("")
                    .map!mergeMultiLineItems
                    .map!medlineToCSL
                    .map!reduceAuthors;

    auto ser = records.toAsdf;
    cgi.write(ser.app.result.to!string);
    cgi.close();
}

mixin GenericMain!handler;
