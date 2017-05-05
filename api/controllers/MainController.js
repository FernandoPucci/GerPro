/**
 * MainController
 *
 * @description :: Server-side logic for managing mains
 * @help        :: See http://sailsjs.org/#!/documentation/concepts/Controllers
 */
var bodyParser = require("body-parser");

module.exports = {

    start: function (req, res) {

        var startResponse = CronServices.startCron();

        if (typeof startResponse === 'number') {

            res.status(startResponse).end(startResponse + "");

        } else {

            res.status(500).end(startResponse + "");

        }

    },

    stop: function (req, res) {

        var stopResponse = CronServices.stopCron();

        if (typeof stopResponse === 'number') {

            res.status(stopResponse).end(stopResponse + "");

        } else {

            res.status(500).end(stopResponse + "");
        }

    },

    healthcheck: function (req, res) {

        var checkResponse = CronServices.checkCron();


            res.status(200).end(checkResponse + "");
       

    }

};

