//https://stackoverflow.com/questions/37958383/call-rest-api-in-sails-js
var hostURI = "gerpro-api.herokuapp.com";

var healthCheckURI = "/api/main/healthcheck";

var request = require('request');
var http = require('http');
var https = require('https');

var KeepAliveServices = {

    keep_alive: function (req, res) {

        sails.log('KEEP-ALIVING');

        var rs = "";
        var options = {
            hostname: hostURI,
            path: healthCheckURI,
            method: 'GET'
        };


        http.get(options, function (resp) {
            resp.on('data', function (chunk) {
                rs = resp;
            });
        }).on("error", function (e) {
            console.log("Got error: " + e.message);
        });
    }
};

module.exports = KeepAliveServices; 