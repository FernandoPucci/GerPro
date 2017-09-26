//https://stackoverflow.com/questions/37958383/call-rest-api-in-sails-js
//PROD
//var hostURI = "gerpro-api.herokuapp.com";
//var portURI = "";

//DEV
var hostURI = "localhost";
var portURI = 1337;

var healthCheckURI = "/api/main/healthcheck";
var executionQueueURI = "/api/test/execute";
var nextQueueURI = "/api/test/next";

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
      port: portURI,
      method: 'GET'
    };


    http.get(options, function (resp) {
      resp.on('data', function (chunk) {
        rs = resp;
      });
    }).on("error", function (e) {
      console.log("[keep_alive] Got error: " + e.message);
    });
  },
  executeQueue: function (req, res) {

    sails.log('EXECUTING QUEUE');

    var rs = "";
    var options = {
      hostname: hostURI,
      path: executionQueueURI,
      port: portURI,
      method: 'GET'
    };


    http.get(options, function (resp) {
      resp.on('data', function (chunk) {
        rs = resp;
      });
    }).on("error", function (e) {
      console.log("[executeQueue] Got error: " + e.message);
    });
  },
  nextQueue: function (req, res) {

    sails.log('CALL NEXT QUEUE');

    var rs = "";
    var options = {
      hostname: hostURI,
      path: nextQueueURI,
      port: portURI,
      method: 'GET'
    };


    http.get(options, function (resp) {
      resp.on('data', function (chunk) {
        rs = resp;
      });
    }).on("error", function (e) {
      console.log("[executeQueue] Got error: " + e.message);
    });
  }
};

module.exports = KeepAliveServices;
